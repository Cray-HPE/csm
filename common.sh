#!/usr/bin/env bash

export PACKAGING_TOOLS_IMAGE=${PACKAGING_TOOLS_IMAGE:-arti.hpc.amslabs.hpecorp.net/internal-docker-stable-local/packaging-tools:0.13.1}
export RPM_TOOLS_IMAGE=${RPM_TOOLS_IMAGE:-arti.hpc.amslabs.hpecorp.net/internal-docker-stable-local/rpm-tools:1.0.0}

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