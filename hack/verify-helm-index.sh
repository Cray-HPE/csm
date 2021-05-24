#!/usr/bin/env bash

PACKAGING_TOOLS_IMAGE="arti.dev.cray.com/internal-docker-stable-local/packaging-tools:0.9.3"

set -o errexit
set -o pipefail

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."

[[ $# -gt 0 ]] || set -- "${ROOTDIR}/helm/index.yaml"

while [[ $# -gt 0 ]]; do
    docker run --rm -i "$PACKAGING_TOOLS_IMAGE" helm-sync --dry-run -v -n 32 - >/dev/null < "$1"
    shift
done
