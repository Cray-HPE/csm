#!/usr/bin/env bash

: "${SKOPEO_IMAGE:=quay.io/skopeo/stable:v1.4.1}"

set -euo pipefail

function filter-repos() {
    echo "$1" | sed \
        -e '/^dtr\.dev\.cray\.com\//d' \
        -e '/^cache\//d'
}

function get-repo-mirror() {
    echo "$1" | sed \
        -e 's/^docker\.io\//artifactory.algol60.net\/docker.io\//' \
        -e 's/^gcr\.io\//artifactory.algol60.net\/gcr.io\//' \
        -e 's/^k8s\.gcr\.io\//artifactory.algol60.net\/k8s.gcr.io\//' \
        -e 's/^quay\.io\//artifactory.algol60.net\/quay.io\//'
}


[[ $# -gt 0 ]] || {
    echo >&2 "usage: ${0##*/} IMAGE ..."
    exit 255
}

while [[ $# -gt 0 ]]; do
    image="$1"
    shift

    # Filter out deprecated image repositories
    if [[ -z "$(filter-repos "$image")" ]]; then
        echo >&2 "warning: invalid image: $image"
        exit 255
    fi

    echo >&2 "+ $image"

    # Verify image exists, get fully qualified name
    dest="$(docker run --rm \
        "$SKOPEO_IMAGE" \
        --override-os linux --override-arch amd64 \
        inspect --retry-times 5 --format "{{.Name}}@{{.Digest}}" "docker://$image" || exit 255)"

    # Get fully qualified image name using repository mirrors; i.e.,
    # alpine:3.14 becomes artifactory.algol60.net/docker.io/library/alpine:3.14
    image_repo="$(get-repo-mirror "${dest%%@*}")"
    image_tag="$(echo "$image" | cut -s -d: -f2)"
    echo "${image_repo}:${image_tag}"
done
