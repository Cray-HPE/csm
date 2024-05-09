#!/usr/bin/env bash

set -eo pipefail

ROOTDIR=$(realpath "${ROOTDIR:-$(dirname "${BASH_SOURCE[0]}")/..}")
source "${ROOTDIR}/assets.sh"

if [ -z "${ARTIFACTORY_USER}" ] || [ -z "${ARTIFACTORY_TOKEN}" ]; then
    echo "Missing authentication information for image download. Please set ARTIFACTORY_USER and ARTIFACTORY_TOKEN environment variables."
    exit 1
fi

function verify_file() {
    if [ -n "${CSM_BASE_VERSION}" ] && [ -f "${ROOTDIR}/dist/csm-${CSM_BASE_VERSION}/${2}" ]; then
        echo "Found ${2} in CSM base"
    else
        curl -sfSL -X HEAD --ignore-content-length -w "Validating ${1} ... http code %{response_code}\n" ${3:+-u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}"} "${1}"
    fi
}

# Verify assets exist
for url in "${PIT_ASSETS[@]}"; do verify_file "$url" "images/pre-install-toolkit/$(basename $url)" yes; done
for url in "${KUBERNETES_ASSETS[@]}"; do verify_file "$url" "images/kubernetes/$(basename $url)" yes; done
for url in "${STORAGE_CEPH_ASSETS[@]}"; do verify_file "$url" "images/storage-ceph/$(basename $url)" yes; done
for arch in "${CN_ARCH[@]}"; do
    for url in $(eval echo \${COMPUTE_${arch}_ASSETS[@]}); do verify_file "$url" "images/compute/$(basename $url)" yes; done
done

verify_file "$HPE_SIGNING_KEY" "hpe-signing-key.asc" yes