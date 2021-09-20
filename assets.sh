#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

PIT_ASSETS=(
    https://arti.dev.cray.com:443/artifactory/csm-misc-master-local/dev/master/sle15_sp3_ncn/x86_64/cray-pre-install-toolkit-sle15sp3.x86_64-1.5.1-20210907082311-g0adb6eb.iso
    https://arti.dev.cray.com:443/artifactory/csm-misc-master-local/dev/master/sle15_sp3_ncn/x86_64/cray-pre-install-toolkit-sle15sp3.x86_64-1.5.1-20210907082311-g0adb6eb.packages
    https://arti.dev.cray.com:443/artifactory/csm-misc-master-local/dev/master/sle15_sp3_ncn/x86_64/cray-pre-install-toolkit-sle15sp3.x86_64-1.5.1-20210907082311-g0adb6eb.verified
)

KUBERNETES_ASSETS=(
    https://artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/0.2.1/kubernetes-0.2.1.squashfs
    https://artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/0.2.1/5.3.18-59.19-default-0.2.1.kernel
    https://artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/0.2.1/initrd-0.2.1.img.xz
)

STORAGE_CEPH_ASSETS=(
    https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/0.2.1/storage-ceph-0.2.1.squashfs
    https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/0.2.1/5.3.18-59.19-default-0.2.1.kernel
    https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/0.2.1/initrd-0.2.1.img.xz
)

HPE_SIGNING_KEY=https://arti.dev.cray.com/artifactory/dst-misc-stable-local/SigningKeys/HPE-SHASTA-RPM-PROD.asc

set -exo pipefail

# Verify assets exist
for url in "${PIT_ASSETS[@]}"; do curl -sfSLI "$url"; done
for url in "${KUBERNETES_ASSETS[@]}"; do curl -sfSLI "$url"; done
for url in "${STORAGE_CEPH_ASSETS[@]}"; do curl -sfSLI "$url"; done
curl -sfSLI "$HPE_SIGNING_KEY"
