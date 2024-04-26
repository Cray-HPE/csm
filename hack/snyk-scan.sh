#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

set -euo pipefail

command -v snyk >/dev/null 2>&1 || { echo >&2 "command not found: snyk"; exit 1; }

ROOTDIR=$(realpath "${ROOTDIR:-$(dirname "${BASH_SOURCE[0]}")/..}")

function usage() {
    echo >&2 "usage: ${0##*/} LOGICAL-IMAGE PHYSICAL-IMAGE SRC-DIR DEST-DIR"
    exit 255
}

function retry_snyk() {
    workdir=$1
    image_ref=$2
    attempts=10
    sleep=10
    counter=0
    while [ $counter -le $attempts ]; do
        # Run snyk and capture the exit code. Possible exit codes and their meaning:
        #   0: success, no vulns found
        #   1: action_needed, vulns found
        #   2: failure, try to re-run command
        #   3: failure, no supported projects detected
        #
        # Lately snyk command tends to freeze for up to 1 hour. Run it with 300 seconds timeout to abort and re-try.
        rc=0
        timeout -v --preserve-status 600 snyk container test --platform=linux/amd64 --json-file-output="${workdir}/snyk.json" "$image_ref" > "${workdir}/snyk.txt" || rc=$?
        if [ $rc -lt 2 ]; then
            # Snyk scan completed successfully (potentially found vulberabilities)
            # Dump output to stderr for posterity
            # cat >&2 "${workdir}/snyk.txt"
            return 0
        fi
        echo "Attempt ${counter}/${attempts} failed, waiting for ${sleep} secs and retrying ..."
        counter=$(($counter + 1))
        sleep ${sleep}
    done
    # If all attempts failed, exit with 255 (e.g., to kill xargs)
    echo "All ${attempts} attempts failed, giving up. Output from the last attempt is:"
    cat "${workdir}/snyk.txt"
    exit 255
}

if [[ $# -ne 3 ]]; then
    usage
fi

logical_image="${1#docker://}"
physical_image="${2#docker://}"
destdir="${3#dir:}/${logical_image}"

# All images must come signed from artifactory.algol60.net
if [[ "$physical_image" != artifactory.algol60.net/* ]]; then
    physical_image="artifactory.algol60.net/csm-docker/stable/${physical_image}"
fi

# Save results to temporary working directory in case of error
workdir="$(mktemp -d .snyk-container-test-XXXXXXX)"
trap 'rm -rf ${workdir}' EXIT

echo >&2 "+ snyk container test ${physical_image}"
retry_snyk "${workdir}" "${physical_image}"

# Fix-up JSON results
results="$(mktemp)"
jq --arg pref "$physical_image" --arg lref "$logical_image" '.docker.image.physicalRef = $pref | .docker.image.logicalRef = $lref | .path = $lref' "${workdir}/snyk.json" > "$results" && mv "$results" "${workdir}/snyk.json"

#snyk container monitor "$physical_image" >&2

# Ensure intermediate directories exist
mkdir -p "$(dirname "$destdir")"

# Ensure destination directory is fresh, which is particularly important
# if there was a previous run
[[ -e "$destdir" ]] && rm -fr "$destdir"

# Move results to destination directory
mv "$workdir" "$destdir"
