#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2022-2024 Hewlett Packard Enterprise Development LP
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
# This updates the CFS configuration that applies to management NCNs by adding
# the appropriate layers for this version of the CSM product.
#

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOTDIR}/lib/version.sh"
source "${ROOTDIR}/lib/install.sh"

# Print a message with extra emphasis to indicate a stage.
function print_stage(){
    msg="$1"
    echo "====> ${msg}"
}

# Exit with an error message and an exit code of 1.
function exit_with_error() {
    msg="$1"
    >&2 echo "${msg}"
    exit 1
}

load-cfs-config-util
trap "{ print_stage 'Cleaning up dependencies'; clean-install-deps &>/dev/null; }" EXIT

function print_usage() {
    cat <<EOF
usage: ${BASH_SOURCE[0]} [options]

Update the CFS configuration for configuring management NCNs by adding or
updating the layer for ${RELEASE}.

Options:

  -h, --help              Print this usage information.

EOF

    cfs-config-util-options-help
}

if [[ $1 == "-h" || $1 == "--help" ]]; then
    print_usage
    exit 0
fi

print_stage "Updating CFS configuration(s)"

cfs-config-util update-configs --product "${RELEASE_NAME}:${RELEASE_VERSION}" \
    --playbook ncn_nodes.yml --playbook ncn-initrd.yml $@
rc=$?

if [[ $rc -eq 2 ]]; then
    print_usage
    exit_with_error "cfs-config-util received invalid arguments."
elif [[ $rc -ne 0 ]]; then
    exit_with_error "Failed to update CFS configurations. cfs-config-util exited with exit status $rc."
fi

print_stage "Completed update of CFS configuration(s)"
