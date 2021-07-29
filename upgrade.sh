#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

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

function deploy() {
    # XXX Loftsman may not be able to connect to $NEXUS_URL due to certificate
    # XXX trust issues, so use --charts-path instead of --charts-repo.
    loftsman ship --charts-path "${ROOTDIR}/helm" --manifest-path "$1"
}

# Undeploy the chart if it exists on the system.
# Use this if a chart has been removed from a manifest and needs
# to be removed from the system as part of an upgrade.
function undeploy() {
    # If the chart is missing (rc==1) just return success.
    helm status "$@" || return 0
    # Remove the chart.
    helm uninstall "$@"
}

# Check for manually create unbound PSP that is not managed by helm
function unbound_psp_check() {
    echo "Checking for manually created cray-unbound-coredns-psp"
    unbound_psp_exist="$(kubectl get ClusterRoleBinding -n services |grep cray-unbound-coredns-psp |wc -l)"||true
    if [[ "$unbound_psp_exist" -eq "1" ]]; then
        unbound_psp_helm_check="$(kubectl get ClusterRoleBinding -n services cray-unbound-coredns-psp -o yaml |grep helm |wc -l)"||true
        if [[ "$unbound_psp_helm_check" -eq "0" ]]; then
            echo "Found ClusterRoleBinding cray-dns-unbound-psp NOT managed by helm"
            kubectl delete ClusterRoleBinding -n services cray-unbound-coredns-psp
            echo "Delete ClusterRoleBinding cray-dns-unbound-psp"
        fi
    fi
    echo "cray-unbound-coredns-psp check Done"
}

# Deploy services critical for Nexus to run
deploy "${BUILDDIR}/manifests/storage.yaml"
deploy "${BUILDDIR}/manifests/platform.yaml"
deploy "${BUILDDIR}/manifests/keycloak-gatekeeper.yaml"

# TODO How to upgrade metallb?
# Deploy metal-lb configuration
# kubectl apply -f "$METALLB_YAML"

# Create secret with HPE signing key
if [[ -f "${ROOTDIR}/hpe-signing-key.asc" ]]; then
    kubectl create secret generic hpe-signing-key -n services --from-file=gpg-pubkey="${ROOTDIR}/hpe-signing-key.asc" --dry-run=client --save-config -o yaml | kubectl apply -f -
fi

# Save previous Unbound IP
pre_upgrade_unbound_ip="$(kubectl get -n services service cray-dns-unbound-udp-nmn -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"

# Check for manually create unbound PSP that is not managed by helm
unbound_psp_check

deploy "${BUILDDIR}/manifests/core-services.yaml"

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
deploy "${BUILDDIR}/manifests/sysmgmt.yaml"

# Deploy Nexus
deploy "${BUILDDIR}/manifests/nexus.yaml"

set +x
cat >&2 <<EOF
+ CSM applications and services upgraded
${0##*/}: OK
EOF
