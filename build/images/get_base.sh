#!/usr/bin/env bash

set -e -o pipefail

SRCDIR="$(dirname "${BASH_SOURCE[0]}")"
. "${SRCDIR}/common.sh"

function acurl() {
    curl -Ss -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_TOKEN}" $@
}

if [ -n "${CSM_BASE_VERSION}" ]; then
    uri=$(acurl "https://artifactory.algol60.net/artifactory/api/search/artifact?name=csm-${CSM_BASE_VERSION}-images.txt&repos=csm-releases" | jq -r '.results[].uri' | head -1)
    if [ -n "${uri}" ]; then
        uri=$(acurl "${uri}" | jq -r '.downloadUri')
        echo "Downloading base image digest file ${uri} ..."
        acurl -o "${SRCDIR}/base_index.txt" "${uri}"
    else
        echo "ERROR: image digest file csm-${CSM_BASE_VERSION}-images.txt is not found under https://artifactory.algol60.net/artifactory/csm-releases/"
        exit 255
    fi
else
    echo "Environment variable CSM_BASE_VERSION is not set, will calculate new image digests."
fi
