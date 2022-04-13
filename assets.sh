#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2021-2022 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
PIT_ASSETS=(
    https://artifactory.algol60.net/artifactory/csm-images/stable/cray-pre-install-toolkit/1.5.8/cray-pre-install-toolkit-sle15sp3.x86_64-1.5.8-20220401214149-ga02c80b.iso
    https://artifactory.algol60.net/artifactory/csm-images/stable/cray-pre-install-toolkit/1.5.8/cray-pre-install-toolkit-sle15sp3.x86_64-1.5.8-20220401214149-ga02c80b.packages
    https://artifactory.algol60.net/artifactory/csm-images/stable/cray-pre-install-toolkit/1.5.8/cray-pre-install-toolkit-sle15sp3.x86_64-1.5.8-20220401214149-ga02c80b.verified
)

KUBERNETES_ASSETS=(
    https://artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/0.2.73/kubernetes-0.2.73.squashfs
    https://artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/0.2.73/5.3.18-150300.59.43-default-0.2.73.kernel
    https://artifactory.algol60.net/artifactory/csm-images/stable/kubernetes/0.2.73/initrd.img-0.2.73.xz
)

STORAGE_CEPH_ASSETS=(
    https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/0.2.73/storage-ceph-0.2.73.squashfs
    https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/0.2.73/5.3.18-150300.59.43-default-0.2.73.kernel
    https://artifactory.algol60.net/artifactory/csm-images/stable/storage-ceph/0.2.73/initrd.img-0.2.73.xz
)

HPE_SIGNING_KEY=https://arti.dev.cray.com/artifactory/dst-misc-stable-local/SigningKeys/HPE-SHASTA-RPM-PROD.asc

set -exo pipefail

# usage: cmd_retry <cmd> <arg1> ...
#
# Run the specified command until it passes or until it fails too many times
function cmd_retry
{
    local -i attempt
    # For now I'm hard coding these values, but it would be easy to make them into function
    # arguments in the future, if desired
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
cmd_retry curl -sfSLI "$HPE_SIGNING_KEY"

# Verify that kubernetes and other supplementary images, shipped with node-image, are
# present in manifest (and, cnsequently, in Nexus). Versions, shipped with node image,
# are exposed as image file properties in Artifactory.
ROOTDIR=$(dirname $0)
KUBERNETES_VERSIONS_JSON="$(mktemp)"
trap "rm -f '${KUBERNETES_VERSIONS_JSON}'" EXIT
shopt -s expand_aliases
alias yq="${ROOTDIR}/vendor/stash.us.cray.com/scm/shasta-cfg/stable/utils/bin/$(uname | awk '{print tolower($0)}')/yq"
cmd_retry curl -sSL -o "${KUBERNETES_VERSIONS_JSON}" "${KUBERNETES_ASSETS[0]/artifactory\/csm-images/artifactory\/api\/storage\/csm-images}?properties"
declare -A KUBERNETES_IMAGES=(
    [KUBERNETES_VERSION]="k8s.gcr.io/kube-apiserver k8s.gcr.io/kube-controller-manager k8s.gcr.io/kube-proxy k8s.gcr.io/kube-scheduler"
    [WEAVE_VERSION]="docker.io/weaveworks/weave-kube docker.io/weaveworks/weave-npc"
    [MULTUS_VERSION]="docker.io/nfvpe/multus"
    [COREDNS_VERSION]="k8s.gcr.io/coredns"
)
error=0
for KEY in "${!KUBERNETES_IMAGES[@]}"; do
    for IMAGE_TAG in $(jq -r ".properties.\"csm.versions.${KEY}\"[]?" "${KUBERNETES_VERSIONS_JSON}"); do
        for IMAGE_NAME in ${KUBERNETES_IMAGES[${KEY}]}; do
            if yq read "${ROOTDIR}/docker/index.yaml" "\"artifactory.algol60.net/csm-docker/stable\".images.\"${IMAGE_NAME}\".[*]" | grep -F -x -q "${IMAGE_TAG}"; then
                echo "INFO: Image ${IMAGE_NAME}:${IMAGE_TAG} is found in manifest."
            else
                echo "ERROR: Image ${IMAGE_NAME}:${IMAGE_TAG} is not found in manifest."
                error=1
            fi
        done
    done
done
if [ $error -eq 1 ]; then
    echo "ERROR: Assets components image validation failed. Not all container images for components, shipped with node image,"
    echo "ERROR: are listed in manifest (see above). Add missing container images to docker/images.yaml, or use different node image."
    exit 1
fi
