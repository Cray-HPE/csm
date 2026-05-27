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
echo "INFO Running Posthook for deliver-product"

set -exo pipefail

# Load variables populated during earlier upgrade phases.
. /etc/cray/upgrade/csm/myenv
if [[ -z "${CSM_RELEASE}" ]]; then
    echo "ERROR CSM_RELEASE could not be determined from /etc/cray/upgrade/csm/myenv"
    exit 1
fi

# Keep idempotency markers under a release-scoped done directory.
DONE_DIR="/etc/cray/upgrade/csm/${CSM_REL_NAME}"
mkdir -p "${DONE_DIR}"

# Step 0: Create repo data from release artifacts.
if [[ -f "${DONE_DIR}/create-repo-data.done" ]]; then
    echo "INFO Repo data creation already completed, skipping."
else
    SETUP_NEXUS_SCRIPT="${CSM_ARTI_DIR}/hooks/setup-nexus.sh"
    if [[ ! -x "${SETUP_NEXUS_SCRIPT}" ]]; then
        echo "ERROR Missing or non-executable setup script: ${SETUP_NEXUS_SCRIPT}"
        exit 1
    fi

    echo "INFO Creating repo data using ${SETUP_NEXUS_SCRIPT}"
    set +e
    "${SETUP_NEXUS_SCRIPT}"
    setup_nexus_rc=$?
    set -e
    if [[ ${setup_nexus_rc} -ne 0 ]]; then
        echo "ERROR Repo data creation failed with exit code ${setup_nexus_rc}"
        exit ${setup_nexus_rc}
    fi

    touch "${DONE_DIR}/create-repo-data.done"
    rm -rf "${CSM_ARTI_DIR}/csm-1.7.1-noos"
    echo "INFO Successfully created repo data"
fi

# Step 1: Create secure NCN base images for kubernetes and storage, upload to IMS.
if [[ -f "${DONE_DIR}/ncn-image-upload.done" ]]; then
    echo "INFO NCN image creation and upload already completed, skipping."
else
    echo "INFO Creating base images, uploading to IMS"

    # Source image artifacts delivered with this CSM release.
    artdir=${CSM_ARTI_DIR}/images
    SQUASHFS_ROOT_PW_HASH=$(awk -F':' /^root:/'{print $2}' < /etc/shadow)
    export SQUASHFS_ROOT_PW_HASH
    set -o pipefail
    NCN_IMAGE_MOD_SCRIPT=$(rpm -ql docs-csm | grep ncn-image-modification.sh)
    set +o pipefail

    KUBERNETES_VERSION=$(find "${artdir}/kubernetes" -name 'kubernetes*.squashfs' -exec basename {} .squashfs \; | sed -e 's/^kubernetes-//' -e 's/-[^-]*$//')
    CEPH_VERSION=$(find "${artdir}/storage-ceph" -name 'storage-ceph*.squashfs' -exec basename {} .squashfs \; | sed -e 's/^storage-ceph-//' -e 's/-[^-]*$//')

    k8s_done=0
    ceph_done=0
    # Reuse existing secure images when already present to avoid expensive regeneration.
    arch="$(uname -i)"
    if [[ -f ${artdir}/kubernetes/secure-kubernetes-${KUBERNETES_VERSION}-${arch}.squashfs ]]; then
        k8s_done=1
    fi
    if [[ -f ${artdir}/storage-ceph/secure-storage-ceph-${CEPH_VERSION}-${arch}.squashfs ]]; then
        ceph_done=1
    fi

    if [[ ${k8s_done} == 1 && ${ceph_done} == 1 ]]; then
        echo "INFO Already ran ${NCN_IMAGE_MOD_SCRIPT}, skipping re-run."
    else
        # ${artdir} is mounted on top of CephFS. Running mksquashfs against it is very slow. We will copy squashfs files to temporary dir
        # instead, and run NCN modification script there.
        tmpdir_kubernetes=$(mktemp -d)
        tmpdir_storage=$(mktemp -d)
        cp "${artdir}/kubernetes/kubernetes-${KUBERNETES_VERSION}-${arch}.squashfs" "${tmpdir_kubernetes}/"
        cp "${artdir}/storage-ceph/storage-ceph-${CEPH_VERSION}-${arch}.squashfs" "${tmpdir_storage}/"
        DEBUG=1 "${NCN_IMAGE_MOD_SCRIPT}" \
            -d /root/.ssh \
            -k "${tmpdir_kubernetes}/kubernetes-${KUBERNETES_VERSION}-${arch}.squashfs" \
            -s "${tmpdir_storage}/storage-ceph-${CEPH_VERSION}-${arch}.squashfs" \
            -p
        mv "${tmpdir_kubernetes}/secure-kubernetes-${KUBERNETES_VERSION}-${arch}.squashfs" "${artdir}/kubernetes/"
        mv "${tmpdir_storage}/secure-storage-ceph-${CEPH_VERSION}-${arch}.squashfs" "${artdir}/storage-ceph/"
        rm -Rf "${tmpdir_kubernetes}" "${tmpdir_storage}"
    fi

    set -o pipefail
    # Upload secure images through the supported docs-csm helper.
    IMS_UPLOAD_SCRIPT=$(rpm -ql docs-csm | grep ncn-ims-image-upload.sh)

    UUID_REGEX='^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$'

    echo "INFO Uploading Kubernetes images..."
    export IMS_ROOTFS_FILENAME="${artdir}/kubernetes/secure-kubernetes-${KUBERNETES_VERSION}-${arch}.squashfs"
    export IMS_INITRD_FILENAME="${artdir}/kubernetes/initrd.img-${KUBERNETES_VERSION}-${arch}.xz"
    # do not quote this glob.  bash will add single ticks (') around it, preventing expansion later
    resolve_kernel_glob=$(echo ${artdir}/kubernetes/*-${arch}.kernel)
    export IMS_KERNEL_FILENAME=$resolve_kernel_glob
    SECURE_K8S_IMAGE_ID=$($IMS_UPLOAD_SCRIPT)
    [[ -n ${SECURE_K8S_IMAGE_ID} ]] && [[ ${SECURE_K8S_IMAGE_ID} =~ $UUID_REGEX ]]

    echo "INFO Uploading Ceph images..."
    export IMS_ROOTFS_FILENAME="${artdir}/storage-ceph/secure-storage-ceph-${CEPH_VERSION}-${arch}.squashfs"
    export IMS_INITRD_FILENAME="${artdir}/storage-ceph/initrd.img-${CEPH_VERSION}-${arch}.xz"
    # do not quote this glob.  bash will add single ticks (') around it, preventing expansion later
    resolve_kernel_glob=$(echo ${artdir}/storage-ceph/*-${arch}.kernel)
    export IMS_KERNEL_FILENAME=$resolve_kernel_glob
    SECURE_STORAGE_IMAGE_ID=$($IMS_UPLOAD_SCRIPT)
    [[ -n ${SECURE_STORAGE_IMAGE_ID} ]] && [[ ${SECURE_STORAGE_IMAGE_ID} =~ $UUID_REGEX ]]
    set +o pipefail

    # Persist generated IMS image IDs for later hook steps.
    echo "INFO Appending image ids to myenv..."
    touch /etc/cray/upgrade/csm/myenv
    echo "export SECURE_STORAGE_IMAGE_ID=${SECURE_STORAGE_IMAGE_ID}" >> /etc/cray/upgrade/csm/myenv
    echo "export SECURE_K8S_IMAGE_ID=${SECURE_K8S_IMAGE_ID}" >> /etc/cray/upgrade/csm/myenv

    # NOTE: NCN node images are no longer set in BSS here
    # IUF workflows handle setting the correct node image before a node is upgraded
    # If doing a CSM only upgrade, NCN images are set in the CSM-Only procedure

    touch "${DONE_DIR}/ncn-image-upload.done"
    echo "INFO Successfully created and uploaded NCN images and updated Cray-Product-Catalog"
fi

# Step 2: Resolve role-specific CFS configs and generate images.yaml from images-template.yaml.
if [[ -f "${DONE_DIR}/get-ncn-config-names.done" ]]; then
    echo "INFO NCN configuration name retrieval already completed, skipping."
else
    echo "INFO Retrieving configuration names for master, worker, and storage nodes from sat status"

    # Parse sat status table to get current config names for master, worker, and storage nodes.
    MASTER_CONFIG=$(sat status 2>/dev/null | awk -F'|' '$12 ~ /Master/  {gsub(/ /,"",$15); print $15; exit}')
    WORKER_CONFIG=$(sat status 2>/dev/null | awk -F'|' '$12 ~ /Worker/  {gsub(/ /,"",$15); print $15; exit}')
    STORAGE_CONFIG=$(sat status 2>/dev/null | awk -F'|' '$12 ~ /Storage/ {gsub(/ /,"",$15); print $15; exit}')

    echo "export MASTER_CONFIG=${MASTER_CONFIG}" >> /etc/cray/upgrade/csm/myenv
    echo "export WORKER_CONFIG=${WORKER_CONFIG}" >> /etc/cray/upgrade/csm/myenv
    echo "export STORAGE_CONFIG=${STORAGE_CONFIG}" >> /etc/cray/upgrade/csm/myenv

    # Keep template immutable and render dynamic values into a generated images.yaml.
    IMAGE_TEMPLATE_FILE="${CSM_ARTI_DIR}/images-template.yaml"
    IMAGE_RENDERED_FILE="${CSM_ARTI_DIR}/images.yaml"

    if [[ ! -f "${IMAGE_TEMPLATE_FILE}" ]]; then
        echo "ERROR Missing image template file: ${IMAGE_TEMPLATE_FILE}"
        exit 1
    fi

    cp "${IMAGE_TEMPLATE_FILE}" "${IMAGE_RENDERED_FILE}"
    sed -i "s|__CSM_REL_NAME__|${CSM_REL_NAME}|g" "${IMAGE_RENDERED_FILE}"
    sed -i "s|__CSM_RELEASE__|${CSM_RELEASE}|g" "${IMAGE_RENDERED_FILE}"
    sed -i "s|__MASTER_CONFIG__|${MASTER_CONFIG}|g" "${IMAGE_RENDERED_FILE}"
    sed -i "s|__WORKER_CONFIG__|${WORKER_CONFIG}|g" "${IMAGE_RENDERED_FILE}"
    sed -i "s|__STORAGE_CONFIG__|${STORAGE_CONFIG}|g" "${IMAGE_RENDERED_FILE}"
    echo "INFO Generated ${IMAGE_RENDERED_FILE} from ${IMAGE_TEMPLATE_FILE}"

    touch "${DONE_DIR}/get-ncn-config-names.done"
    echo "INFO Successfully retrieved NCN configuration names"
fi

# Step 3: Create role images via SAT bootprep and persist generated image IDs.
if [[ -f "${DONE_DIR}/create-bootprep-images.done" ]]; then
    echo "INFO SAT bootprep image creation already completed, skipping."
else
    echo "INFO Running SAT bootprep image creation for master, worker, and storage"

    pushd ${CSM_ARTI_DIR}

    IMAGE_RENDERED_FILE="images.yaml"
    if [[ ! -f "${IMAGE_RENDERED_FILE}" ]]; then
        echo "ERROR Missing generated images file: ${IMAGE_RENDERED_FILE}"
        exit 1
    fi

    # Capture SAT output in a file so image IDs can be parsed reliably.
    BOOTPREP_OUTPUT_FILE=$(mktemp)
    sat bootprep run --limit images --cfs-version v3 "${IMAGE_RENDERED_FILE}" --overwrite-images 2>&1 | tee -a ${BOOTPREP_OUTPUT_FILE}
    if [[ $? -ne 0 ]]; then
        echo "ERROR Failed to create images using SAT bootprep"
	rm ${BOOTPREP_OUTPUT_FILE}
        exit 1
    fi

    # Extract IDs only if the line contains 'succeeded'
    FINAL_MASTER_IMAGE_ID=$(grep "Creation of image master-.*succeeded" "${BOOTPREP_OUTPUT_FILE}" | sed -E 's/.*ID //')
    FINAL_WORKER_IMAGE_ID=$(grep "Creation of image worker-.*succeeded" "${BOOTPREP_OUTPUT_FILE}" | sed -E 's/.*ID //')
    FINAL_STORAGE_IMAGE_ID=$(grep "Creation of image storage-.*succeeded" "${BOOTPREP_OUTPUT_FILE}" | sed -E 's/.*ID //')

    # Fail this stage if any role image was not created.
    if [ -z "${FINAL_STORAGE_IMAGE_ID}" ] || [ -z "${FINAL_MASTER_IMAGE_ID}" ] || [ -z "${FINAL_WORKER_IMAGE_ID}" ]; then
        echo "ERROR: One or more images failed to create successfully." >&2
        exit 1
    fi

    # Save SAT-created image IDs for downstream stages.
    echo "export FINAL_MASTER_IMAGE_ID=${FINAL_MASTER_IMAGE_ID}" >> /etc/cray/upgrade/csm/myenv
    echo "export FINAL_WORKER_IMAGE_ID=${FINAL_WORKER_IMAGE_ID}" >> /etc/cray/upgrade/csm/myenv
    echo "export FINAL_STORAGE_IMAGE_ID=${FINAL_STORAGE_IMAGE_ID}" >> /etc/cray/upgrade/csm/myenv

    touch "${DONE_DIR}/create-bootprep-images.done"
    echo "INFO Successfully created images using SAT bootprep"
fi

echo "INFO Posthook for deliver-product completed"
