#!/usr/bin/env bash

set -eo pipefail

ROOTDIR=$(realpath "${ROOTDIR:-$(dirname "${BASH_SOURCE[0]}")/..}")
source "${ROOTDIR}/assets.sh"
source "${ROOTDIR}/vendor/github.hpe.com/hpe/hpc-shastarelm-release/lib/release.sh"

if [ -z "${ARTIFACTORY_USER}" ] || [ -z "${ARTIFACTORY_TOKEN}" ]; then
    echo "Missing authentication information for image download. Please set ARTIFACTORY_USER and ARTIFACTORY_TOKEN environment variables."
    exit 1
fi

# Verify assets exist
for url in "${PIT_ASSETS[@]}"; do cmd_retry curl -sfSLI -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" "$url"; done
for url in "${KUBERNETES_ASSETS[@]}"; do cmd_retry curl -sfSLI -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" "$url"; done
for url in "${STORAGE_CEPH_ASSETS[@]}"; do cmd_retry curl -sfSLI -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" "$url"; done
for arch in "${CN_ARCH[@]}"; do
    for url in $(eval echo \${COMPUTE_${arch}_ASSETS[@]}); do cmd_retry curl -sfSLI -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" "$url"; done
done

cmd_retry curl -sfSLI "$HPE_SIGNING_KEY"

# Verify that kubernetes and other supplementary images, shipped with node-image, are
# present in manifest (and, cnsequently, in Nexus). Versions, shipped with node image,
# are exposed as image file properties in Artifactory.
KUBERNETES_VERSIONS_JSON="$(mktemp)"
trap "rm -f '${KUBERNETES_VERSIONS_JSON}'" EXIT
shopt -s expand_aliases
alias yq="${ROOTDIR}/vendor/github.com/Cray-HPE/shasta-cfg/utils/bin/$(uname | awk '{print tolower($0)}')/yq"
cmd_retry curl -sSL -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" -o "${KUBERNETES_VERSIONS_JSON}" "${KUBERNETES_ASSETS[0]/artifactory\/csm-images/artifactory\/api\/storage\/csm-images}?properties"
declare -A KUBERNETES_IMAGES=(
    [KUBERNETES_VERSION]="k8s.gcr.io/kube-apiserver k8s.gcr.io/kube-controller-manager k8s.gcr.io/kube-proxy k8s.gcr.io/kube-scheduler"
    [WEAVE_VERSION]="docker.io/weaveworks/weave-kube docker.io/weaveworks/weave-npc"
    [MULTUS_VERSION]="ghcr.io/k8snetworkplumbingwg/multus-cni"
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
