#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

set -exo pipefail

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOTDIR}/lib/version.sh"
source "${ROOTDIR}/lib/install.sh"

: "${BUILDDIR:="${ROOTDIR}/build"}"

if [[ ! -d "$BUILDDIR" ]]; then
    echo >&2 "error: no such directory: $BUILDDIR"
    exit 1
fi

function deploy() {
    # XXX Loftsman may not be able to connect to $NEXUS_URL due to certificate
    # XXX trust issues, so use --charts-path instead of --charts-repo.
    loftsman ship --charts-path "${ROOTDIR}/helm" --manifest-path "$1"
}

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
nexus-upload raw "${ROOTDIR}/rpm/cray/csm/sle-15sp1"         "csm-${RELEASE_VERSION}-sle-15sp1"
nexus-upload raw "${ROOTDIR}/rpm/cray/csm/sle-15sp1-compute" "csm-${RELEASE_VERSION}-sle-15sp1-compute"
nexus-upload raw "${ROOTDIR}/rpm/cray/csm/sle-15sp2"         "csm-${RELEASE_VERSION}-sle-15sp2"
nexus-upload raw "${ROOTDIR}/rpm/shasta-firmware"       "shasta-firmware-${RELEASE_VERSION}"

clean-install-deps

# Deploy remaining system management applications
deploy "${BUILDDIR}/manifests/sysmgmt.yaml"
