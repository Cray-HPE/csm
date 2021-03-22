#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

# By default, not an upgrade
: "${IS_UPGRADE:="no"}"

INSTALL_CMD="${0##*/}"
INSTALL_OPTS="$@"

function usage() {
    echo >&2 "usage: ${INSTALL_CMD} [--upgrade]"
    exit 2
}

while [[ $# -gt 0 ]]; then
    case "$1" in
    -h|--help)
        usage
        ;;
    -u|--upgrade)
        echo >&2 "Upgrading CSM components..."
        echo >&2
        IS_UPGRADE="yes"
        ;;
    *)
        echo >&2 "unknown option: $1"
        usage
        ;;
    esac
    shift
done

if [[ "${IS_UPGRADE:-"no"}" != "yes" ]]; then
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
fi

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

# Deploy services critical for Nexus to run
deploy "${BUILDDIR}/manifests/storage.yaml"
deploy "${BUILDDIR}/manifests/platform.yaml"
deploy "${BUILDDIR}/manifests/keycloak-gatekeeper.yaml"

# Deploy metal-lb configuration
[[ -v METALLB_YAML ]] && kubectl apply -f "$METALLB_YAML"

# Upload SLS Input file to S3
[[ -v SLS_INPUT_FILE ]] && csi upload-sls-file --sls-file "$SLS_INPUT_FILE"

if [[ "${IS_UPGRADE:-"no"}" == "yes" ]]; then
    # Save previous Unbound IP
    pre_upgrade_unbound_ip="$(kubectl get -n services service cray-dns-unbound-udp-nmn -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
fi

deploy "${BUILDDIR}/manifests/core-services.yaml"

# Wait for Unbound to come up
"${ROOTDIR}/lib/wait-for-unbound.sh"

# Verify Unbound settings
unbound_ip="$(kubectl get -n services service cray-dns-unbound-udp-nmn -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
if [[ "${IS_UPGRADE:-"no"}" == "yes" ]]; then
    if [[ "$pre_upgrade_unbound_ip" != "$unbound_ip" ]]; then
        echo >&2 "WARNING: Unbound IP has changed: $unbound_ip"
        echo >&2 "WARNING: Need to update nameserver settings on NCNs"
        # TODO pdsh command to update nameserver settings
    fi
else
    # Update DNS settings on the pit server
    sed -e "s/^\(NETCONFIG_DNS_STATIC_SERVERS\)=.*$/\1=\"${unbound_ip}\"/" -i /etc/sysconfig/network/config
    netconfig update -f
    systemctl stop dnsmasq
    systemctl disable dnsmasq
fi

# Deploy remaining system management applications
deploy "${BUILDDIR}/manifests/sysmgmt.yaml"

# Deploy Nexus
deploy "${BUILDDIR}/manifests/nexus.yaml"

set +x
cat >&2 <<EOF
+ CSM applications and services deployed
${INSTALL_CMD}: OK
EOF
