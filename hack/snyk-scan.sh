#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

set -euo pipefail

command -v snyk >/dev/null 2>&1 || { echo >&2 "command not found: snyk"; exit 1; }

function usage() {
    echo >&2 "usage: ${0##*/} DIR PHYSICAL-IMAGE LOGICAL-IMAGE"
    exit 255
}

if [[ $# -ne 3 ]]; then
    [[ $# -eq 2 ]] || usage
    set -- "$@" "$2"
fi

physical_image="${2#docker://}"
logical_image="${3#docker://}"
destdir="${1#dir:}/${logical_image}"

echo >&2 "+ snyk container test $physical_image"

# Save results to temporary working directory in case of error
workdir="$(mktemp -d .snyk-container-test-XXXXXXX)"
trap "rm -fr '$workdir'" ERR

# Run snyk and capture the exit code. Possible exit codes and their meaning:
#   0: success, no vulns found
#   1: action_needed, vulns found
#   2: failure, try to re-run command
#   3: failure, no supported projects detected
rc=0
snyk container test --platform=linux/amd64 --json-file-output="${workdir}/snyk.json" "$physical_image" > "${workdir}/snyk.txt" || rc=$?

# Dump output to stderr for posterity
cat >&2 "${workdir}/snyk.txt"

# If Snyk exited due to failure, then exit with 255 (e.g., to kill xargs)
(( rc < 2 )) || exit 255

# Fix-up JSON results
results="$(mktemp)"
jq --arg pref "$physical_image" --arg lref "$logical_image" '.docker.image.physicalRef = $pref | .docker.image.logicalRef = $lref' "${workdir}/snyk.json" > "$results" && mv "$results" "${workdir}/snyk.json"

#snyk container monitor "$physical_image" >&2

# Ensure intermediate directories exist
mkdir -p "$(dirname "$destdir")"

# Ensure destination directory is fresh, which is particularly important
# if there was a previous run
[[ -e "$destdir" ]] && rm -fr "$destdir"

# Move results to destination directory
mv "$workdir" "$destdir"
