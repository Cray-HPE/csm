#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

PIT_ASSETS=(
    https://arti.dev.cray.com/artifactory/csm-distribution-stable-local/cray-pre-install-toolkit/1.4.9/cray-pre-install-toolkit-sle15sp2.x86_64-1.4.9-20210309034439-g1e67449.iso
    https://arti.dev.cray.com/artifactory/csm-distribution-stable-local/cray-pre-install-toolkit/1.4.9/cray-pre-install-toolkit-sle15sp2.x86_64-1.4.9-20210309034439-g1e67449.packages
    https://arti.dev.cray.com/artifactory/csm-distribution-stable-local/cray-pre-install-toolkit/1.4.9/cray-pre-install-toolkit-sle15sp2.x86_64-1.4.9-20210309034439-g1e67449.verified
)

KUBERNETES_ASSETS=(
    https://artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/0.0.57/kubernetes-0.0.57.squashfs
    https://artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/0.0.57/5.3.18-24.75-default-0.0.57.kernel
    https://artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/0.0.57/initrd.img-0.0.57.xz
)

STORAGE_CEPH_ASSETS=(
    https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/0.0.47/storage-ceph-0.0.47.squashfs
    https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/0.0.47/5.3.18-24.75-default-0.0.47.kernel
    https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/0.0.47/initrd.img-0.0.47.xz
)

FIRMWARE_PACKAGE=http://car.dev.cray.com/artifactory/internal/~PVIRTUCIO/release/Cray_Firmware/03.04.2021_v1/firmware_package_03042021a.tgz

FIRMWARE_ASSETS=(
    http://car.dev.cray.com/artifactory/list/integration-firmware/aruba/ArubaOS-CX_8320_10_06_0110.stable.swi
    http://car.dev.cray.com/artifactory/list/integration-firmware/aruba/ArubaOS-CX_8360_10_06_0110.stable.swi
)

set -exo pipefail

function cmd_retry
{
    # usage: <cmd> <arg1> ...

    local -i attempt
    local -i max_attempts=10
    local -i sleep_time=12
    attempt=1
    while [ true ]; do
        # We redirect to stderr just in case the output of this command is being piped
        echo "Attempt #$attempt to run: $*" 1>&2
        if "$@" ; then
            return 0
        elif [ $attempt -lt $max_attempts ]; then
           echo "Sleeping ${sleep_time} seconds before retry" 1>&2
           sleep ${sleep_time}
           attempt=$(($attempt + 1))
           continue
        fi
        echo "ERROR: Unable to get $url even after retries" 1>&2
        return 1
    done
    echo "PROGRAMMING LOGIC ERROR: This line should never be reached" 1>&2
    exit 1
}

# Verify assets exist
for url in "${PIT_ASSETS[@]}"; do cmd_retry curl -sfSLI "$url"; done
for url in "${KUBERNETES_ASSETS[@]}"; do cmd_retry curl -sfSLI "$url"; done
for url in "${STORAGE_CEPH_ASSETS[@]}"; do cmd_retry curl -sfSLI "$url"; done
cmd_retry curl -sfSLI "$FIRMWARE_PACKAGE"
for url in "${FIRMWARE_ASSETS[@]}"; do cmd_retry curl -sfSLI "$url"; done
