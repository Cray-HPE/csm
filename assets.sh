#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

PIT_ASSETS=(
    https://artifactory.algol60.net/artifactory/csm-images/stable/cray-pre-install-toolkit/1.4.18/cray-pre-install-toolkit-sle15sp2.x86_64-1.4.18-20211014030721-g5660d5a.iso
    https://artifactory.algol60.net/artifactory/csm-images/stable/cray-pre-install-toolkit/1.4.18/cray-pre-install-toolkit-sle15sp2.x86_64-1.4.18-20211014030721-g5660d5a.packages
    https://artifactory.algol60.net/artifactory/csm-images/stable/cray-pre-install-toolkit/1.4.18/cray-pre-install-toolkit-sle15sp2.x86_64-1.4.18-20211014030721-g5660d5a.verified
)

KUBERNETES_ASSETS=(
    https://artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/0.1.109/kubernetes-0.1.109.squashfs
    https://artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/0.1.109/5.3.18-24.75-default-0.1.109.kernel
    https://artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/0.1.109/initrd.img-0.1.109.xz
)

STORAGE_CEPH_ASSETS=(
    https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/0.1.109/storage-ceph-0.1.109.squashfs
    https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/0.1.109/5.3.18-24.75-default-0.1.109.kernel
    https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/0.1.109/initrd.img-0.1.109.xz
)

HPE_SIGNING_KEY=https://arti.dev.cray.com/artifactory/dst-misc-stable-local/SigningKeys/HPE-SHASTA-RPM-PROD.asc

set -exo pipefail

# Verify assets exist
for url in "${PIT_ASSETS[@]}"; do curl -sfSLI "$url"; done
for url in "${KUBERNETES_ASSETS[@]}"; do curl -sfSLI "$url"; done
for url in "${STORAGE_CEPH_ASSETS[@]}"; do curl -sfSLI "$url"; done
curl -sfSLI "$HPE_SIGNING_KEY"
