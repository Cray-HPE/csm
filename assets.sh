#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

PIT_ASSETS=(
    https://artifactory.algol60.net/artifactory/csm-images/unstable/cray-pre-install-toolkit/1.4.15/cray-pre-install-toolkit-sle15sp2.x86_64-1.4.15-20210927234959-g735efde.iso
    https://artifactory.algol60.net/artifactory/csm-images/unstable/cray-pre-install-toolkit/1.4.15/cray-pre-install-toolkit-sle15sp2.x86_64-1.4.15-20210927234959-g735efde.packages
    https://artifactory.algol60.net/artifactory/csm-images/unstable/cray-pre-install-toolkit/1.4.15/cray-pre-install-toolkit-sle15sp2.x86_64-1.4.15-20210927234959-g735efde.verified
)

KUBERNETES_ASSETS=(
    https://artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/0.1.105/kubernetes-0.1.105.squashfs
    https://artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/0.1.105/5.3.18-24.75-default-0.1.105.kernel
    https://artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/0.1.105/initrd.img-0.1.105.xz
)

STORAGE_CEPH_ASSETS=(
    https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/0.1.105/storage-ceph-0.1.105.squashfs
    https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/0.1.105/5.3.18-24.75-default-0.1.105.kernel
    https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/0.1.105/initrd.img-0.1.105.xz
)

HPE_SIGNING_KEY=https://arti.dev.cray.com/artifactory/dst-misc-stable-local/SigningKeys/HPE-SHASTA-RPM-PROD.asc

set -exo pipefail

# Verify assets exist
for url in "${PIT_ASSETS[@]}"; do curl -sfSLI "$url"; done
for url in "${KUBERNETES_ASSETS[@]}"; do curl -sfSLI "$url"; done
for url in "${STORAGE_CEPH_ASSETS[@]}"; do curl -sfSLI "$url"; done
curl -sfSLI "$HPE_SIGNING_KEY"
