#!/usr/bin/env bash

if [[ $# -ne 1 ]]; then
    echo >&2 "usage: ${0##*/} DISTDIR"
    exit 2
fi

set -eo pipefail

distdir="$(realpath "$1")"

if [[ ! -d "$distdir" ]]; then
    echo >&2 "error: no such directory: $distdir"
    exit 3
fi

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."

# Use the version of yq in SHASTA-CFG
shopt -s expand_aliases
alias yq="${ROOTDIR}/utils/bin/$(uname | awk '{print tolower($0)}')/yq"

set -x

# Copy shasta-cfg content ignoring anything in the ignore file.
rsync -rlE --safe-links --exclude-from="${ROOTDIR}/package/ignore" "${ROOTDIR}/" "${distdir}/"

# Remove existing sealed secrets
yq r --printMode p "${distdir}/customizations.yaml" "spec.kubernetes.sealed_secrets.(kind==SealedSecret)" \
| xargs -n 1 -r yq d -i "${distdir}/customizations.yaml"
