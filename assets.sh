#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

PIT_ASSETS=(
    https://arti.dev.cray.com/artifactory/csm-misc-stable-local/release/csm-1.1/sle15_sp2_ncn/x86_64/cray-pre-install-toolkit-sle15sp2.x86_64-1.4.15-20210908143924-ge18e257.iso
    https://arti.dev.cray.com/artifactory/csm-misc-stable-local/release/csm-1.1/sle15_sp2_ncn/x86_64/cray-pre-install-toolkit-sle15sp2.x86_64-1.4.15-20210908143924-ge18e257.packages
    https://arti.dev.cray.com/artifactory/csm-misc-stable-local/release/csm-1.1/sle15_sp2_ncn/x86_64/cray-pre-install-toolkit-sle15sp2.x86_64-1.4.15-20210908143924-ge18e257.verified
)

KUBERNETES_ASSETS=(
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/kubernetes/0.1.80/kubernetes-0.1.80.squashfs
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/kubernetes/0.1.80/5.3.18-24.75-default-0.1.80.kernel
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/kubernetes/0.1.80/initrd.img-0.1.80.xz
)

STORAGE_CEPH_ASSETS=(
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/storage-ceph/0.1.78/storage-ceph-0.1.78.squashfs
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/storage-ceph/0.1.78/5.3.18-24.75-default-0.1.78.kernel
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/storage-ceph/0.1.78/initrd.img-0.1.78.xz
)

HPE_SIGNING_KEY=https://arti.dev.cray.com/artifactory/dst-misc-stable-local/SigningKeys/HPE-SHASTA-RPM-PROD.asc

set -exo pipefail

# Verify assets exist
for url in "${PIT_ASSETS[@]}"; do curl -sfSLI "$url"; done
for url in "${KUBERNETES_ASSETS[@]}"; do curl -sfSLI "$url"; done
for url in "${STORAGE_CEPH_ASSETS[@]}"; do curl -sfSLI "$url"; done
curl -sfSLI "$HPE_SIGNING_KEY"
