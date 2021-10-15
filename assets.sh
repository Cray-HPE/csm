#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

PIT_ASSETS=(
    https://artifactory.algol60.net/artifactory/csm-images/stable/cray-pre-install-toolkit/1.5.5/cray-pre-install-toolkit-sle15sp3.x86_64-1.5.5-20211015205247-g8644881.iso
    https://artifactory.algol60.net/artifactory/csm-images/stable/cray-pre-install-toolkit/1.5.5/cray-pre-install-toolkit-sle15sp3.x86_64-1.5.5-20211015205247-g8644881.packages
    https://artifactory.algol60.net/artifactory/csm-images/stable/cray-pre-install-toolkit/1.5.5/cray-pre-install-toolkit-sle15sp3.x86_64-1.5.5-20211015205247-g8644881.verified
)

KUBERNETES_ASSETS=(
    https://artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/0.2.7/kubernetes-0.2.7.squashfs
    https://artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/0.2.7/5.3.18-59.27-default-0.2.7.kernel
    https://artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/0.2.7/initrd.img-0.2.7.xz
)

STORAGE_CEPH_ASSETS=(
    https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/0.2.7/storage-ceph-0.2.7.squashfs
    https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/0.2.7/5.3.18-59.27-default-0.2.7.kernel
    https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/0.2.7/initrd.img-0.2.7.xz
)

HPE_SIGNING_KEY=https://arti.dev.cray.com/artifactory/dst-misc-stable-local/SigningKeys/HPE-SHASTA-RPM-PROD.asc

set -exo pipefail

# Verify assets exist
for url in "${PIT_ASSETS[@]}"; do curl -sfSLI "$url"; done
for url in "${KUBERNETES_ASSETS[@]}"; do curl -sfSLI "$url"; done
for url in "${STORAGE_CEPH_ASSETS[@]}"; do curl -sfSLI "$url"; done
curl -sfSLI "$HPE_SIGNING_KEY"
