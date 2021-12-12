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
    echo >&2 "+ skopeo inspect $img"
    docker run --rm "$SKOPEO_IMAGE" \
        --command-timeout 60s \
        --override-os linux \
        --override-arch amd64 \
        inspect \
        --retry-times 5 \
        --format "{{.Name}}@{{.Digest}}" \
        "$img"
}

[[ $# -gt 0 ]] || usage

while [[ $# -gt 0 ]]; do
    # Resolve image to canonical form, e.g., alpine -> docker.io/library/alpine
    image="$("${SRCDIR}/resolve.py" "${1#docker://}")"

    # Resolve image as an artifactory.algol60.net mirror
    image_mirror="$("${SRCDIR}/resolve.py" -m "$image" || exit 255)"

    # First, try to inspect the image mirror to get a digest-based reference;
    # skopeo will return a "404 (Not Found) error if it has not yet been
    # pulled.
    ref="$(skopeo-inspect "$image_mirror" || true)"
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
