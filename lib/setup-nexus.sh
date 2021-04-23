#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

set -exo pipefail

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."
source "${ROOTDIR}/lib/version.sh"
source "${ROOTDIR}/lib/install.sh"

load-install-deps

# Setup Nexus
nexus-setup blobstores   "${ROOTDIR}/nexus-blobstores.yaml"
nexus-setup repositories "${ROOTDIR}/nexus-repositories.yaml"

# Upload assets to existing repositories
skopeo-sync "${ROOTDIR}/docker" 
nexus-upload helm "${ROOTDIR}/helm" "${CHARTS_REPO:-"charts"}"

# Upload repository contents
nexus-upload raw "${ROOTDIR}/rpm/cray/csm/sle-15sp2"         "csm-${RELEASE_VERSION}-sle-15sp2"
nexus-upload raw "${ROOTDIR}/rpm/cray/csm/sle-15sp2-compute" "csm-${RELEASE_VERSION}-sle-15sp2-compute"
nexus-upload raw "${ROOTDIR}/rpm/shasta-firmware"            "shasta-firmware-${RELEASE_VERSION}"

clean-install-deps

set +x
cat >&2 <<EOF
+ Nexus setup complete
setup-nexus.sh: OK
EOF
