#!/usr/bin/env bash

set -eo pipefail

ROOTDIR=$(realpath "${ROOTDIR:-$(dirname "${BASH_SOURCE[0]}")/..}")
source "${ROOTDIR}/assets.sh"
source "${ROOTDIR}/common.sh"

if [ $# -ne 1 ] || ([ "${1}" != "--validate" ] && [ "${1}" != "--download" ]); then
    echo "Usage: $0 [--validate|--download]"
    exit 1
fi

[ "${1}" == "--validate" ] && VALIDATE=1 || VALIDATE=0

function validate_url() {
    url="${1}"
    auth="${2}"
    echo -ne "Validating ${url} ... "
    curl -sfSL -X HEAD --ignore-content-length -w "http code %{response_code}\n" \
        ${auth:+-u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}"} "${url}"
}

function download_url() {
    url="${1}"
    path="${2}"
    auth="${3}"
    echo -ne "Downloading ${url} ... "
    mkdir -p "${BUILDDIR}/$(dirname "${path}")"
    wget -q -O "${BUILDDIR}/${path}" ${auth:+--http-user="${ARTIFACTORY_USER}" --http-password="${ARTIFACTORY_TOKEN}"} "${url}"
    echo "ok"
    if [ -n "${auth}" ]; then
        sha256=$(curl -sfSLR -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" "${url/\/artifactory\//\/artifactory\/api\/storage\/}" | jq -r '.checksums.sha256')
        echo "${sha256}" > "${BUILDDIR}/${path}.sha265.txt"
        if ! echo "${sha256} ${BUILDDIR}/${path}" | sha256sum -c --quiet -; then
            echo "SHA256 checksum for downloaded ${path} is incorrect, looks like file was corrupted in transit."
            exit 1
        fi
    fi
}

function process_file() {
    url="${1}"
    path="${2}"
    auth="${3}"
    if [ "${VALIDATE}" == "1" ]; then
        if [ -n "${CSM_BASE_VERSION}" ]; then
            if [ -f "${ROOTDIR}/dist/csm-${CSM_BASE_VERSION}/${path}" ]; then
                echo "Found ${path} in CSM base, skip validate"
            else
                echo "Not found ${path} in CSM base, validating ..."
                validate_url "${url}" "${auth}"
            fi
        else
            validate_url "${url}" "${auth}"
        fi
    else
        if [ -n "${CSM_BASE_VERSION}" ]; then
            if [ -f "${ROOTDIR}/dist/csm-${CSM_BASE_VERSION}/${path}" ]; then
                echo -ne "Found ${path} in CSM base, copying ... "
                mkdir -p "$(dirname "${BUILDDIR}/${path}")"
                cp -f "${ROOTDIR}/dist/csm-${CSM_BASE_VERSION}/${path}" "${BUILDDIR}/${path}"
                echo "ok"
            else
                echo "Not found ${path} in CSM base, will need to download."
                download_url "${url}" "${path}" "${auth}"
            fi
        else
            download_url "${url}" "${path}" "${auth}"
        fi
    fi
}

for url in "${PIT_ASSETS[@]}"; do
    process_file "${url}" "images/pre-install-toolkit/$(basename "${url}")" "yes"
done

for url in "${KUBERNETES_ASSETS[@]}"; do
   process_file "${url}" "images/kubernetes/$(basename "${url}")" "yes"
done

for url in "${STORAGE_CEPH_ASSETS[@]}"; do
    process_file "${url}" "images/storage-ceph/$(basename "${url}")" "yes"
done

for arch in "${CN_ARCH[@]}"; do
    for url in $(eval echo "\${COMPUTE_${arch}_ASSETS[@]}"); do
        process_file "${url}" "images/compute/$(basename "${url}")" "yes"
    done
done

