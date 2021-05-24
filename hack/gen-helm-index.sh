#!/usr/bin/env bash

PACKAGING_TOOLS_IMAGE="arti.dev.cray.com/internal-docker-stable-local/packaging-tools:0.9.3"

set -o errexit
set -o pipefail

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."

workdir="$(mktemp -d)"
trap "rm -fr '${workdir}'" EXIT

if [[ -f "${ROOTDIR}/helm/index.yaml" ]]; then
    options="-i helm/index.yaml"
fi

set -o xtrace

# Generate index
docker run --rm -v "$(realpath "$ROOTDIR"):/data" "$PACKAGING_TOOLS_IMAGE" sh -c "helm-index --default-repo 'https://arti.dev.cray.com/artifactory/csm-helm-stable-local/' ${options} manifests/*.yaml" > "${workdir}/helm-index.yaml"

# Save to helm/index.yaml
[[ -d "${ROOTDIR}/helm" ]] || mkdir -p "${ROOTDIR}/helm"
mv "${workdir}/helm-index.yaml" "${ROOTDIR}/helm/index.yaml"

# Output any differences
git --no-pager diff -- "${ROOTDIR}/helm/index.yaml"
