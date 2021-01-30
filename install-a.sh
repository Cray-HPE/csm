#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

set -exo pipefail

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOTDIR}/lib/version.sh"
source "${ROOTDIR}/lib/install.sh"

: "${BUILDDIR:="${ROOTDIR}/build"}"
mkdir -p "$BUILDDIR"

# system specific shasta-cfg dist/repo clone
: "${SITE_INIT:="/var/www/ephemeral/prep/site-init"}"
CUSTOMIZATIONS="${SITE_INIT}/customizations.yaml"

# Generate manifests with customizations
mkdir -p "${BUILDDIR}/manifests"
find "${ROOTDIR}/manifests" -name "*.yaml" | while read manifest; do
    manifestgen -i "$manifest" -c "$CUSTOMIZATIONS" -o "${BUILDDIR}/manifests/$(basename "$manifest")"
done

# Deploy sealed secret key
${SITE_INIT}/deploy/deploydecryptionkey.sh

function deploy() {
    # XXX Loftsman may not be able to connect to $NEXUS_URL due to certificate
    # XXX trust issues, so use --charts-path instead of --charts-repo.
    loftsman ship --charts-path "${ROOTDIR}/helm" --manifest-path "$1"
}

# Deploy services critical for Nexus to run
deploy "${BUILDDIR}/manifests/storage.yaml"
deploy "${BUILDDIR}/manifests/platform.yaml"
deploy "${BUILDDIR}/manifests/keycloak-gatekeeper.yaml"

## TODO Apply workarounds in csm-installer-workarounds
echo >&2 "warning: TODO apply workarounds in fix/"

# TODO Deploy metal-lb configuration
: "${SYSCONFDIR:="/var/www/ephemeral/prep/surtur/surtur"}"
kubectl apply -f "${SYSCONFDIR}/metallb.yaml"

# Upload SLS Input file to S3
csi upload-sls-file --sls-file "${SYSCONFDIR}/sls_input_file.json"
deploy "${BUILDDIR}/manifests/core-services.yaml"

"${ROOTDIR}/lib/wait-for-unbound.sh"

prompt="pit:$(pwd) #"
unbound_ip="$(kubectl get -n services service cray-dns-unbound-udp-nmn -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"

cat >&2 <<EOF

Continue with the installation after performing the following steps to switch
DNS settings from dnsmasq on the pit server to Unbound running in Kubernetes:

1. Unbound is listening on ${unbound_ip}, verify it is working by resolving
   e.g., ncn-w001.nmn:

    ${prompt} dig "@${unbound_ip}" +short ncn-w001.nmn

2. Run the following two commands on all NCN manager, worker, and storage
   nodes as well as the pit server:

    ${prompt} sed -e "s/^\(NETCONFIG_DNS_STATIC_SERVERS\)=.*$/\1=\"${unbound_ip}\"/" -i /etc/sysconfig/network/config
    ${prompt} netconfig update -f

3. Stop dnsmasq on the pit server:

    ${prompt} systemctl stop dnsmasq
    ${prompt} systemctl disable dnsmasq

4. Continue with the installation:

    ${prompt} ${ROOTDIR}/install.sh --continue

EOF
