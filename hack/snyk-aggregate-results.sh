#!/bin/bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

if [[ $# -lt 1 ]]; then
    echo >&2 "usage: ${0##*/} SCANDIR [--sheet-name NAME]"
    exit 1
fi

scandir="$1"
shift

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."

# Build snyk-aggregate-results image
if ! docker image inspect -f '{{ .Id }}' snyk-aggregate-results:latest >&2; then
    ( cd "${ROOTDIR}/security/snyk-aggregate-results" && make )
fi

# Aggregate Snyk results
docker run --rm -v "$(realpath "$scandir"):/data" snyk-aggregate-results -o "/data/snyk-results.xlsx" "$@"
