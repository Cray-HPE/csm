#!/usr/bin/env bash

# Copyright 2020 Hewlett Packard Enterprise Development LP

set -ex
set -o pipefail

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

# TODO Apply workarounds in csm-installer-workarounds
echo >2 "warning: TODO apply workarounds in fix/"

# TODO Deploy metal-lb configuration
: "${SYSCONFDIR:="/var/www/ephemeral/prep/<system-name>"}"
kubectl apply -f "${SYSCONFDIR}/metallb.yaml"

# Upload SLS Input file to S3
csi upload-sls-file --sls-file "${SYSCONFDIR}/sls_input_file.json"
deploy "${BUILDDIR}/manifests/core-services.yaml"

# Deploy Nexus
deploy "${BUILDDIR}/manifests/nexus.yaml"

load-install-deps

# Setup Nexus
nexus-setup blobstores   "${ROOTDIR}/nexus-blobstores.yaml"
nexus-setup repositories "${ROOTDIR}/nexus-repositories.yaml"

# Upload assets to existing repositories
skopeo-sync "${ROOTDIR}/docker" 
nexus-upload helm "${ROOTDIR}/helm" "${CHARTS_REPO:-"charts"}"

# Upload repository contents
nexus-upload raw "${ROOTDIR}/rpm/csm-sle-15sp1"         "csm-${RELEASE_VERSION}-sle-15sp1"
nexus-upload raw "${ROOTDIR}/rpm/csm-sle-15sp1-compute" "csm-${RELEASE_VERSION}-sle-15sp1-compute"
nexus-upload raw "${ROOTDIR}/rpm/csm-sle-15sp2"         "csm-${RELEASE_VERSION}-sle-15sp2"
nexus-upload raw "${ROOTDIR}/rpm/shasta-firmware"       "shasta-firmware-${RELEASE_VERSION}"

clean-install-deps

# Deploy remaining system management applications
deploy "${BUILDDIR}/manifests/sysmgmt.yaml"
