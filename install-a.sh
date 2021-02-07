#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

if [[ !  -v SYSCONFDIR ]]; then
    if [[ ! -v SYSTEM_NAME ]]; then
        echo >&2 "error: environment variable not set: SYSTEM_NAME"
        exit 1
    fi
    SYSCONFDIR="/var/www/ephemeral/prep/${SYSTEM_NAME}"
fi

if [[ ! -d "$SYSCONFDIR" ]]; then
    echo >&2 "warning: no such directory: SYSCONFDIR: $SYSCONFDIR"
fi

: "${METALLB_YAML:="${SYSCONFDIR}/metallb.yaml"}"
if [[ ! -f "$METALLB_YAML" ]]; then
    echo >&2 "error: no such file: METALLB_YAML: $METALLB_YAML"
    exit 1
fi

: "${SLS_INPUT_FILE:="${SYSCONFDIR}/sls_input_file.json"}"
if [[ ! - f "$SLS_INPUT_FILE" ]]; then
    echo >&2 "error: no such file: SLS_INPUT_FILE: $SLS_INPUT_FILE"
    exit 1
fi

set -exo pipefail

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOTDIR}/lib/version.sh"
source "${ROOTDIR}/lib/install.sh"

: "${BUILDDIR:="${ROOTDIR}/build"}"
mkdir -p "$BUILDDIR"

[[ -f "${BUILDDIR}/customizations.yaml" ]] && rm -f "${BUILDDIR}/customizations.yaml"
kubectl get secrets -n loftsman site-init -o jsonpath='{.data.customizations\.yaml}' | base64 -d > "${BUILDDIR}/customizations.yaml"

# Generate manifests with customizations
manifestdir="${BUILDDOR}/manifests"
mkdir -p "${BUILDDIR}/manifests"
find "${ROOTDIR}/manifests" -name "*.yaml" | while read manifest; do
    manifestgen -i "$manifest" -c "${BUILDDIR}/customizations.yaml" -o "${BUILDDIR}/manifests/$(basename "$manifest")"
done

function deploy() {
    # XXX Loftsman may not be able to connect to $NEXUS_URL due to certificate
    # XXX trust issues, so use --charts-path instead of --charts-repo.
    loftsman ship --charts-path "${ROOTDIR}/helm" --manifest-path "$1"
}

# Deploy services critical for Nexus to run
deploy "${BUILDDIR}/manifests/storage.yaml"
deploy "${BUILDDIR}/manifests/platform.yaml"
deploy "${BUILDDIR}/manifests/keycloak-gatekeeper.yaml"

# TODO Deploy metal-lb configuration
kubectl apply -f "$METALLB_YAML"

# Upload SLS Input file to S3
csi upload-sls-file --sls-file "$SLS_INPUT_FILE"
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

    # sed -e "s/^\(NETCONFIG_DNS_STATIC_SERVERS\)=.*$/\1=\"${unbound_ip}\"/" -i /etc/sysconfig/network/config
    # netconfig update -f

3. Stop dnsmasq on the pit server:

    ${prompt} systemctl stop dnsmasq
    ${prompt} systemctl disable dnsmasq

4. Continue with the installation:

    ${prompt} ${ROOTDIR}/install.sh --continue

EOF
