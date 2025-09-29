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
nexus-upload raw "${ROOTDIR}/rpm/cray/csm/sle-15sp7"         "csm-${RELEASE_VERSION}-sle-15sp7"
nexus-upload raw "${ROOTDIR}/rpm/embedded"                   "csm-${RELEASE_VERSION}-embedded"

clean-install-deps

set +x
cat >&2 <<EOF
+ Nexus setup complete
setup-nexus.sh: OK
EOF
