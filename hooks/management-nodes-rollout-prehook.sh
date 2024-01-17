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

echo "INFO Running prehook for management nodes rollout."
. /etc/cray/upgrade/csm/myenv

echo "INFO upgrading CSM applications and services"
/usr/share/doc/csm/upgrade/scripts/upgrade/csm-upgrade.sh
if [[ "$?" -ne 0 ]]; then
    echo "ERROR upgrading CSM applications and services is unsuccessful"
    exit 1
else
    echo "INFO Successfully started upgrading CSM applications and services"
fi



script_start_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

helm-check.sh script_start_time


unset SW_ADMIN_PASSWORD

echo "INFO performing CSM health check post-service upgrade" 
/opt/cray/tests/install/ncn/automated/ncn-k8s-combined-healthcheck-post-service-upgrade
if [[ "$?" -ne 0 ]]; then
    echo "ERROR ncn-k8s-combined-healthcheck-post-service-upgrade failed."
    exit 1
else
    echo "INFO Successfully done ncn-k8s-combined-healthcheck-post-service-upgrade" 
fi

echo "INFO creating of CSM Health log tarball" 
TARFILE="csm_upgrade.$(date +%Y%m%d_%H%M%S).logs.tgz"
tar -czvf "/root/${TARFILE}"  /root/output.log
if [[ "$?" -ne 0 ]]; then
    echo "ERROR creation of CSM Health log tarball"
    exit 1
else
    echo "INFO Successfully created CSM Health log tarball" 
fi

echo "INFO starting upload of CSM Health log tarball to S3"
cray artifacts create config-data "${TARFILE}" "/root/${TARFILE}"
if [[ "$?" -ne 0 ]]; then
    echo "ERROR upload of CSM Health log tarball to S3"
    exit 1
else
    echo "INFO CSM Health log tarball uploaded Successfully to S3" 
fi

echo "INFO prehook for management nodes rollout completed."

if [[ "$?" -ne 0 ]]; then
    echo "ERROR prehook for management nodes rollout is unsuccessful"
    exit 1
else
    echo "INFO prehook for management nodes rollout completed."
fi