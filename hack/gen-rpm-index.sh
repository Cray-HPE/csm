#!/usr/bin/env bash

function suse-repos() {
    local uri="$1"
    if [[ "$uri" == "${uri%%/*}" ]]; then
      local uri="${uri}/15-SP2"
    fi
    local repo="$(echo "$uri" | tr -s -c '[:alnum:][:cntrl:]' -)"
    echo "-d https://arti.dev.cray.com/artifactory/mirror-SUSE/Products/${uri}/x86_64/product/ suse/Products/${uri}/x86_64/product"
    echo "-d https://arti.dev.cray.com/artifactory/mirror-SUSE/Updates/${uri}/x86_64/update/ suse/Updates/${uri}/x86_64/update"
}

function cray-repos() {
  local uri="$1"
  shift
  for arch in "$@"; do
    echo "-d http://car.dev.cray.com/artifactory/${uri}/sle15_sp2_ncn/${arch}/${ref:-"release/shasta-1.4"}/ cray/${uri%%/*}/sle-15sp2/"
  done
}

function rpm-index() {
    docker run --rm -i dtr.dev.cray.com/cray/packaging-tools rpm-index -v \
        $(suse-repos SLE-Module-Basesystem) \
        $(suse-repos SLE-Module-Containers) \
        $(suse-repos SLE-Module-Desktop-Applications) \
        $(suse-repos SLE-Module-Development-Tools) \
        $(suse-repos SLE-Module-HPC) \
        $(suse-repos SLE-Module-Legacy) \
        $(suse-repos SLE-Module-Public-Cloud) \
        $(suse-repos SLE-Module-Python2) \
        $(suse-repos SLE-Module-Server-Applications) \
        $(suse-repos SLE-Module-Web-Scripting) \
        $(suse-repos SLE-Product-HPC) \
        $(suse-repos SLE-Product-SLES) \
        $(suse-repos SLE-Product-WE) \
        $(suse-repos Storage/6) \
        $(suse-repos Storage/7) \
        -d https://arti.dev.cray.com/artifactory/mirror-SUSE/Backports/SLE-15-SP2_x86_64/standard/ suse/Backports/15-SP2/x86_64/standard \
        -d http://car.dev.cray.com/artifactory/mirror-sles15sp2/Updates/SLE-Module-Basesystem-PTF/ suse/PTFs/SLE-Module-Basesystem/15-SP2/x86_64/ptf \
        -d https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64 kubernetes/el7/x86_64 \
        $(cray-repos cos/DVS        x86_64) \
        $(cray-repos cos/LUS        x86_64) \
        $(cray-repos cos/SHASTA-3RD x86_64) \
        $(cray-repos cos/SHASTA-OS  noarch x86_64) \
        $(cray-repos csm/CDS   x86_64) \
        $(cray-repos csm/CLOUD x86_64) \
        $(cray-repos csm/CSM   noarch) \
        $(cray-repos csm/MTL   noarch x86_64) \
        $(cray-repos csm/SCMS  x86_64) \
        $(cray-repos csm/SPET  noarch x86_64) \
        $(cray-repos csm/UAS   x86_64) \
        $(cray-repos sat/SAT x86_64) \
        $(cray-repos slingshot/OFI-CRAY noarch x86_64) \
        $(cray-repos slingshot/SSHOT    x86_64) \
        $(cray-repos sdu/SSA noarch x86_64) \
        $(cray-repos ct-tests/HMS x86_64) \
        -
}

set -ex

rpm-index
