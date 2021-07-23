#!/usr/bin/env bash

command -v snyk >/dev/null 2>&1 || { echo >&2 "command not found: snyk"; exit 1; }

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."

workdir="$(mktemp -d)"
trap "rm -fr '$workdir'" EXIT

"${ROOTDIR}/hack/list-images.py" > "${workdir}/images.txt"

while read image; do
    echo >&2 "$image"
    outdir="${ROOTDIR}/scans/docker/${image}"
    mkdir -p "$outdir"
    snyk container test --json-file-output="${outdir}/snyk.json" "$image" | tee "${outdir}/snyk.txt"
done < "${workdir}/images.txt"
