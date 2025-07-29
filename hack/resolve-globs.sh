#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2025 Hewlett Packard Enterprise Development LP
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

ROOTDIR=$(realpath "${ROOTDIR:-$(dirname "${BASH_SOURCE[0]}")/..}")
source "${ROOTDIR}/assets.sh"
source "${ROOTDIR}/common.sh"

# Resolve globs in KUBERNETES_IMAGE_ID, e.g. 6.2.* > 6.2.30
KUBERNETES_IMAGE_ID=$(basename $(dirname $(resolve_globs "csm-images" "unstable/kubernetes/${KUBERNETES_IMAGE_ID}" "kubernetes-${KUBERNETES_IMAGE_ID}-${NCN_ARCH}.squashfs")))
# Resolve globs in KERNEL_VERSION, e.g. 6.4.0-*-default > 6.4.0-150600.23.17-default
KERNEL_PATH=$(resolve_globs "csm-images" "unstable/kubernetes/${KUBERNETES_IMAGE_ID}" "${KERNEL_VERSION}-${KUBERNETES_IMAGE_ID}-${NCN_ARCH}.kernel")
KERNEL_VERSION=$(basename "${KERNEL_PATH}")
KERNEL_VERSION=${KERNEL_VERSION%-${KUBERNETES_IMAGE_ID}-${NCN_ARCH}.kernel}

# NOTE: The kernel-default-debuginfo package version needs to be aligned
# to the KERNEL_VERSION. Always verify and update the correct version of
# the kernel-default-debuginfo package when changing the KERNEL_VERSION
# by doing a zypper search for the corresponding kernel-default-debuginfo package
# in the SLE-Module-Basesystem update_debug repo
# zypper --plus-repo=https://${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}@artifactory.algol60.net/artifactory/sles-mirror/Updates/SLE-Module-Basesystem/15-SP4/x86_64/update_debug se -s kernel-default-debuginfo
KERNEL_DEFAULT_DEBUGINFO_VERSION="${KERNEL_VERSION//-default/}.1"

KUBERNETES_ASSETS=(
    "https://artifactory.algol60.net/artifactory/csm-images/unstable/kubernetes/${KUBERNETES_IMAGE_ID}/kubernetes-${KUBERNETES_IMAGE_ID}-${NCN_ARCH}.squashfs"
    "https://artifactory.algol60.net/artifactory/csm-images/unstable/kubernetes/${KUBERNETES_IMAGE_ID}/${KERNEL_VERSION}-${KUBERNETES_IMAGE_ID}-${NCN_ARCH}.kernel"
    "https://artifactory.algol60.net/artifactory/csm-images/unstable/kubernetes/${KUBERNETES_IMAGE_ID}/initrd.img-${KUBERNETES_IMAGE_ID}-${NCN_ARCH}.xz"
)

# Resolve globs in PIT_IMAGE_ID, e.g. 6.2.* > 6.2.30
PIT_IMAGE_ID=$(basename $(dirname $(resolve_globs "csm-images" "stable/pre-install-toolkit/${PIT_IMAGE_ID}" "pre-install-toolkit-${PIT_IMAGE_ID}-${NCN_ARCH}.iso")))
PIT_ASSETS=(
    "https://artifactory.algol60.net/artifactory/csm-images/stable/pre-install-toolkit/${PIT_IMAGE_ID}/pre-install-toolkit-${PIT_IMAGE_ID}-${NCN_ARCH}.iso"
)

# Resolve globs in STORAGE_CEPH_IMAGE_ID, e.g. 6.2.* > 6.2.30
STORAGE_CEPH_IMAGE_ID=$(basename $(dirname $(resolve_globs "csm-images" "stable/storage-ceph/${STORAGE_CEPH_IMAGE_ID}" "storage-ceph-${STORAGE_CEPH_IMAGE_ID}-${NCN_ARCH}.squashfs")))
STORAGE_CEPH_ASSETS=(
    "https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/${STORAGE_CEPH_IMAGE_ID}/storage-ceph-${STORAGE_CEPH_IMAGE_ID}-${NCN_ARCH}.squashfs"
    "https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/${STORAGE_CEPH_IMAGE_ID}/${KERNEL_VERSION}-${STORAGE_CEPH_IMAGE_ID}-${NCN_ARCH}.kernel"
    "https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/${STORAGE_CEPH_IMAGE_ID}/initrd.img-${STORAGE_CEPH_IMAGE_ID}-${NCN_ARCH}.xz"
)

for arch in "${CN_ARCH[@]}"; do
    # Resolve globs in COMPUTE_IMAGE_ID, e.g. 6.2.* > 6.2.30
    COMPUTE_IMAGE_ID=$(basename $(dirname $(resolve_globs "csm-images" "stable/compute/${COMPUTE_IMAGE_ID}" "compute-${COMPUTE_IMAGE_ID}-${arch}.squashfs")))
    eval "COMPUTE_${arch}_ASSETS"=\( \
        "https://artifactory.algol60.net/artifactory/csm-images/stable/compute/${COMPUTE_IMAGE_ID}/compute-${COMPUTE_IMAGE_ID}-${arch}.squashfs" \
        "https://artifactory.algol60.net/artifactory/csm-images/stable/compute/${COMPUTE_IMAGE_ID}/${KERNEL_VERSION}-${COMPUTE_IMAGE_ID}-${arch}.kernel" \
        "https://artifactory.algol60.net/artifactory/csm-images/stable/compute/${COMPUTE_IMAGE_ID}/initrd.img-${COMPUTE_IMAGE_ID}-${arch}.xz" \
    \)
done
