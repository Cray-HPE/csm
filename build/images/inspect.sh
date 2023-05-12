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
    # echo >&2 "+ skopeo inspect $img"
    docker run --rm "$SKOPEO_IMAGE" \
        --command-timeout 60s \
        --override-os linux \
        --override-arch amd64 \
        inspect \
        --retry-times 5 \
        --creds "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" \
        --format "{{.Name}}@{{.Digest}}" \
        "$img"
}

[[ $# -gt 0 ]] || usage

while [[ $# -gt 0 ]]; do
    # Resolve image to canonical form, e.g., alpine -> docker.io/library/alpine
    image="$("${SRCDIR}/resolve.py" "${1#docker://}")"

    # Resolve image as an artifactory.algol60.net mirror
    image_mirror="$("${SRCDIR}/resolve.py" -m "$image" || exit 255)"

    ref=""

    # Try to re-use image digest from base version, if we are building patch release.
    if [ -n "${CSM_BASE_VERSION:-}" ]; then
        image_record=$(grep "${image_mirror}\t" "${SRCDIR}/base_index.txt" || true)
        if [ -z "${image_record}" ]; then
            if [ "${image}" != "${image_mirror}" ]; then
                image_record=$(grep "${image}\t" "${SRCDIR}/base_index.txt" || true)
                if [ -z "${image_record}" ]; then
                    echo "+ WARNING: neither image ${image_mirror} nor ${image} were part of CSM build ${CSM_BASE_VERSION}, will calculate new digest" >&2
                fi
            else
                echo "+ WARNING: image ${image_mirror} was not part of CSM build ${CSM_BASE_VERSION}, will calculate new digest" >&2
            fi
        fi
        if [ -n "${image_record}" ]; then
            physical_image=$(echo -e "${image_record}" | cut -f1)
            logical_image=$(echo -e "${image_record}" | cut -f2)
            ref="$(skopeo-inspect "${physical_image}" || true)"
            if [ -z "${ref}" ]; then
                if [ "${FAIL_ON_MISSED_IMAGE_DIGEST:-}" == "true" ]; then
                    echo "+ ERROR: image ${physical_image} can not be downloaded and FAIL_ON_MISSED_IMAGE_DIGEST flag is set to 'true'." >&2
                    exit 255
                else
                    echo "+ WARNING: image ${physical_image} can not be downloaded, but FAIL_ON_MISSED_IMAGE_DIGEST flag is set to 'false'. Will calculate new digest for ${logical_image}." >&2
                fi
            fi
        fi
    fi

    # First, try to inspect the image mirror to get a digest-based reference;
    # skopeo will return a "404 (Not Found) error if it has not yet been
    # pulled.
    if [[ -z "$ref" ]]; then
        ref="$(skopeo-inspect "$image_mirror" || true)"
    fi
    if [[ -z "$ref" ]]; then
        # Second, try to inspect the image using the non-mirror
        # (i.e., upstream) image to get a digest-based reference
        ref="$(skopeo-inspect "$image" || true)"
        if [[ -z "$ref" ]]; then
            echo >&2 "error: failed to inspect image: $image"
            exit 255
        fi
        # In the second case the digest-based reference then needs to be
        # re-resolved as a mirror.
        ref="$("${SRCDIR}/resolve.py" -m "$ref" || exit 255)"
    fi

    # Output maps "logical" refs to "physical" digest-based refs
    printf '%s\t%s\n' "$image" "$ref"

    shift
done
