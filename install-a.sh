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
if [[ ! -f "$SLS_INPUT_FILE" ]]; then
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

# Update DNS settings on the pit server
unbound_ip="$(kubectl get -n services service cray-dns-unbound-udp-nmn -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
sed -e "s/^\(NETCONFIG_DNS_STATIC_SERVERS\)=.*$/\1=\"${unbound_ip}\"/" -i /etc/sysconfig/network/config
netconfig update -f
systemctl stop dnsmasq
systemctl disable dnsmasq

function get-token() {
    local client_secret="$(kubectl get secrets admin-client-auth -o jsonpath='{.data.client-secret}' | base64 -d)"
    curl -sSk \
        -d grant_type=client_credentials \
        -d client_id=admin-client \
        -d client_secret=${client_secret} \
        'https://api-gw-service-nmn.local/keycloak/realms/shasta/protocol/openid-connect/token' \
    | jq -r '.access_token'
}

function list-ncns() {
    curl -sSk \
        -H "Authorization: Bearer $(get-token)" \
        'https://api-gw-service-nmn.local/apis/sls/v1/search/hardware?extra_properties.Role=Management' \
    | jq -r '.[] | .ExtraProperties.Aliases[]'
}

# Change DNS settings on each NCN
ncns="$(list-ncns | paste -s -d , -)"
pdsh -w "${ncns}" "sed -e 's/^\(NETCONFIG_DNS_STATIC_SERVERS\)=.*$/\1=\"${unbound_ip}\"/' -i /etc/sysconfig/network/config; netconfig update -f"

# Output instructions for continuing installation
cat >&2 <<EOF


Critical platform services are deployed.

Before continuing the installation:

1. Verify dnsmasq is DISABLED on the pit server:

     pit# systemctl status dnsmasq

2. Verify the pit server is configured to use Unbound at ${unbound_ip}:

     pit# cat /etc/resolv.conf | grep nameserver

3. Verify every NCN is configured to use Unbound at ${unbound_ip}:

     pit# pdsh -w "${ncns}" "cat /etc/resolv.conf | grep nameserver"

TAKE CORRECTIVE ACTION if the pit server or any NCN does not include
${unbound_ip} as a nameserver in /etc/resolv.conf. Nameservers should
be defined in the "NETCONFIG_DNS_STATIC_SERVERS" variable in
/etc/sysconfig/network/config, then run "netconfig update -f" to update the
settings in /etc/resolv.conf.

Once the DNS settings have been verified on all NCNs to use Unbound at
${unbound_ip}, continue with the installation from the pit server:

    pit# ${ROOTDIR}/install.sh --continue

EOF
