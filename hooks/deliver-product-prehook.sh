#!/bin/bash
#
# MIT License
#
# (C) Copyright 2026 Hewlett Packard Enterprise Development LP
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
echo "INFO Running Prehook for deliver-product"

set -exo pipefail

#find the CSM_RELEASE by using the directory name
HOOKS_PATH="$(readlink -f hooks)"
CSM_RELEASE=$(basename "$(dirname "$HOOKS_PATH")" | sed 's/^csm-//')
MEDIA_DIR=$(dirname "$(dirname "$HOOKS_PATH")")

if [[ -z ${CSM_RELEASE} ]]; then
    echo "ERROR Unable to find CSM RELEASE version"
    exit 1
fi

echo "INFO Installing CSM patch ${CSM_RELEASE}"
CSM_REL_NAME="csm-${CSM_RELEASE}"
CSM_ARTI_DIR="${MEDIA_DIR}/${CSM_REL_NAME}"

# Initialize myenv for this run with the core release context used by post-hooks.
echo "INFO Setting up myenv file"
rm -rf /etc/cray/upgrade/csm/myenv
# Persist key environment variables needed by downstream hook scripts.
echo "export CSM_ARTI_DIR=${CSM_ARTI_DIR}" >> /etc/cray/upgrade/csm/myenv
echo "export CSM_RELEASE=${CSM_RELEASE}" >> /etc/cray/upgrade/csm/myenv
echo "export CSM_REL_NAME=${CSM_REL_NAME}" >> /etc/cray/upgrade/csm/myenv

# github does not allow empty dir in the repo, hence gitkeep is created. But while using IUF we need to remove it to avoid running into an error.
if [ -n "$(ls -A ${CSM_ARTI_DIR}/dummy)" ]; then
    if [ -f "${CSM_ARTI_DIR}/dummy/.gitkeep" ]; then
        rm "${CSM_ARTI_DIR}/dummy/.gitkeep"
    fi
fi

echo "INFO Prehook for deliver-product completed"
