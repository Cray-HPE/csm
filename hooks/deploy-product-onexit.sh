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

if [[ -f "$DONE_DIR/upgrade_k8s_1_29.done" ]]; then
    echo "INFO kubernetes upgrade to v1.29 already completed, skipping."
else
    echo "INFO Starting the kubernetes upgrade to v1.29"
    /usr/share/doc/csm/upgrade/scripts/k8s/upgrade_k8s.sh -v "1.27.16 1.28.15 1.29.15"
    if [[ $? -ne 0 ]]; then
        echo "ERROR Failed to upgrade kubernetes to v1.29"
        exit 1
    else
        touch "$DONE_DIR/upgrade_k8s_1_29.done"
        echo "INFO Successfully upgraded kubernetes to v1.29"
    fi
fi

if [[ -f "$DONE_DIR/deploy_charts_post_k8s_upgrade.done" ]]; then
    echo "INFO deploy manifests for v1.29 already completed, skipping."
else
    echo "INFO Deploying manifests for v1.29"
    /usr/share/doc/csm/upgrade/scripts/k8s/deploy_charts_post_k8s_upgrade.sh
    if [[ $? -ne 0 ]]; then
        echo "ERROR Failed to deploy manifests for v1.29"
        exit 1
    else
        touch "$DONE_DIR/deploy_charts_post_k8s_upgrade.done"
        echo "INFO Successfully deployed manifests for v1.29"
    fi
fi

if [[ -f "$DONE_DIR/upgrade_k8s_1_32.done" ]]; then
    echo "INFO kubernetes upgrade to v1.32 already completed, skipping."
else
    echo "INFO Starting the kubernetes upgrade to v1.32"
    /usr/share/doc/csm/upgrade/scripts/k8s/upgrade_k8s.sh -v "1.30.12 1.31.8 1.32.5"
    if [[ $? -ne 0 ]]; then
        echo "ERROR Failed to upgrade kubernetes to v1.32"
        exit 1
    else
        touch "$DONE_DIR/upgrade_k8s_1_32.done"
        echo "INFO Successfully upgraded kubernetes to v1.32"
    fi
fi

if [[ -f "$DONE_DIR/cleanup_bss.done" ]]; then
    echo "INFO BSS cleanup already completed, skipping."
else
    echo "INFO Remove upgrade and upgrade_version file creation from BSS for masters and workers."
    /usr/share/doc/csm/upgrade/scripts/upgrade/cleanup.sh
    if [[ $? -ne 0 ]]; then
        echo "ERROR Failed to update BSS to remove upgrade and upgrade_version."
        exit 1
    else
        touch "$DONE_DIR/cleanup_bss.done"
        echo "INFO Successfully updated BSS to remove upgrade and upgrade_version."
    fi
fi

echo "INFO Deploying manifests for v1.32"
pushd ${CSM_ARTI_DIR}
./upgrade.sh
if [[ $? -ne 0 ]]; then
    echo "ERROR Failed to deploy manifests for v1.32"
    exit 1
else
    popd +0
    echo "INFO Successfully deployed manifests for v1.32"
fi

echo "INFO Checking current k8s-primary-cni value in BSS"
CNI_VALUE=$(cray bss bootparameters list --hosts Global --format json | jq -r '.[]."cloud-init"."meta-data"."k8s-primary-cni"')

if [[ "$CNI_VALUE" == "cilium" ]]; then
    echo "INFO k8s-primary-cni is already set to 'cilium'. Skipping migration workflow."
else
    echo "INFO k8s-primary-cni is '$CNI_VALUE'. Proceeding with migration workflow."

    echo "INFO Generating Cilium workflow manifest"

    if [[ ! -f /usr/share/doc/csm/workflows/cilium/generateCiliumLiveMigration.py ]]; then
        echo "ERROR Missing file: generateCiliumLiveMigration.py"
        exit 1
    fi

    if ! /usr/share/doc/csm/workflows/cilium/generateCiliumLiveMigration.py; then
        echo "ERROR Failed to generate Cilium workflow manifest"
        exit 1
    fi

    if [[ ! -f /usr/share/doc/csm/workflows/cilium/cilium-live-migration.yaml ]]; then
        echo "ERROR Missing file: cilium-live-migration.yaml"
        exit 1
    fi

    echo "INFO Applying Cilium workflow manifest"
    if ! kubectl apply -f /usr/share/doc/csm/workflows/cilium/cilium-live-migration.yaml -n argo; then
        echo "ERROR Failed to apply Cilium workflow manifest"
        exit 1
    fi

    WORKFLOW_NAME=$(grep '^  name:' /usr/share/doc/csm/workflows/cilium/cilium-live-migration.yaml | awk '{print $2}')

    echo "INFO Monitoring Cilium workflow status"
    while true; do
        STATUS=$(kubectl get workflow -n argo "${WORKFLOW_NAME}" -o jsonpath='{.status.phase}' 2>/dev/null)

        if [[ "$STATUS" == "Succeeded" ]]; then
            echo "INFO Workflow ${WORKFLOW_NAME} succeeded"
            break
        elif [[ "$STATUS" == "Failed" ]]; then
            echo "ERROR Workflow ${WORKFLOW_NAME} failed"
            exit 1
        elif [[ -z "$STATUS" ]]; then
            echo "INFO Waiting for workflow ${WORKFLOW_NAME} to be created..."
        else
            echo "INFO Workflow ${WORKFLOW_NAME} status: $STATUS"
        fi
        sleep 120
    done
    echo "INFO Cilium workflow completed"
fi

echo "INFO Verifying k8s-primary-cni value in BSS after migration"
CNI_VALUE_POST=$(cray bss bootparameters list --hosts Global --format json | jq -r '.[]."cloud-init"."meta-data"."k8s-primary-cni"')
if [[ "$CNI_VALUE_POST" == "cilium" ]]; then
    echo "INFO k8s-primary-cni is now set to 'cilium'. Migration successful."
else
    echo "ERROR k8s-primary-cni is still '$CNI_VALUE_POST'. Migration may have failed."
    exit 1
fi

# If all steps succeeded, remove all .done files
rm -f "$DONE_DIR"/*.done

echo "INFO Onexit handler for deploy product completed"
