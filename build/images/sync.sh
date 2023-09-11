#!/usr/bin/env bash

set -euo pipefail

ROOTDIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")/../..")
source "${ROOTDIR}/common.sh"

function usage() {
    echo >&2 "usage: ${0##*/} LOGICAL_IMAGE PHYSICAL_IMAGE DIR"
    exit 255
}

[[ $# -eq 3 ]] || usage

logical_image="${1}"
physical_image="${2}"
destdir="${3%/}/$logical_image"

function skopeo-copy() {
    echo >&2 "+ skopeo copy docker://$physical_image dir:$destdir"

    # Sync to temporary working directory in case of error
    workdir="$(mktemp -d .skopeo-copy-XXXXXXX)"
    trap "rm -fr '$workdir'" EXIT

    creds=""
    [[ "${physical_image}" == artifactory.algol60.net/* ]] && creds="${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}"

    docker run --rm \
        -u "$(id -u):$(id -g)" \
        --mount "type=bind,source=$(realpath "$workdir"),destination=/data" \
        "$SKOPEO_IMAGE" \
        --command-timeout 60s \
        --override-os linux \
        --override-arch amd64 \
        copy \
        --retry-times 5 \
        ${creds:+--src-creds "${creds}"} \
        "docker://$physical_image" \
        dir:/data \
        >&2 || exit 255

    # Ensure intermediate directories exist
    mkdir -p "$(dirname "$destdir")"

    # Ensure destination directory is fresh, which is particularly important
    # if there was a previous run
    [[ -e "$destdir" ]] && rm -fr "$destdir"

    # Move image to destination directory
    mv "$workdir" "$destdir"
}

if [ -n "${CSM_BASE_VERSION:-}" ]; then
    base_image_dir="${ROOTDIR}/dist/csm-${CSM_BASE_VERSION}/docker/${logical_image}/"
    if [ -d "${base_image_dir}" ]; then
        mkdir -p "${destdir}"
        echo >&2 "+ rsync -aq ${base_image_dir} ${destdir%/}/"
        rsync -aq "${base_image_dir}" "${destdir%/}/"
    else
        skopeo-copy
    fi
else
    skopeo-copy
fi