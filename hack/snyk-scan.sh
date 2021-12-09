#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

set -euo pipefail

command -v snyk >/dev/null 2>&1 || { echo >&2 "command not found: snyk"; exit 1; }

[[ $# -gt 1 ]] || {
    echo >&2 "usage: ${0##*/} DIR IMAGE..."
    exit 255
}

scandir="$1"
shift

while [[ $# -gt 0 ]]; do
    image="$1"
    shift
    echo >&2 "$image"
    outdir="${scandir}/${image}"
    mkdir -p "$outdir"
    snyk container test --json-file-output="${outdir}/snyk.json" "$image" | tee "${outdir}/snyk.txt" >&2
    #snyk container monitor "$image" >&2
done
