#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

PIT_ASSETS=(
    https://arti.dev.cray.com/artifactory/csm-distribution-stable-local/cray-pre-install-toolkit/1.4.9/cray-pre-install-toolkit-sle15sp2.x86_64-1.4.9-20210309034439-g1e67449.iso
    https://arti.dev.cray.com/artifactory/csm-distribution-stable-local/cray-pre-install-toolkit/1.4.9/cray-pre-install-toolkit-sle15sp2.x86_64-1.4.9-20210309034439-g1e67449.packages
    https://arti.dev.cray.com/artifactory/csm-distribution-stable-local/cray-pre-install-toolkit/1.4.9/cray-pre-install-toolkit-sle15sp2.x86_64-1.4.9-20210309034439-g1e67449.verified
)

KUBERNETES_ASSETS=(
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/kubernetes/0.0.53/kubernetes-0.0.53.squashfs
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/kubernetes/0.0.53/5.3.18-24.49-default-0.0.53.kernel
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/kubernetes/0.0.53/initrd.img-0.0.53.xz
)

STORAGE_CEPH_ASSETS=(
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/storage-ceph/0.0.44/storage-ceph-0.0.44.squashfs
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/storage-ceph/0.0.44/5.3.18-24.49-default-0.0.44.kernel
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/storage-ceph/0.0.44/initrd.img-0.0.44.xz
)

FIRMWARE_PACKAGE=http://car.dev.cray.com/artifactory/internal/~PVIRTUCIO/release/Cray_Firmware/03.04.2021_v1/firmware_package_03042021a.tgz

FIRMWARE_ASSETS=(
    http://car.dev.cray.com/artifactory/list/integration-firmware/aruba/ArubaOS-CX_8360_10_06_0110.swi
)

set -exo pipefail

# Verify assets exist
for url in "${PIT_ASSETS[@]}"; do curl -sfSLI "$url"; done
for url in "${KUBERNETES_ASSETS[@]}"; do curl -sfSLI "$url"; done
for url in "${STORAGE_CEPH_ASSETS[@]}"; do curl -sfSLI "$url"; done
curl -sfSLI "$FIRMWARE_PACKAGE"
for url in "${FIRMWARE_ASSETS[@]}"; do curl -sfSLI "$url"; done
