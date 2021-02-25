#!/usr/bin/env bash

[[ $# -eq 1 ]] || {
    echo >&2 "usage: ${0##*/} IMAGE"
    exit 1
}

image="$1"

set -o pipefail

if command -v podman >/dev/null 2>&1; then
    graphroot="$(podman info -f json | jq -r '.store.graphRoot')"
    if [ "$graphroot" == "null" ]
    then
	    graphroot="$(podman info -f json | jq -r '.store.graphroot')"
    fi
    if [ "$graphroot" == "null" ]
    then
	    echo >&2 "error: unable to determine graph root for podman"
	    exit 1
    fi

    runroot="$(podman info -f json | jq -r '.store.runRoot')"
    if [ "$runroot" == "null" ]
    then
	    runroot="$(podman info -f json | jq -r '.store.runroot')"
    fi
    if [ "$runroot" == "null" ]
    then
	    echo >&2 "error: unable to determine run root for podman"
	    exit 1
    fi

    mounts="-v $(realpath "$graphroot"):/var/lib/containers/storage"
    transport="containers-storage"
    run_opts="--rm --network none --privileged --ulimit=host"
    skopeo_dest="${transport}:[vfs@${graphroot}+${runroot}]${image}"
elif command -v docker >/dev/null 2>&1; then
    mounts="-v /var/run/docker.sock:/var/run/docker.sock"
    transport="docker-daemon"
    run_opts="--rm --network none --privileged"
    skopeo_dest="${transport}:${image}"
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

podman run $run_opts  \
    $mounts \
    -v "$(realpath "${ROOTDIR}/docker"):/image:ro" \
    "$SKOPEO_IMAGE" \
    copy "dir:/image/${image}" "$skopeo_dest"