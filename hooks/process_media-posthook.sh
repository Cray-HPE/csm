#!/bin/bash
#
# MIT License
#
# (C) Copyright 2022-2023 Hewlett Packard Enterprise Development LP
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

set -exo pipefail

if [[ -z ${CSM_RELEASE} ]]; then
    echo "CSM RELEASE is not specified"
    exit 1
fi

CSM_REL_NAME="csm-${CSM_RELEASE}"
CSM_ARTI_DIR="/etc/cray/upgrade/csm/${CSM_REL_NAME}/tarball/${CSM_REL_NAME}"

echo "Removing old myenv file"
rm -rf /etc/cray/upgrade/csm/myenv
echo "export CSM_ARTI_DIR=${CSM_ARTI_DIR}" >> /etc/cray/upgrade/csm/myenv
echo "export CSM_RELEASE=${CSM_RELEASE}" >> /etc/cray/upgrade/csm/myenv
echo "export CSM_REL_NAME=${CSM_REL_NAME}" >> /etc/cray/upgrade/csm/myenv


# shellcheck disable=SC2046
echo "Trying to upgrade CSI"
result=$(rpm --force -Uvh $(find ${CSM_ARTI_DIR}/rpm/cray/csm/ -name "cray-site-init*.rpm") 2>1)
if [ $? -ne 0 ]; then
    echo "CSI could not be upgraded with error ${result}"
    exit 1
fi

# shellcheck disable=SC2046
echo "Trying to upgrade CANU"
result=$(rpm --force -Uvh $(find ${CSM_ARTI_DIR}/rpm/cray/csm/ -name "canu*.rpm") 2>1)
if [ $? -ne 0 ]; then
    echo "CANU could not be upgraded with error ${result}"
    exit 1
fi

# run the pre-requisites script
echo "Running prerequisites script"
result= $(docs/upgrade/scripts/upgrade/prerequisites.sh --csm-version "${CSM_RELEASE}" 2>&1)

if [ $? -ne 0 ]; then
    echo "Prerequisites script could not be executed: ${result} "
    exit 1
fi
