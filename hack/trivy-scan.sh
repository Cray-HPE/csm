#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

command -v trivy >/dev/null 2>&1 || { echo >&2 "command not found: trivy"; exit 1; }

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."

scandir="${1:-"${ROOTDIR}/scans/docker"}"

workdir="$(mktemp -d)"
trap "rm -fr '$workdir'" EXIT

"${ROOTDIR}/hack/list-images.py" > "${workdir}/images.txt"

while read image; do
    echo >&2 "$image"
    outdir="${scandir}/${image}"
    mkdir -p "$outdir"
    trivy image "$image" 2>&1 | tee "${outdir}/trivy.txt"
    trivy image --ignore-unfixed "$image" 2>&1 | tee "${outdir}/trivy-fixable.txt"
done < "${workdir}/images.txt"
