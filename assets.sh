#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2021-2022 Hewlett Packard Enterprise Development LP
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

# Multi-arch management clusters are not supported.
NCN_ARCH='x86_64'

# Application image architecture (including compute)
#CN_ARCH=("x86_64" "aarch64")
CN_ARCH=("x86_64")

# All images must use the same, exact kernel version.
KERNEL_VERSION='5.14.21-150500.55.28.1.26977.2.PTF.1214754-default'
# NOTE: The kernel-default-debuginfo package version needs to be aligned
# to the KERNEL_VERSION. Always verify and update the correct version of
# the kernel-default-debuginfo package when changing the KERNEL_VERSION
# by doing a zypper search for the corresponding kernel-default-debuginfo package
# in the SLE-Module-Basesystem update_debug repo
# zypper --plus-repo=https://${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}@artifactory.algol60.net/artifactory/sles-mirror/Updates/SLE-Module-Basesystem/15-SP5/x86_64/update_debug se -s kernel-default-debuginfo
#KERNEL_DEFAULT_DEBUGINFO_VERSION="${KERNEL_VERSION/-default/}.1"
KERNEL_DEFAULT_DEBUGINFO_VERSION="5.14.21-150500.55.28.1.26977.2.PTF.1214754"

# The image ID may not always match the other images and should be defined individually.
KUBERNETES_IMAGE_ID=5.2.43
KUBERNETES_ASSETS=(
    "https://artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/${KUBERNETES_IMAGE_ID}/kubernetes-${KUBERNETES_IMAGE_ID}-${NCN_ARCH}.squashfs"
    "https://artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/${KUBERNETES_IMAGE_ID}/${KERNEL_VERSION}-${KUBERNETES_IMAGE_ID}-${NCN_ARCH}.kernel"
    "https://artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/${KUBERNETES_IMAGE_ID}/initrd.img-${KUBERNETES_IMAGE_ID}-${NCN_ARCH}.xz"
)

# The image ID may not always match the other images and should be defined individually.
PIT_IMAGE_ID=5.2.43
PIT_ASSETS=(
    "https://artifactory.algol60.net/artifactory/csm-images/stable/pre-install-toolkit/${PIT_IMAGE_ID}/pre-install-toolkit-${PIT_IMAGE_ID}-${NCN_ARCH}.iso"
)

# The image ID may not always match the other images and should be defined individually.
STORAGE_CEPH_IMAGE_ID=5.2.43
STORAGE_CEPH_ASSETS=(
    "https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/${STORAGE_CEPH_IMAGE_ID}/storage-ceph-${STORAGE_CEPH_IMAGE_ID}-${NCN_ARCH}.squashfs"
    "https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/${STORAGE_CEPH_IMAGE_ID}/${KERNEL_VERSION}-${STORAGE_CEPH_IMAGE_ID}-${NCN_ARCH}.kernel"
    "https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/${STORAGE_CEPH_IMAGE_ID}/initrd.img-${STORAGE_CEPH_IMAGE_ID}-${NCN_ARCH}.xz"
)

# The image ID may not always match the other images and should be defined individually.
COMPUTE_IMAGE_ID=5.2.43
for arch in "${CN_ARCH[@]}"; do
    eval "COMPUTE_${arch}_ASSETS"=\( \
        "https://artifactory.algol60.net/artifactory/csm-images/stable/compute/${COMPUTE_IMAGE_ID}/compute-${COMPUTE_IMAGE_ID}-${arch}.squashfs" \
        "https://artifactory.algol60.net/artifactory/csm-images/stable/compute/${COMPUTE_IMAGE_ID}/${KERNEL_VERSION}-${COMPUTE_IMAGE_ID}-${arch}.kernel" \
        "https://artifactory.algol60.net/artifactory/csm-images/stable/compute/${COMPUTE_IMAGE_ID}/initrd.img-${COMPUTE_IMAGE_ID}-${arch}.xz" \
    \)
done

HPE_SIGNING_KEY=https://arti.hpc.amslabs.hpecorp.net/artifactory/dst-misc-stable-local/SigningKeys/HPE-SHASTA-RPM-PROD.asc
