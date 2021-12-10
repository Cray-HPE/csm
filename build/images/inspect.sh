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
    image="${1#docker://}"

    # Resolve image as an artifactory.algol60.net mirror
    image_mirror="$("${SRCDIR}/resolve.py" "$image" || exit 255)"

    # First, try to inspect the image mirror; skopeo will return a "404 (Not
    # Found) error if it has not yet been pulled.
    ref="$(skopeo-inspect "$image_mirror" || true)"
    if [[ -z "$ref" ]]; then
        # Second, try to inspect the image using the given ref
        ref="$(skopeo-inspect "$image" || true)"
        if [[ -z "$ref" ]]; then
            echo >&2 "error: failed to inspect image: $image"
            exit 255
        fi
        # The resulting ref needs to be resolved as a mirror
        ref="$("${SRCDIR}/resolve.py" "$ref" || exit 255)"
    fi

    printf '%s\t%s\n' "$image" "$ref"

    shift
done
