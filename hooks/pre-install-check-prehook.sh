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
echo "INFO Running prehook for pre-install-check"

set -exo pipefail

#find the CSM_RELEASE by using the directory name
HOOKS_PATH="$(readlink -f hooks)"
CSM_RELEASE=$(basename "$(dirname "$HOOKS_PATH")" | sed 's/^csm-//')
MEDIA_DIR=$(basename "$(dirname "$(dirname "$HOOKS_PATH")")")

if [[ -z ${CSM_RELEASE} ]]; then
    echo "ERROR Unable to find CSM RELEASE version"
    exit 1
fi

echo "INFO Upgrading to ${CSM_RELEASE}"
CSM_REL_NAME="csm-${CSM_RELEASE}"
CSM_ARTI_DIR="/etc/cray/upgrade/csm/${MEDIA_DIR}/${CSM_REL_NAME}/"

echo "INFO Removing old myenv file"
rm -rf /etc/cray/upgrade/csm/myenv
echo "export CSM_ARTI_DIR=${CSM_ARTI_DIR}" >> /etc/cray/upgrade/csm/myenv
echo "export CSM_RELEASE=${CSM_RELEASE}" >> /etc/cray/upgrade/csm/myenv
echo "export CSM_REL_NAME=${CSM_REL_NAME}" >> /etc/cray/upgrade/csm/myenv


# shellcheck disable=SC2046
echo "INFO Trying to upgrade CSI"
result=$(rpm --force -Uvh $(find ${CSM_ARTI_DIR}/rpm/cray/csm/ -name "cray-site-init*.rpm") 2>1)
if [ $? -ne 0 ]; then
    echo "ERROR CSI could not be upgraded with error ${result}"
    exit 1
else
    echo "INFO CSI upgraded successfully"
fi

# shellcheck disable=SC2046
echo "INFO Trying to upgrade CANU"
result=$(rpm --force -Uvh $(find ${CSM_ARTI_DIR}/rpm/cray/csm/ -name "canu*.rpm") 2>1)
if [ $? -ne 0 ]; then
    echo "ERROR CANU could not be upgraded with error ${result}"
    exit 1
else
    echo "INFO CANU upgraded successfully"
fi

if [ -n "$(ls -A ${CSM_ARTI_DIR}/sample)" ]; then
    rm ${CSM_ARTI_DIR}/sample/.gitkeep
fi    

# Unset the SW_ADMIN_PASSWORD variable in case it is set -- this will force the BGP test to look up the password itself
if [[ ! -z ${SW_ADMIN_PASSWORD} ]]; then
    unset SW_ADMIN_PASSWORD
fi

# run the pre-requisites script
echo "INFO Setting up the prerequisites for CSM upgrade"
result=$(docs/upgrade/scripts/upgrade/prerequisites.sh --csm-version "${CSM_RELEASE}" 2>&1)

if [ $? -ne 0 ]; then
    echo "ERROR Setting up prerequisites for CSM upgrade failed: ${result} "
    exit 1
else
    echo "INFO Prerequisites setup for CSM upgrade successfully completed"
fi

echo "INFO Prehook for pre-install-check completed"
