#!/usr/bin/env bash

function rpm-list() {
    while [[ $# -gt 0 ]]; do
        docker run --rm --privileged -v "$(realpath "$(dirname "$1")"):/data" dtr.dev.cray.com/cray/squashfs-tools /usr/local/bin/list-rpms.sh "/data/$(basename "$1")"
        shift
    done
}

set -ex
set -o pipefail

rpm-list "$@" | sort -u
