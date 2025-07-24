#!/bin/bash
#
# MIT License
#
# (C) Copyright 2024-2025 Hewlett Packard Enterprise Development LP
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

echo "INFO Running Onexit handler for deploy product"
. /etc/cray/upgrade/csm/myenv

DONE_DIR="/etc/cray/upgrade/csm/${CSM_REL_NAME}"

if [[ -f "$DONE_DIR/apply-networking-manifests.done" ]]; then
    echo "INFO weave and multus upgrade already completed, skipping."
else
    echo "INFO Upgrading weave and multus"
    /srv/cray/scripts/common/apply-networking-manifests.sh
    if [[ $? -ne 0 ]]; then
        echo "ERROR Failed to upgrade weave and multus"
        exit 1
    else
        touch "$DONE_DIR/apply-networking-manifests.done"
        echo "INFO Successfully upgraded weave and multus"
    fi
fi

if [[ -f "$DONE_DIR/apply-coredns-pod-affinity.done" ]]; then
    echo "INFO coredns anti-affinity upgrade already completed, skipping."
else
    echo "INFO Upgrading coredns anti-affinity"
    /usr/share/doc/csm/upgrade/scripts/k8s/apply-coredns-pod-affinity.sh
    if [[ $? -ne 0 ]]; then
        echo "ERROR Failed to upgrade coredns anti-affinity"
        exit 1
    else
        touch "$DONE_DIR/apply-coredns-pod-affinity.done"
        echo "INFO Successfully upgraded coredns anti-affinity"
    fi
fi

if [[ -f "$DONE_DIR/upgrade_control_plane.done" ]]; then
    echo "INFO kubernetes control plane upgrade already completed, skipping."
else
    echo "INFO Starting the kubernetes control plane upgrade"
    /usr/share/doc/csm/upgrade/scripts/k8s/upgrade_control_plane.sh
    if [[ $? -ne 0 ]]; then
        echo "ERROR Failed to upgrade kubernetes control plane"
        exit 1
    else
        touch "$DONE_DIR/upgrade_control_plane.done"
        echo "INFO Successfully upgraded kubernetes control plane"
    fi
fi

echo "INFO Running job to complete k8s upgrade from 1.26 to 1.32"


result=$(kubectl create -f /usr/share/doc/csm/upgrade/scripts/k8s/upgrade_k8s_job.yaml 2>&1)
if [[ $? -ne 0 ]]; then
  echo "ERROR Failed to create the Kubernetes upgrade job: $result"
  exit 1
fi

job_name=$(echo $result | awk '{print $1}' | awk -F '/' '{print $2}')
echo "INFO Job $job_name has been created in the argo namespace. This is performing k8s upgrade from 1.26 to 1.32"
echo "INFO Monitor the job and ensure it is successful before proceeding to next stage."

echo "INFO Onexit handler for deploy product completed"

