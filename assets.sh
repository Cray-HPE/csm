#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

PIT_ASSETS=(
    http://car.dev.cray.com/artifactory/csm/MTL/sle15_sp2_ncn/x86_64/release/shasta-1.4/metal-team/cray-pre-install-toolkit-sle15sp2.x86_64-1.4.7-20210220024508-g406d7a6.iso
    http://car.dev.cray.com/artifactory/csm/MTL/sle15_sp2_ncn/x86_64/release/shasta-1.4/metal-team/cray-pre-install-toolkit-sle15sp2.x86_64-1.4.7-20210220024508-g406d7a6.packages
    http://car.dev.cray.com/artifactory/csm/MTL/sle15_sp2_ncn/x86_64/release/shasta-1.4/metal-team/cray-pre-install-toolkit-sle15sp2.x86_64-1.4.7-20210220024508-g406d7a6.verified
)

KUBERNETES_ASSETS=(
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/kubernetes/0.0.37/kubernetes-0.0.37.squashfs
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/kubernetes/0.0.37/5.3.18-24.46-default-0.0.37.kernel
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/kubernetes/0.0.37/initrd.img-0.0.37.xz
)

STORAGE_CEPH_ASSETS=(
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/storage-ceph/0.0.32/storage-ceph-0.0.32.squashfs
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/storage-ceph/0.0.32/5.3.18-24.46-default-0.0.32.kernel
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/storage-ceph/0.0.32/initrd.img-0.0.32.xz
)

set -exo pipefail

# Verify assets exist
for url in "${PIT_ASSETS[@]}"; do curl -sfSLI "$url"; done
for url in "${KUBERNETES_ASSETS[@]}"; do curl -sfSLI "$url"; done
for url in "${STORAGE_CEPH_ASSETS[@]}"; do curl -sfSLI "$url"; done
