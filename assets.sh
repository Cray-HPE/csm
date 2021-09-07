#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

PIT_ASSETS=(
<<<<<<< HEAD
    http://arti.dev.cray.com/artifactory/csm-misc-master-local/dev/master/sle15_sp3_ncn/x86_64/cray-pre-install-toolkit-sle15sp3.x86_64-1.5.0-20210827082307-g1784709.iso
    http://arti.dev.cray.com/artifactory/csm-misc-master-local/dev/master/sle15_sp3_ncn/x86_64/cray-pre-install-toolkit-sle15sp3.x86_64-1.5.0-20210827082307-g1784709.packages
    http://arti.dev.cray.com/artifactory/csm-misc-master-local/dev/master/sle15_sp3_ncn/x86_64/cray-pre-install-toolkit-sle15sp3.x86_64-1.5.0-20210827082307-g1784709.verified
)

KUBERNETES_ASSETS=(
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/kubernetes/0.2.1/kubernetes-0.2.1.squashfs
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/kubernetes/0.2.1/5.3.18-59.16-default-0.2.1.kernel
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/kubernetes/0.2.1/initrd.img-0.2.1.xz
)

STORAGE_CEPH_ASSETS=(
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/storage-ceph/0.2.1/storage-ceph-0.2.1.squashfs
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/storage-ceph/0.2.1/5.3.18-59.16-default-0.2.1.kernel
    https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/storage-ceph/0.2.1/initrd.img-0.2.1.xz
=======
    http://car.dev.cray.com/artifactory/csm/MTL/sle15_sp2_ncn/x86_64/release/csm-1.0/casmpet-team/cray-pre-install-toolkit-sle15sp2.x86_64-1.4.14-20210901181733-g592db0a.iso
    http://car.dev.cray.com/artifactory/csm/MTL/sle15_sp2_ncn/x86_64/release/csm-1.0/casmpet-team/cray-pre-install-toolkit-sle15sp2.x86_64-1.4.14-20210901181733-g592db0a.packages
    http://car.dev.cray.com/artifactory/csm/MTL/sle15_sp2_ncn/x86_64/release/csm-1.0/casmpet-team/cray-pre-install-toolkit-sle15sp2.x86_64-1.4.14-20210901181733-g592db0a.verified
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
>>>>>>> f385627e2fc28ddfc393db734bcdfe27590b76d1
)

HPE_SIGNING_KEY=https://arti.dev.cray.com/artifactory/dst-misc-stable-local/SigningKeys/HPE-SHASTA-RPM-PROD.asc

set -exo pipefail

# Verify assets exist
for url in "${PIT_ASSETS[@]}"; do curl -sfSLI "$url"; done
for url in "${KUBERNETES_ASSETS[@]}"; do curl -sfSLI "$url"; done
for url in "${STORAGE_CEPH_ASSETS[@]}"; do curl -sfSLI "$url"; done
curl -sfSLI "$HPE_SIGNING_KEY"
