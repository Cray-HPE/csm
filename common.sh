#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2024 Hewlett Packard Enterprise Development LP
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

export PACKAGING_TOOLS_IMAGE=${PACKAGING_TOOLS_IMAGE:-artifactory.algol60.net/dst-docker-mirror/internal-docker-stable-local/packaging-tools:0.14.0}
export RPM_TOOLS_IMAGE=${RPM_TOOLS_IMAGE:-artifactory.algol60.net/dst-docker-mirror/internal-docker-stable-local/rpm-tools:1.0.0}
export SKOPEO_IMAGE=${SKOPEO_IMAGE:-artifactory.algol60.net/csm-docker/stable/quay.io/skopeo/stable:v1}
export CRAY_NEXUS_SETUP_IMAGE=${CRAY_NEXUS_SETUP_IMAGE:-artifactory.algol60.net/csm-docker/stable/cray-nexus-setup:0.11.0}

if [ -z "${ARTIFACTORY_USER}" ] || [ -z "${ARTIFACTORY_TOKEN}" ]; then
    echo "Missing authentication information for image download. Please set ARTIFACTORY_USER and ARTIFACTORY_TOKEN environment variables."
    exit 1
fi

function acurl() {
    curl -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" "$@"
}

export REPOCREDSVARNAME="REPOCREDSVAR"
export REPOCREDSVAR=$(jq --null-input --arg url "https://artifactory.algol60.net/artifactory/" --arg realm "Artifactory Realm" --arg user "$ARTIFACTORY_USER"   --arg password "$ARTIFACTORY_TOKEN"   '{($url): {"realm": $realm, "user": $user, "password": $password}}')
export REPO_CREDS_DOCKER_OPTIONS="-e ${REPOCREDSVARNAME}"
export REPO_CREDS_RPMSYNC_OPTIONS="-c ${REPOCREDSVARNAME}"

ROOTDIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
RELEASE_NAME=${RELEASE_NAME:-csm}
RELEASE_VERSION=$("${ROOTDIR}"/version.sh)
RELEASE_VERSION_MAJOR=$(echo "${RELEASE_VERSION}" | cut -f1 -d.)
RELEASE_VERSION_MINOR=$(echo "${RELEASE_VERSION}" | cut -f2 -d.)
RELEASE=${RELEASE:-${RELEASE_NAME}-${RELEASE_VERSION}}
BUILDDIR=${BUILDDIR:-${ROOTDIR}/dist/${RELEASE}}
CSM_BASE_VERSION=${CSM_BASE_VERSION:-}

# Use a newer version of cfs-config-util that hasn't rolled out to other products yet
CFS_CONFIG_UTIL_IMAGE="artifactory.algol60.net/csm-docker/stable/cfs-config-util:5.1.1"

# Find files in a given Artifactory repo by Ant style glob pattern (may occur in path and file name),
# retrieve version by searching for last inclusion of X.Y.Z pattern in full name (i.e. path + "/" + filename),
# sort by version (numerically) and print path to last artifact within repo.
#
# Examples:
#   resolve_globs csm-images stable/kubernetes/6.2.*/6.4.0-*-6.2.*-x86_64.kernel > stable/kubernetes/6.2.29/6.4.0-150600.23.17-default-6.2.29-x86_64.kernel
#   resolve_globs csm-rpms 'hpe/stable/noos/*' 'docs-csm-1.4.*.noarch.rpm' > hpe/stable/noos/docs-csm/1.4/noarch/docs-csm-1.4.180-1.noarch.rpm
#
function resolve_globs() {
    local repo="${1}"
    local path_pattern="${2}"
    local name_pattern="${3}"
    if [[ "${path_pattern}" == *\** ]] || [[ "${name_pattern}" == *\** ]]; then
        if [ -n "${CSM_BASE_VERSION:-}" ]; then
            echo "ERROR resolving glob ${repo}/${path_pattern}/${name_pattern}: globs are not supported when CSM is in release mode (CSM_BASE_VERSION is set)" >&2
            exit 1
        fi
        result=$(
            acurl -Ss --fail-with-body -X POST -H 'Content-Type: text/plain' -Ss --data-binary @- "https://artifactory.algol60.net/artifactory/api/search/aql" <<-EOF
items.find(
    {
        "repo": {"\$eq": "${repo}"},
        "path": {"\$match": "${path_pattern}"},
        "name": {"\$match": "${name_pattern}"}
    }
)
EOF
        )
        if [ $? -ne 0 ]; then
            echo "ERROR resolving glob ${repo}/${path_pattern}/${name_pattern}:" >&2
            echo "${result}" >&2
            exit 1
        fi
        if [ "$(echo "${result}" | jq -r '.results | length')" == "0" ]; then
            echo "ERROR resolving glob ${repo}/${path_pattern}/${name_pattern}: pattern does not match anything" >&2
            exit 1
        fi
        echo "${result}" | \
            jq -r '.results | map({"path": .path, "name": .name, "version": ((.path + "/" + .name) | sub(".*[^\\d](?<version>\\d+\\.\\d+\\.\\d+)[^\\d].*"; "\(.version)")) })
                | sort_by(.version | split(".") | map(tonumber)) | last | (.path + "/" + .name)'
    else
        # Skip API call if there are no globs
        echo "${path_pattern}/${name_pattern}"
    fi
}

# Add component version to version digest YAML file.
#
# Usage: write_version_digest <.yq.path.to.array> <value>
# Example: write_version_digest .helm csm-algol60/cray-nexus:0.12.2
#
function write_version_digest() {
    local path="${1}"
    local value="${2}"
    local file="${ROOTDIR}/dist/csm-${RELEASE_VERSION}-versions.yaml"
    mkdir -p "${ROOTDIR}/dist"
    touch "${file}"
    yq e -i "${path} += [\"${value}\"]" "${file}" || (echo "ERROR adding value to array \"${path}\" in file ${file}"; exit 1)
}
