#!/bin/bash
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

echo "INFO Running Prehook for management nodes rollout"
. /etc/cray/upgrade/csm/myenv

echo "INFO Upgrading CSM applications and services"
if [ ! -f /etc/cray/upgrade/csm/${CSM_REL_NAME}/upgrade-csm-applications-services.done ]; then
    /usr/share/doc/csm/upgrade/scripts/upgrade/csm-upgrade.sh
    if [[ $? -ne 0 ]]; then
        echo "ERROR Unable to start upgrade of CSM applications and services"
        exit 1
    else
        # checking for the upgrade status of CSM applications and services
        HOOKS_PATH="$(readlink -f hooks)"
        script_start_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        # upgrade-csm-applications-check.sh checks the status of all the helm charts deployed for this CSM upgrade
        $HOOKS_PATH/helm-upgrade-status-check.sh $script_start_time
        if [[ $? -ne 0 ]]; then
            echo "ERROR Failed to upgrade CSM applications and services"
            exit 1
        else
            touch /etc/cray/upgrade/csm/${CSM_REL_NAME}/upgrade-csm-applications-services.done
            echo "INFO Upgrade of CSM applications and services completed"
        fi
    fi
else
    echo "INFO Upgrade of CSM applications and services has previously been completed"
fi

# Unset the SW_ADMIN_PASSWORD variable in case it is set this will force the BGP test to look up the password itself
if [[ ! -z ${SW_ADMIN_PASSWORD} ]]; then
    unset SW_ADMIN_PASSWORD
fi

echo "INFO Performing CSM health check post-service upgrade" 
if [ ! -f /etc/cray/upgrade/csm/${CSM_REL_NAME}/health-checks.done ]; then
    export healthcheck=$(/opt/cray/tests/install/ncn/automated/ncn-k8s-combined-healthcheck iuf 2>&1)
    if [[ $? -ne 0 ]]; then
        echo "ERROR ncn-k8s-combined-healthcheck failed"
        exit 1
    else
        echo "INFO Successfully completed ncn-k8s-combined-healthcheck" 
        touch /etc/cray/upgrade/csm/${CSM_REL_NAME}/health-checks.done
    fi
else
    echo "INFO ncn-k8s-combined-healthcheck has previously been completed"
fi

echo "INFO Archiving CSM health log" 

LOGS=()

# Base directory that is common for Goss Test
healthcheck_log_dir="/opt/cray/tests/install/logs/print_goss_json_results"
# Extract log file paths using grep
$healthcheck_log_file=$(echo "$healthcheck" | grep -o "$healthcheck_log_dir[^ ]*")

#Check LOG_FILE exists before archiving
if [[ -f "$healthcheck_log_file" ]]; then
    LOGS+=("$healthcheck_log_file")
else
    echo "WARN Log File: $healthcheck_log_file does not exist."
fi

#Check output.log exists before archiving
if [[! -f /root/output.log ]]; then
    LOGS+=("$healthcheck_log_file")
else
    echo "WARN Log File: /root/output.log does not exist."
fi

TARFILE="csm_upgrade.$(date +%Y%m%d_%H%M%S).logs.tgz"
tar -czvf "/root/${TARFILE}" "${LOGS[@]}"
if [[ $? -ne 0 ]]; then
    echo "ERROR Failed to create CSM health log archive"
    exit 1
else
    echo "INFO Successfully created CSM health log archive" 
fi

echo "INFO Uploading CSM health log archive to S3"
cray artifacts create config-data "${TARFILE}" "/root/${TARFILE}"
if [[ $? -ne 0 ]]; then
    echo "ERROR Failed to upload CSM health log archive to S3"
    exit 1
else
    echo "INFO Successfully uploaded CSM health log archive to S3" 
fi

echo "INFO Prehook for management nodes rollout completed"
