#!/usr/bin/env bash

set -euo pipefail

ROOTDIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")/../..")
source "${ROOTDIR}/common.sh"
source "${ROOTDIR}/vendor/github.hpe.com/hpe/hpc-shastarelm-release/lib/release.sh"

function usage() {
    echo >&2 "usage: ${0##*/} LOGICAL_IMAGE PHYSICAL_IMAGE DIR"
    exit 255
}

[[ $# -eq 3 ]] || usage

logical_image="${1}"
physical_image="${2}"
destdir="${3%/}/$logical_image"

if [ -n "${CSM_BASE_VERSION:-}" ]; then
    base_image_dir="${ROOTDIR}/dist/csm-${CSM_BASE_VERSION}/docker/${logical_image}/"
    if [ -d "${base_image_dir}" ]; then
        mkdir -p "${destdir}"
        echo >&2 "+ rsync -aq ${base_image_dir} ${destdir%/}/"
        rsync -aq "${base_image_dir}" "${destdir%/}/"
    else
        sha="${physical_image/*:}"
        if test -f "${destdir}/manifest.json" && echo "${sha}" "${destdir}/manifest.json" | sha256sum -c -; then
            echo >&2 "+ Valid checksum found for ${destdir}/manifest.json, skip copy"
        else
            skopeo-copy "docker://$physical_image" "dir:${destdir}"
        fi
    fi
else
    skopeo-copy "docker://$physical_image" "dir:${destdir}"
fi
