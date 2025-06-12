#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2021-2025 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#

set -exo pipefail

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOTDIR}/lib/version.sh"
source "${ROOTDIR}/lib/install.sh"

: "${BUILDDIR:="${ROOTDIR}/build"}"
mkdir -p "$BUILDDIR"

# Assumes site-init customizations has been properly updated
[[ -f "${BUILDDIR}/customizations.yaml" ]] && rm -f "${BUILDDIR}/customizations.yaml"
kubectl get secrets -n loftsman site-init -o jsonpath='{.data.customizations\.yaml}' | base64 -d > "${BUILDDIR}/customizations.yaml"

# Generate manifests with customizations
mkdir -p "${BUILDDIR}/manifests"
find "${ROOTDIR}/manifests" -name "*.yaml" | while read manifest; do
    manifestgen -i "$manifest" -c "${BUILDDIR}/customizations.yaml" -o "${BUILDDIR}/manifests/$(basename "$manifest")"
done

# What version of K8s is currently running?
K8SVER=$(kubectl version -o json | jq -r '.serverVersion.gitVersion' | grep -o "v1.[^.]*")

function deploy() {
    # XXX Loftsman may not be able to connect to $NEXUS_URL due to certificate
    # XXX trust issues, so use --charts-path instead of --charts-repo.
    loftsman ship --charts-path "${ROOTDIR}/helm" --manifest-path "$1"
}

# Undeploy the chart if it exists on the system.
# Use this if a chart has been removed from a manifest and needs
# to be removed from the system as part of an upgrade.
function undeploy() {
    # Now that we're using --keep-history, helm status will return with a STATUS
    # of "uninstalled" if the chart has already been uninstalled.
    # If the chart is missing (rc==1) or if uninstalled, return success.
    helm status "$@" || return 0
    if [ "$(helm status "$@" | grep STATUS | awk '{print $2}')" = "uninstalled" ]; then
      return 0
    fi
    # Remove the chart.
    helm uninstall "$@" --keep-history
}

# Select which manifest file to deploy depending on K8SVER running.
# If a manifest doesn't exist for the K8SVER, use default manifest (ie platform.yaml).
function select_manifest_file() {
    manifest="$1"
    # If we're not running K8SVER v1.32, then return ${manifest}-${K8SVER}.yaml.
    if [ "${K8SVER}" != "v1.32" ] && [ -f ${BUILDDIR}/manifests/${manifest}-${K8SVER}.yaml ]; then
      echo "${manifest}-${K8SVER}.yaml"
    else
      echo "${manifest}.yaml"
    fi
}

# CRUS is removed in CSM 1.6, and should be removed during the upgrade, if it exists
undeploy -n services cray-crus

# REDS is removed in CSM 1.6, and should be removed before installing the CSM 1.6 cray-hms-discovery
undeploy -n services cray-hms-reds

#
# cray-etcd-backup and cray-etcd-defrag moving from operators to services namespace,
# uninstall prior to upgrade.
#
echo "Removing cray-etcd-backup and cray-etcd-defrag charts from the operators namespace."
echo "These charts will later be deployed in the services namespace."
undeploy -n operators cray-etcd-backup
undeploy -n operators cray-etcd-defrag

# Undeploying sysmgmt-health and deleting the crds so as to successfully upgrade to
# the latest version of victoria-metrics-k8s-stack
if [ "${K8SVER}" = "v1.24" ]; then
    echo "Removing cray-sysmgmt-health from the sysmgmt-health namespace."
    undeploy -n sysmgmt-health cray-sysmgmt-health
    echo "Removing crds from the sysmgmt-health namespace as a part of cleanup."
    # Need to disable pipefail in case victoriamertrics.com crds have already been removed.
    bash +o pipefail -c "kubectl get crd | grep victoriametrics.com | awk '{ print \$1 }' | xargs -i kubectl delete crd {}"
fi

# Need to undeploy kyverno at K8s 1.24 before upgrading to K8s 1.32
if [ "${K8SVER}" = "v1.24" ]; then
    echo "Removing cray-kyverno-policies-upstream chart ..."
    undeploy -n kyverno cray-kyverno-policies-upstream
    echo "Removing kyverno-policy chart ..."
    undeploy -n kyverno kyverno-policy
    echo "Removing cray-kyverno chart ..."
    undeploy -n kyverno cray-kyverno
fi

# Select manifests are we deploying
core_services_yaml=$(select_manifest_file core-services)
keycloak_gatekeeper_yaml=$(select_manifest_file keycloak-gatekeeper)
nexus_yaml=$(select_manifest_file nexus)
platform_yaml=$(select_manifest_file platform)
storage_yaml=$(select_manifest_file storage)
sysmgmt_yaml=$(select_manifest_file sysmgmt)

# Deploy services critical for Nexus to run
echo "Deploying ceph csi provisioners..."
if [ "${K8SVER}" = "v1.32" ]; then
    # Apply the workaround for cephcsi upgrade known issues
    kubectl delete csidriver rbd.csi.ceph.com || true
    kubectl delete csidriver cephfs.csi.ceph.com || true
fi
deploy "${BUILDDIR}/manifests/${storage_yaml}"
echo "Deployment of ceph csi provisioners is complete."
echo "PVC movement will resume when all ceph csi pods are finished starting."
if [ "${K8SVER}" = "v1.32" ]; then
    # Update postgres operator crds before upgrading the operator
    postgres_chart_path=$(find "${ROOTDIR}/helm" -name "cray-postgres-operator*.tgz")
    if [[ -z $postgres_chart_path ]]; then
      echo >&2 "Error: failed to find cray-postgres-operator chart in ${ROOTDIR}/helm."
      exit 1
    fi
    # check if file exists before applying crds, needed for backwards compatibility
    if tar -tf "$postgres_chart_path" cray-postgres-operator/files/postgres-operator-crds-1.10.1.yaml > /dev/null 2>&1; then
      # create CRDs for cray-postgres-operator, this is necessary when postgres is upgraded to 1.10.1 in CSM 1.7
      tar --extract --file="$postgres_chart_path" --to-stdout cray-postgres-operator/files/postgres-operator-crds-1.10.1.yaml | kubectl apply -f -
      # 5 second sleep is necessary for cray-postgres-operator chart deploy. Chart fails with CRD error if no sleep
      sleep 5
    else
      echo >&2 "Warning: File 'cray-postgres-operator/files/postgres-operator-crds-1.10.1.yaml' does not exist in $postgres_chart_path"
    fi
fi
deploy "${BUILDDIR}/manifests/${platform_yaml}"
deploy "${BUILDDIR}/manifests/${keycloak_gatekeeper_yaml}"

# TODO How to upgrade metallb?
# Deploy metal-lb configuration
# kubectl apply -f "$METALLB_YAML"

# Create secret with RPM signing keys
# For backward compatibility, also import hpe-signing-key.asc under the name "gpg-pubkey"
RPM_SIGNING_KEYS_OPT="--from-file gpg-pubkey=${ROOTDIR}/security/keys/rpm/hpe-signing-key.asc"
for key in ${ROOTDIR}/security/keys/rpm/*.asc; do
    RPM_SIGNING_KEYS_OPT="${RPM_SIGNING_KEYS_OPT} --from-file ${key}"
done
kubectl create secret generic hpe-signing-key -n services ${RPM_SIGNING_KEYS_OPT} --dry-run=client --save-config -o yaml | kubectl apply -f -

# Save previous Unbound IP
pre_upgrade_unbound_ip="$(kubectl get -n services service cray-dns-unbound-udp-nmn -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"

deploy "${BUILDDIR}/manifests/${core_services_yaml}"

# Wait for Unbound to come up
"${ROOTDIR}/lib/wait-for-unbound.sh"

# Verify Unbound settings
unbound_ip="$(kubectl get -n services service cray-dns-unbound-udp-nmn -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
if [[ "$pre_upgrade_unbound_ip" != "$unbound_ip" ]]; then
    echo >&2 "WARNING: Unbound IP has changed: $unbound_ip"
    echo >&2 "WARNING: Need to update nameserver settings on NCNs"
    # TODO pdsh command to update nameserver settings
fi

# In 1.5 the cray-conman Helm chart is replaced by console-[data,node,operator] charts but
# cray-conman needs to be removed if it exists.
undeploy -n services cray-conman

# Deploy remaining system management applications
deploy "${BUILDDIR}/manifests/${sysmgmt_yaml}"

# In 1.7 the old spire server is removed. The new cray-spire server should be around from 1.5 on.
# We first need to change the serviceAccountName in cray-spire daemonset request-ncn-join-token in
# case it is using the cray-spire-request-ncn-join-token service account which will be deleted with the
# undeploy of spire.
kubectl patch daemonsets.apps -n spire request-ncn-join-token --type='json' -p='[{"op": "replace", "path": '/spec/template/spec/serviceAccountName', "value":"default"}]'
undeploy -n spire spire

if [ "${K8SVER}" = "v1.32" ]; then
    # Wait for postgres pods to be running after upgrading postgres operator
    "${ROOTDIR}/lib/fix-postgres.sh"
fi

# Ensure updated pre-cache images have been pulled on each NCN worker,
# otherwise the Nexus upgrade may not be successful. This should be relatively
# quick since the daemon-set should have run since the platform manifest was
# deployed above and already pulled these images.
echo >&2 -n "Ensuring pre-cached images are pulled on NCN workers before upgrading Nexus..."
images=$(kubectl get configmap -n nexus cray-precache-images -o json | jq -r '.data.images_to_cache')
export PDSH_SSH_ARGS_APPEND="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
output=$(pdsh -b -S -w $(grep -oP 'ncn-w\w\d+' /etc/hosts | sort -u | tr -t '\n' ',') 'for image in '$images'; do crictl pull $image; done' 2>&1)
if [[ "$output" == *"failed"* ]]; then
    echo >&2 "FAIL"
    echo >&2 "$output"
    echo >&2""
    echo >&2 "Verify the images which failed in the output above are available in Nexus."
    exit 1
else
    echo >&2 "OK"
fi

# Deploy Nexus
deploy "${BUILDDIR}/manifests/${nexus_yaml}"

# Deploy Kyverno image verification policy - only if K8SVER is v1.32
if [ "${K8SVER}" = "v1.32" ]; then
    deploy "${BUILDDIR}/manifests/kyverno-policy.yaml"
fi

# Deploy Vshasta specific services
function is_vshasta_node {
    # This is the best check for an image specifically booted to vshasta
    [[ -f /etc/google_system ]] && return 0

    # metal images can still be booted on GCP, so check if there are any disks vendored by Google
    # if not, we conclude that this is not GCP
    lsblk --noheadings -o vendor | grep -q Google
    return $?
}

if is_vshasta_node; then
    deploy "${BUILDDIR}/manifests/vshasta.yaml"
fi

#
# Remove the old etcd operator now that new manifests have been applied
#
undeploy -n operators cray-etcd-operator

# Update BSS runcmd for master nodes to create /etc/cray/kubernetes
# and touch /etc/cray/kubernetes/upgrade. This is necessary to persist
# upgrade state across node reboots.
function get_token() {
  if [ -z "${TOKEN}" ]; then
    TOKEN=$(curl -s -S -d grant_type=client_credentials \
      -d client_id=admin-client \
      -d client_secret="$(kubectl get secrets admin-client-auth -o jsonpath='{.data.client-secret}' | base64 -d)" \
      https://api-gw-service-nmn.local/keycloak/realms/shasta/protocol/openid-connect/token | jq -r '.access_token')
    export TOKEN
    echo "${TOKEN}"
  fi
}

if [ "${K8SVER}" = "v1.24" ]; then
  # Get bootparameters and select only ncn-[mw]* hosts.
  cray bss bootparameters list --format json | jq '[.[] | select(."cloud-init"."meta-data"."local-hostname" | select(. != null) | match("ncn-[mw].*"))]' > /tmp/bootparameters.json

  # Adjust cloud-init runcmd on ncn-[mw]* hosts to create /etc/cray/kubernetes and
  # then touch /etc/cray/kubernetes/upgrade. This ensures that the upgrade file
  # persists across reboots. Note that this inserts the commands after the initial
  # runcmd command, 'set -xv'.
  jq '[.[] | select(."cloud-init"."meta-data"."local-hostname" | select(. != null) | match("ncn-[mw].*")) | ."cloud-init"."user-data".runcmd |= [.[0]] + ["mkdir -p /etc/cray/kubernetes", "touch /etc/cray/kubernetes/upgrade"] + .[1:]]' /tmp/bootparameters.json > /tmp/boot-parameters-patched.json

  # Patch BSS.
  readarray -t hosts < <(jq --compact-output '.[]' /tmp/boot-parameters-patched.json)

  for host in "${hosts[@]}"; do
    curl -s -i -k -H "Authorization: Bearer $(get_token)" -X PUT https://api-gw-service-nmn.local/apis/bss/boot/v1/bootparameters --data @<(echo -n ${host})
  done

  # Clean up.
  rm /tmp/bootparameters.json
  rm /tmp/boot-parameters-patched.json
fi

set +x
cat >&2 <<EOF
+ CSM applications and services upgraded
${0##*/}: OK
EOF
