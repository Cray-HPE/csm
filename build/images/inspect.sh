#!/usr/bin/env bash

set -euo pipefail

SRCDIR="$(dirname "${BASH_SOURCE[0]}")"
. "${SRCDIR}/common.sh"

function usage() {
    echo >&2 "usage: ${0##*/} IMAGE..."
    exit 255
}

function skopeo-inspect() {
    local img="docker://$1"
    local creds=""
    [[ "${1}" == artifactory.algol60.net/* ]] && creds="${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}"
    # echo >&2 "+ skopeo inspect $img"
    docker run --rm "$SKOPEO_IMAGE" \
        --command-timeout 60s \
        --override-os linux \
        --override-arch amd64 \
        inspect \
        --retry-times 5 \
        ${creds:+--creds "${creds}"} \
        --format "{{.Name}}@{{.Digest}}" \
        "$img"
}

function resolve_canonical() {
    local image="${1#docker://}"
    if [[ "${image}" != *.*:* ]]; then
        # alpine:latest > docker.io/library/alpine:latest
        echo "docker.io/library/${image}"
    else
        # nothing needs to be changed
        echo "${image}"
    fi
}

# All images must come from artifactory.algol60.net/csm-docker/stable. Otherwise, we
# can't guarantee reproducibility of builds, when CSM_BASE_VERSION is set.
function resolve_mirror() {
    local image="${1#docker://}"
    if [[ "$image" == artifactory.algol60.net/csm-docker/stable/* ]]; then
        # nothing needs to be changed
        echo "${image}"
    elif [[ "$image" == artifactory.algol60.net/sat-docker/stable/* ]]; then
        # nothing needs to be changed
        echo "${image}"
    else
        # docker.io/library/alpine:latest > artifactory.algol60.net/csm-docker/stable/docker.io/library/alpine:latest
        # quay.io/skopeo/stable:v1.4.1 > artifactory.algol60.net/csm-docker/stable/quay.io/skopeo/stable:v1.4.1
        echo "artifactory.algol60.net/csm-docker/stable/${image}"
    fi
}

[[ $# -gt 0 ]] || usage

while [[ $# -gt 0 ]]; do
    # Resolve image to canonical form, e.g., alpine -> docker.io/library/alpine
    image="$(resolve_canonical "${1#docker://}")"

    # Resolve image as an artifactory.algol60.net mirror
    image_mirror="$(resolve_mirror "$image")"

    ref=""

    # Try to re-use image digest from base version, if we are building patch release.
    if [ -n "${CSM_BASE_VERSION:-}" ]; then
        image_record=$(cat "${SRCDIR}/base_index.txt" | tr '\t' ',' | grep -F "${image_mirror},"  || true)
        if [ -z "${image_record}" ]; then
            echo "+ WARNING: image ${image_mirror} was not part of CSM build ${CSM_BASE_VERSION}, will calculate new digest" >&2
        else
            IFS=, read -r logical_image physical_image <<< "${image_record}"
            ref="$(skopeo-inspect "${physical_image}" || true)"
            if [ -z "${ref}" ]; then
                if [ "${FAIL_ON_MISSED_IMAGE_DIGEST:-}" == "true" ]; then
                    echo "+ ERROR: image ${physical_image} can not be downloaded and FAIL_ON_MISSED_IMAGE_DIGEST flag is set to 'true'." >&2
                    exit 255
                else
                    echo "+ WARNING: image ${physical_image} can not be downloaded, but FAIL_ON_MISSED_IMAGE_DIGEST flag is set to 'false'. Will calculate new digest for ${logical_image}." >&2
                fi
            else
                echo "+ INFO: reusing $ref from $CSM_BASE_VERSION for $image" >&2
            fi
        fi
    fi

    if [[ -z "$ref" ]]; then
        ref=$(skopeo-inspect "$image_mirror")
    fi

    # Output maps "logical" refs to "physical" digest-based refs
    printf '%s\t%s\n' "$image" "$ref"

    shift
done
