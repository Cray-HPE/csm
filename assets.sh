#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

PIT_ASSETS=(
    http://car.dev.cray.com/artifactory/csm/MTL/sle15_sp2_ncn/x86_64/release/shasta-1.4/metal-team/cray-pre-install-toolkit-sle15sp2.x86_64-1.4.1-20210206225826-g566b697.iso
    http://car.dev.cray.com/artifactory/csm/MTL/sle15_sp2_ncn/x86_64/release/shasta-1.4/metal-team/cray-pre-install-toolkit-sle15sp2.x86_64-1.4.1-20210206225826-g566b697.packages
    http://car.dev.cray.com/artifactory/csm/MTL/sle15_sp2_ncn/x86_64/release/shasta-1.4/metal-team/cray-pre-install-toolkit-sle15sp2.x86_64-1.4.1-20210206225826-g566b697.verified
)

KUBERNETES_ASSETS=(
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/kubernetes/0.0.28/kubernetes-0.0.28.squashfs
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/kubernetes/0.0.28/5.3.18-24.46-default-0.0.28.kernel
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/kubernetes/0.0.28/initrd.img-0.0.28.xz
)

STORAGE_CEPH_ASSETS=(
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/storage-ceph/0.0.24/storage-ceph-0.0.24.squashfs
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/storage-ceph/0.0.24/5.3.18-24.46-default-0.0.24.kernel
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/storage-ceph/0.0.24/initrd.img-0.0.24.xz
)

set -exo pipefail

# Verify assets exist
for url in "${PIT_ASSETS[@]}"; do curl -sfSLI "$url"; done
for url in "${KUBERNETES_ASSETS[@]}"; do curl -sfSLI "$url"; done
for url in "${STORAGE_ASSETS[@]}"; do curl -sfSLI "$url"; done
