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

echo "INFO Running prehook for management nodes rollout"
. /etc/cray/upgrade/csm/myenv

script_start_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "INFO Upgrading CSM applications and services"
/usr/share/doc/csm/upgrade/scripts/upgrade/csm-upgrade.sh
if [[ "$?" -ne 0 ]]; then
    echo "ERROR Failed to upgrade all CSM applications and services"
    exit 1
else
    echo "INFO Successfully started upgrading CSM applications and services"
fi

#checking for the upgrade status of CSM applications and services
HOOKS_PATH="$(readlink -f hooks)"
$HOOKS_PATH/upgrade-check.sh $script_start_time
if [[ "$?" -ne 0 ]]; then
    echo "ERROR Failed to upgrade CSM applications and services"
    exit 1
else
    echo "INFO Upgrade of CSM applications and services completed"
fi

# Unset the SW_ADMIN_PASSWORD variable in case it is set -- this will force the BGP test to look up the password itself
unset SW_ADMIN_PASSWORD

echo "INFO Performing CSM health check post-service upgrade" 
if [ ! -f /etc/cray/upgrade/csm/${CSM_REL_NAME}/health-checks.done ]; then
    /opt/cray/tests/install/ncn/automated/ncn-k8s-combined-healthcheck-post-service-upgrade
    if [[ "$?" -ne 0 ]]; then
        echo "ERROR ncn-k8s-combined-healthcheck-post-service-upgrade failed"
        exit 1
    fi
fi

echo "INFO Successfully done ncn-k8s-combined-healthcheck-post-service-upgrade" 
touch /etc/cray/upgrade/csm/${CSM_REL_NAME}/health-checks.done

echo "INFO Creating CSM Health log tarball" 
TARFILE="csm_upgrade.$(date +%Y%m%d_%H%M%S).logs.tgz"
tar -czvf "/root/${TARFILE}"  /root/output.log
if [[ "$?" -ne 0 ]]; then
    echo "ERROR Creation of CSM Health log tarball failed"
    exit 1
else
    echo "INFO Successfully created CSM Health log tarball" 
fi

echo "INFO starting upload of CSM Health log tarball to S3"
cray artifacts create config-data "${TARFILE}" "/root/${TARFILE}"
if [[ "$?" -ne 0 ]]; then
    echo "ERROR Upload of CSM Health log tarball to S3"
    exit 1
else
    echo "INFO CSM Health log tarball uploaded Successfully to S3" 
fi

echo "INFO Prehook for management nodes rollout completed"