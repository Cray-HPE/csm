#!/usr/bin/env bash

[[ $# -eq 1 ]] || {
    echo >&2 "usage: ${0##*/} IMAGE"
    exit 1
}

image="$1"

set -o pipefail

if command -v podman >/dev/null 2>&1; then
    #graphroot=/var/lib/containers/storage
    graphroot="$(podman info -f json | jq -r '.store.graphRoot')"
    container_runtime_volume="$(realpath "$graphroot"):/var/lib/containers/storage"
    transport="containers-storage"
elif command -v docker >/dev/null 2>&1; then
    container_runtime_volume="/var/run/docker.sock:/var/run/docker.sock"
    transport="docker-daemon"
    shopt -s expand_aliases
    alias podman=docker
else
    echo >&2 "error: podman or docker not available"
    exit 2
fi

set -ex

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."
source "${ROOTDIR}/lib/install.sh"

SKOPEO_IMAGE="$(load-vendor-image "${ROOTDIR}/vendor/skopeo.tar")"

podman run --rm --network none --privileged -v "$container_runtime_volume" \
    -v "$(realpath "${ROOTDIR}/docker"):/image:ro" \
    "$SKOPEO_IMAGE" \
    copy "dir:/image/${image}" "${transport}:${image}"
