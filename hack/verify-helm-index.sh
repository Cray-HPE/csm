#!/usr/bin/env bash

# Copyright 2021, 2023 Hewlett Packard Enterprise Development LP

PACKAGING_TOOLS_IMAGE="arti.hpc.amslabs.hpecorp.net/internal-docker-stable-local/packaging-tools:0.13.0"

set -o errexit
set -o pipefail

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."

MAX_ATTEMPTS=3

[[ $# -gt 0 ]] || set -- "${ROOTDIR}/helm/index.yaml"

while [[ $# -gt 0 ]]; do
    try=1
    while true ; do
        echo "$(date) $1: attempt #$try"
        if docker run --rm -i "$PACKAGING_TOOLS_IMAGE" helm-sync --dry-run -v -n 32 - >/dev/null < "$1" ; then
            echo "$(date) $1: attempt #$try PASSED"
            break
        fi
        echo "$(date) $1: attempt #$try FAILED"
        if [ $try -eq ${MAX_ATTEMPTS} ]; then
            echo "$(date) ERROR: Too many failed attempts. Aborting!"
            exit 1
        fi
        let try+=1
    done
    shift
done
