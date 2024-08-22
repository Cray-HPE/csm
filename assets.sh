#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2021-2022, 2024 Hewlett Packard Enterprise Development LP
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
KERNEL_VERSION='6.4.0-150600.23.7.4.28314.3.PTF.1215587-default'
# NOTE: The kernel-default-debuginfo package version needs to be aligned
# to the KERNEL_VERSION. Always verify and update the correct version of
# the kernel-default-debuginfo package when changing the KERNEL_VERSION
# by doing a zypper search for the corresponding kernel-default-debuginfo package
# in the SLE-Module-Basesystem update_debug repo
# zypper --plus-repo=https://${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}@artifactory.algol60.net/artifactory/sles-mirror/Updates/SLE-Module-Basesystem/15-SP4/x86_64/update_debug se -s kernel-default-debuginfo
KERNEL_DEFAULT_DEBUGINFO_VERSION="${KERNEL_VERSION//-default/}"

# The image ID may not always match the other images and should be defined individually.
KUBERNETES_IMAGE_ID=6.2.3
KUBERNETES_ASSETS=(
    "https://artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/${KUBERNETES_IMAGE_ID}/kubernetes-${KUBERNETES_IMAGE_ID}-${NCN_ARCH}.squashfs"
    "https://artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/${KUBERNETES_IMAGE_ID}/${KERNEL_VERSION}-${KUBERNETES_IMAGE_ID}-${NCN_ARCH}.kernel"
    "https://artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/${KUBERNETES_IMAGE_ID}/initrd.img-${KUBERNETES_IMAGE_ID}-${NCN_ARCH}.xz"
)

# The image ID may not always match the other images and should be defined individually.
PIT_IMAGE_ID=6.2.3
PIT_ASSETS=(
    "https://artifactory.algol60.net/artifactory/csm-images/stable/pre-install-toolkit/${PIT_IMAGE_ID}/pre-install-toolkit-${PIT_IMAGE_ID}-${NCN_ARCH}.iso"
)

# The image ID may not always match the other images and should be defined individually.
STORAGE_CEPH_IMAGE_ID=6.2.3
STORAGE_CEPH_ASSETS=(
    "https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/${STORAGE_CEPH_IMAGE_ID}/storage-ceph-${STORAGE_CEPH_IMAGE_ID}-${NCN_ARCH}.squashfs"
    "https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/${STORAGE_CEPH_IMAGE_ID}/${KERNEL_VERSION}-${STORAGE_CEPH_IMAGE_ID}-${NCN_ARCH}.kernel"
    "https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/${STORAGE_CEPH_IMAGE_ID}/initrd.img-${STORAGE_CEPH_IMAGE_ID}-${NCN_ARCH}.xz"
)

# The image ID may not always match the other images and should be defined individually.
COMPUTE_IMAGE_ID=6.2.3
for arch in "${CN_ARCH[@]}"; do
    eval "COMPUTE_${arch}_ASSETS"=\( \
        "https://artifactory.algol60.net/artifactory/csm-images/stable/compute/${COMPUTE_IMAGE_ID}/compute-${COMPUTE_IMAGE_ID}-${arch}.squashfs" \
        "https://artifactory.algol60.net/artifactory/csm-images/stable/compute/${COMPUTE_IMAGE_ID}/${KERNEL_VERSION}-${COMPUTE_IMAGE_ID}-${arch}.kernel" \
        "https://artifactory.algol60.net/artifactory/csm-images/stable/compute/${COMPUTE_IMAGE_ID}/initrd.img-${COMPUTE_IMAGE_ID}-${arch}.xz" \
    \)
done

# Public keys for RPM signature validation.
#
# hpe-signing-key.asc - for all packages signed by HPE Code Signing DST/CSM old key (expires 2025-12-07)
# hpe-signing-key-fips.asc - for all packages signed by HPE Code Signing, DST new key (expires 2026-09-01), for example kernel-mft-mlnx-kmp-default
# hpe-sdr-signing-key.asc - older HPE key used by SDR repos (Qlogic driver - qlgc-fastlinq-kmp-default)
# suse-package-key.asc - for most SUSE packages in embedded repo
# opensuse-obs-filesystems.asc - for packages copied into /csm-rpms/stable from OpenSUSE filesystems (such as csm-rpms/hpe/stable/sle-15sp5/ceph-common-17.2.6.865+g60870edfe2e-lp155.1.1.x86_64.rpm): https://download.opensuse.org/repositories/filesystems:/ceph:/quincy:/upstream/openSUSE_Leap_15.5/repodata/repomd.xml.key
# opensuse-obs-backports.asc - for packages in /sles-mirror/Backports/SLE-15-SP5_x86_64 (dkms, perl-File-BaseDir)
# suse_ptf_key.asc - for SUSE PTF kernel packages, see https://www.suse.com/support/kb/doc/?id=000018545
# opensuse-tumbleweed.asc - k8s packages taken from https://download.opensuse.org/tumbleweed/repo/oss/repodata/
HPE_RPM_SIGNING_KEYS=(
    https://artifactory.algol60.net/artifactory/gpg-keys/hpe-signing-key.asc
    https://artifactory.algol60.net/artifactory/gpg-keys/hpe-signing-key-fips.asc
    https://artifactory.algol60.net/artifactory/gpg-keys/hpe-sdr-signing-key.asc
    # https://artifactory.algol60.net/artifactory/gpg-keys/google-package-key.asc
    https://artifactory.algol60.net/artifactory/gpg-keys/suse-package-key.asc
    https://artifactory.algol60.net/artifactory/gpg-keys/suse-package-2027-01-18.key
    https://artifactory.algol60.net/artifactory/gpg-keys/opensuse-obs-filesystems-15-sp5.asc
    https://artifactory.algol60.net/artifactory/gpg-keys/opensuse-obs-backports-15-sp5.asc
    https://artifactory.algol60.net/artifactory/gpg-keys/suse_ptf_key.asc
    https://artifactory.algol60.net/artifactory/gpg-keys/opensuse-tumbleweed.asc
)

# Public keys for container image signature validation.
#
HPE_OCI_SIGNING_KEYS=(
    https://artifactory.algol60.net/artifactory/gpg-keys/csm-sigstore-images.pub
    https://artifactory.algol60.net/artifactory/gpg-keys/gcp-csm-builds-github-cray-hpe.pub
    https://artifactory.algol60.net/artifactory/gpg-keys/gcp-csm-builds-jenkins-csm.pub
)
