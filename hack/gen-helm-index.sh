#!/usr/bin/env bash

PACKAGING_TOOLS_IMAGE="arti.dev.cray.com/internal-docker-stable-local/packaging-tools:0.9.0"

set -o errexit
set -o pipefail

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."

workdir="$(mktemp -d)"
trap "rm -fr '${workdir}'" EXIT

docker run --rm -v "$(realpath "$ROOTDIR"):/data" "$PACKAGING_TOOLS_IMAGE" sh -c 'helm-index -i helm/index.yaml manifests/*.yaml' > "${workdir}/helm-index.yaml"
mv "${workdir}/helm-index.yaml" "${ROOTDIR}/helm/index.yaml"
