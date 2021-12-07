#!/usr/bin/env bash

: "${SKOPEO_IMAGE:=artifactory.algol60.net/quay.io/skopeo/stable:v1.4.1}"

set -euo pipefail

function get-repo-upstream() {
    echo "$1" | sed \
        -e 's/^artifactory.algol60.net\/docker.io\//docker\.io\//' \
        -e 's/^artifactory.algol60.net\/gcr.io\//gcr\.io\//' \
        -e 's/^artifactory.algol60.net\/k8s.gcr.io\//k8s\.gcr\.io\//' \
        -e 's/^artifactory.algol60.net\/quay.io\//quay\.io\//'
}

[[ $# -gt 0 ]] || {
    echo >&2 "usage: ${0##*/} DIR IMAGE ..."
    exit 255
}

destdir="$1"
shift

while [[ $# -gt 0 ]]; do
    imgsrc="$1"
    shift

    echo >&2 "+ skopeo copy $imgsrc"

    imgdest="$(get-repo-upstream "$imgsrc")"

    if [[ -e "${destdir}/${imgdest}" ]]; then
        echo >&2 "error: File exists: ${destdir}/${imgdest}"
        exit 255
    fi

    mkdir -p "${destdir}/${imgdest}"

    # Copy image
    docker run --rm \
        -u "$(id -u):$(id -g)" \
        -v "$(realpath -m "$destdir"):/data" \
        "$SKOPEO_IMAGE" \
        --override-os linux --override-arch amd64 \
        copy --retry-times 5 --all "docker://$imgsrc" "dir:/data/$imgdest" >&2 || exit 255
done
