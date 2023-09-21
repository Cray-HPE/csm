#!/usr/bin/env bash

export SKOPEO_IMAGE=${SKOPEO_IMAGE:-artifactory.algol60.net/csm-docker/stable/quay.io/skopeo/stable:v1}
export YQ_IMAGE=${YQ_IMAGE:-artifactory.algol60.net/csm-docker/stable/docker.io/mikefarah/yq:4}
export PACKAGING_TOOLS_IMAGE=${PACKAGING_TOOLS_IMAGE:-arti.hpc.amslabs.hpecorp.net/internal-docker-stable-local/packaging-tools:0.13.0}
export RPM_TOOLS_IMAGE=${RPM_TOOLS_IMAGE:-arti.hpc.amslabs.hpecorp.net/internal-docker-stable-local/rpm-tools:1.0.0}

if [ -z "${ARTIFACTORY_USER}" ] || [ -z "${ARTIFACTORY_TOKEN}" ]; then
    echo "Missing authentication information for image download. Please set ARTIFACTORY_USER and ARTIFACTORY_TOKEN environment variables."
    exit 1
fi

REPO_CREDS_DOCKER_OPTIONS=""
REPO_CREDS_RPMSYNC_OPTIONS=""
if [ ! -z "$ARTIFACTORY_USER" ] && [ ! -z "$ARTIFACTORY_TOKEN" ]; then
    #code to store credentials in environment variable
    export REPOCREDSVARNAME="REPOCREDSVAR"
    export REPOCREDSVAR=$(jq --null-input --arg url "https://artifactory.algol60.net/artifactory/" --arg realm "Artifactory Realm" --arg user "$ARTIFACTORY_USER"   --arg password "$ARTIFACTORY_TOKEN"   '{($url): {"realm": $realm, "user": $user, "password": $password}}')
    REPO_CREDS_DOCKER_OPTIONS="-e ${REPOCREDSVARNAME}"
    REPO_CREDS_RPMSYNC_OPTIONS="-c ${REPOCREDSVARNAME}"
fi

export RPM_SYNC="docker run ${REPO_CREDS_DOCKER_OPTIONS} --rm -i ${PACKAGING_TOOLS_IMAGE} rpm-sync ${REPO_CREDS_RPMSYNC_OPTIONS}"
export YQ="docker run --rm -i $YQ_IMAGE"
