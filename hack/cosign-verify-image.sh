#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2024 Hewlett Packard Enterprise Development LP
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

set -euo pipefail

ROOTDIR=$(realpath "${ROOTDIR:-$(dirname "${BASH_SOURCE[0]}")/..}")
source "${ROOTDIR}/assets.sh"
source "${ROOTDIR}/common.sh"

function usage() {
    echo >&2 "usage: ${0##*/} LOGICAL_IMAGE PHYSICAL_IMAGE"
    exit 255
}

[[ $# -eq 2 ]] || usage

logical_image="${1}"
physical_image="${2}"

echo -ne "Validating ${logical_image} ... "
tmpdir=$(mktemp -d)
trap "rm -rf ${tmpdir}" EXIT

# cosign is not capable of reading multiple keys from signle file, will need to toss
# keys into separate files
count=0
while read -r line; do
    if [ "${line}" == '-----BEGIN PUBLIC KEY-----' ]; then
        count=$((count+1))
    fi
    echo "${line}" >> "${tmpdir}/key-${count}.pub"
done < <(yq e '.spec.kubernetes.services["kyverno-policy"].checkImagePolicy.rules[].verifyImages[].attestors[].entries[].keys.publicKeys' \
    "${ROOTDIR}/vendor/github.com/Cray-HPE/shasta-cfg/customizations.yaml")

# iterate over provided keys until one of them works
for key in "${tmpdir}"/key-*.pub; do
    if cosign verify --key "${key}" --insecure-ignore-tlog --insecure-ignore-sct "${physical_image}"  2>/dev/null 1>/dev/null; then
        echo "ok"
        exit 0
    fi
done

echo "error: unable to validate with any provided key"
exit 1