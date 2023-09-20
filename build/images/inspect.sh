#!/usr/bin/env bash

set -euo pipefail

ROOTDIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")/../..")
source "${ROOTDIR}/common.sh"

function usage() {
    echo >&2 "usage: ${0##*/} IMAGE..."
    exit 255
}

function skopeo-inspect() {
    local img="docker://$1"
    local creds=""
    [[ "${1}" == artifactory.algol60.net/* ]] && creds="${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}"
    echo >&2 "+ skopeo inspect $img"
    skopeo \
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
        base_images=$(realpath "${ROOTDIR}/dist/csm-${CSM_BASE_VERSION}-images.txt")
        image_record=$(cat "${base_images}" | tr '\t' ',' | grep -F "${image},"  || true)
        if [ -z "${image_record}" ]; then
            echo "+ WARNING: image ${image} was not part of CSM build ${CSM_BASE_VERSION}, will calculate new digest" >&2
        else
            IFS=, read -r logical_image physical_image <<< "${image_record}"
            image_name=$(echo "${logical_image}" | cut -f1 -d:)
            # manifest_file=$(realpath "${ROOTDIR}/dist/csm-${CSM_BASE_VERSION}/docker/${image}/manifest.json")
            sha256sum_expected=$(echo "${physical_image}" | cut -f2 -d:)
            # sha256sum_actual=$(sha256sum "${manifest_file}" | cut -f 1 -d ' ')
            # # Checksum mismatch happens when multi-arch digest is recorded in images.txt, but single-arch digest is stored in tarball.
            # # We can re-enable this when we run skopeo-copy during build with "--all", which will store multi-platform manifest with right checksum
            # # and all of it's references, not just a signle reference for specific arch/os.
            # if [ "${sha256sum_expected}" != "${sha256sum_actual}" ]; then
            #     echo "+ WARNING: sha256sum for image ${image} in ${base_images} (${sha256sum_expected}) does not match actual sha256sum of ${manifest_file} (${sha256sum_actual})" >&2
            #     exit 255
            # fi
            image_name=$(echo "${logical_image}" | cut -f1 -d:)
            ref="${image_name}@sha256:${sha256sum_expected}"
            echo "+ INFO: reusing $ref from $CSM_BASE_VERSION for $image" >&2
        fi
    fi

    if [[ -z "$ref" ]]; then
        ref=$(skopeo-inspect "$image_mirror")
    fi

    # Output maps "logical" refs to "physical" digest-based refs
    printf '%s\t%s\n' "$image" "$ref"

    shift
done
