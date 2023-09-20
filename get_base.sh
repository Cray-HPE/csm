#!/usr/bin/env bash

set -e -o pipefail

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOTDIR}/common.sh"

if [ -n "${CSM_BASE_VERSION}" ]; then
    CSM_FOLDER=$(echo "${CSM_BASE_VERSION}" | cut -f1,2 -d .)
    mkdir -p "${ROOTDIR}/dist"
    echo "CSM_BASE_VERSION is set to ${CSM_BASE_VERSION}"
    if [ -d "${ROOTDIR}/dist/csm-${CSM_BASE_VERSION}" ]; then
        echo "dist/csm-${CSM_BASE_VERSION} is already present, reusing"
    else
        for filename in "csm-${CSM_BASE_VERSION}-images.txt" "csm-${CSM_BASE_VERSION}.tar.gz"; do
            if [ -f "${ROOTDIR}/dist/${filename}" ]; then
                echo "dist/${filename} is already downloaded, reusing"
            else
                echo "Downloading ${ROOTDIR}/dist/${filename} ..."
                wget -nv --http-user="${ARTIFACTORY_USER}" --http-password="${ARTIFACTORY_TOKEN}" -O "${ROOTDIR}/dist/${filename}" \
                    "https://artifactory.algol60.net/artifactory/csm-releases/csm/${CSM_FOLDER}/${filename}"
            fi
        done
        echo "Unpacking base CSM distribution ..."
        cd "${ROOTDIR}/dist"
        tar xfz "csm-${CSM_BASE_VERSION}.tar.gz"
        rm "csm-${CSM_BASE_VERSION}.tar.gz"
    fi
else
    echo "Environment variable CSM_BASE_VERSION is not set, will pull fresh artifacts."
fi
