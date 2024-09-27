#!/usr/bin/env bash

# Copyright 2021-2024 Hewlett Packard Enterprise Development LP

set -exo pipefail

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."
source "${ROOTDIR}/lib/version.sh"
source "${ROOTDIR}/lib/install.sh"

# Set podman --dns flags to unbound IP
podman_run_flags+=(--dns "$(kubectl get -n services service cray-dns-unbound-udp-nmn -o jsonpath='{.status.loadBalancer.ingress[0].ip}')")

load-install-deps

# Setup Nexus
nexus-setup blobstores   "${ROOTDIR}/nexus-blobstores.yaml"
nexus-setup repositories "${ROOTDIR}/nexus-repositories.yaml"

# Upload assets to existing repositories
skopeo-sync "${ROOTDIR}/docker"

# Tag SAT image as csm-latest
sat_image="artifactory.algol60.net/csm-docker/stable/cray-sat"
# This value is replaced by release.sh at CSM release distribution build time
sat_version="@SAT_VERSION@"
# This csm-latest tag is being phased out, but still used as a default
skopeo-copy "${sat_image}:${sat_version}" "${sat_image}:csm-latest"
# Bootstrap sat by writing the sat version to the file used by the sat-podman
# wrapper script. This is later written by the CSM layer of the CFS config.
mkdir -p /opt/cray/etc/sat
echo "${sat_version}" > /opt/cray/etc/sat/version

nexus-upload helm "${ROOTDIR}/helm" "${CHARTS_REPO:-"charts"}"

# Upload repository contents
nexus-upload raw "${ROOTDIR}/rpm/cray/csm/noos"              "csm-${RELEASE_VERSION}-noos"
nexus-upload raw "${ROOTDIR}/rpm/cray/csm/sle-15sp2"         "csm-${RELEASE_VERSION}-sle-15sp2"
nexus-upload raw "${ROOTDIR}/rpm/cray/csm/sle-15sp3"         "csm-${RELEASE_VERSION}-sle-15sp3"
nexus-upload raw "${ROOTDIR}/rpm/cray/csm/sle-15sp4"         "csm-${RELEASE_VERSION}-sle-15sp4"
nexus-upload raw "${ROOTDIR}/rpm/cray/csm/sle-15sp5"         "csm-${RELEASE_VERSION}-sle-15sp5"
nexus-upload raw "${ROOTDIR}/rpm/cray/csm/sle-15sp6"         "csm-${RELEASE_VERSION}-sle-15sp6"
nexus-upload raw "${ROOTDIR}/rpm/embedded"                   "csm-${RELEASE_VERSION}-embedded"

# Update the cray-sat-podman package to ensureversion consistency
zypper update cray-sat-podman

clean-install-deps

set +x
cat >&2 <<EOF
+ Nexus setup complete
setup-nexus.sh: OK
EOF
