#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

set -euo pipefail

command -v snyk >/dev/null 2>&1 || { echo >&2 "command not found: snyk"; exit 1; }

function usage() {
    echo >&2 "usage: ${0##*/} DIR PHYSICAL-IMAGE LOGICAL-IMAGE"
    exit 255
}

function retry_snyk() {
    workdir=$1
    physical_image=$2
    attempts=20
    sleep=20
    counter=0
    while [ $counter -le $attempts ]; do
        # Run snyk and capture the exit code. Possible exit codes and their meaning:
        #   0: success, no vulns found
        #   1: action_needed, vulns found
        #   2: failure, try to re-run command
        #   3: failure, no supported projects detected
        rc=0
        snyk container test --exclude-app-vulns --json-file-output="${workdir}/snyk.json" "$physical_image" &> "${workdir}/snyk.txt" || rc=$?
        if [ $rc -lt 2 ]; then
            # Snyk scan completed successfully (potentially found vulberabilities)
            # Dump output to stderr for posterity
            cat >&2 "${workdir}/snyk.txt"
            return 0
        fi
        cat "${workdir}/snyk.txt"
        echo "Attempt ${counter}/${attempts} failed, waiting for ${sleep} secs and retrying ..."
        counter=$(($counter + 1))
        sleep ${sleep}
    done
    
    # If all attempts failed, exit with 255 (e.g., to kill xargs)
    echo "All ${attempts} attempts failed, giving up"
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
trap "rm -fr '$workdir'" EXIT

# Invoke snyk scan with retry logic, in case of connection timeout and internal errors at snyk.io
retry_snyk "${workdir}" "${physical_image}"

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
