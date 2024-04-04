#!/usr/bin/env bash

#
# MIT License
#
# (C) Copyright 2023 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
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
