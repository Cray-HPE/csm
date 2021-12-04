#!/usr/bin/env bash

: "${SKOPEO_IMAGE:=quay.io/skopeo/stable:v1.4.1}"

set -euo pipefail

[[ $# -gt 0 ]] || {
    echo >&2 "usage: ${0##*/} DIR IMAGE ..."
    exit 255
}

destdir="$1"
shift

while [[ $# -gt 0 ]]; do
    image="$1"
    shift

    echo >&2 "+ skopeo copy $image"

    if [[ -e "${destdir}/${image}" ]]; then
        echo >&2 "error: File exists: ${destdir}/${image}"
        exit 255
    fi

    mkdir -p "${destdir}/${image}"

    # Copy image
    docker run --rm \
        -u "$(id -u):$(id -g)" \
        -v "$(realpath -m "$destdir"):/data" \
        "$SKOPEO_IMAGE" \
        --override-os linux --override-arch amd64 \
        copy --retry-times 5 --all "docker://$image" "dir:/data/$image" >&2 || exit 255
done
