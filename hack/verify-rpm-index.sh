#!/usr/bin/env bash

# Copyright 2021, 2023 Hewlett Packard Enterprise Development LP

PACKAGING_TOOLS_IMAGE="arti.hpc.amslabs.hpecorp.net/internal-docker-stable-local/packaging-tools:0.13.0"

set -o errexit
set -o pipefail

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."

[[ $# -gt 0 ]] || set -- "${ROOTDIR}/rpm/cray/csm/sle-15sp2/index.yaml" "${ROOTDIR}/rpm/cray/csm/sle-15sp2-compute/index.yaml"

#pass the repo credentials environment variables to the container that runs rpm-sync
REPO_CREDS_DOCKER_OPTIONS=""
REPO_CREDS_RPMSYNC_OPTIONS=""
if [ ! -z "$ARTIFACTORY_USER" ] && [ ! -z "$ARTIFACTORY_TOKEN" ]; then
    #code to store credentials in environment variable
    export REPOCREDSVARNAME="REPOCREDSVAR"
    export REPOCREDSVAR=$(jq --null-input --arg url "https://artifactory.algol60.net/artifactory/" --arg realm "Artifactory Realm" --arg user "$ARTIFACTORY_USER"   --arg password "$ARTIFACTORY_TOKEN"   '{($url): {"realm": $realm, "user": $user, "password": $password}}')
    REPO_CREDS_DOCKER_OPTIONS="-e ${REPOCREDSVARNAME}"
    REPO_CREDS_RPMSYNC_OPTIONS="-c ${REPOCREDSVARNAME}"
fi

while [[ $# -gt 0 ]]; do
    docker run ${REPO_CREDS_DOCKER_OPTIONS} --rm -i "$PACKAGING_TOOLS_IMAGE" rpm-sync ${REPO_CREDS_RPMSYNC_OPTIONS} -v -n 32 - >/dev/null < "$1"
    shift
done
