#!/usr/bin/env bash

set -e -o pipefail

if [ -z "${ARTIFACTORY_USER}" ] || [ -z "${ARTIFACTORY_TOKEN}" ]; then
    echo "Missing authentication information for image download. Please set ARTIFACTORY_USER and ARTIFACTORY_TOKEN environment variables."
    exit 1
fi

if [ -n "${CSM_BASE_VERSION}" ]; then
    CSM_FOLDER=$(echo "${CSM_BASE_VERSION}" | cut -f1,2 -d .)
    ROOT_DIR=$(dirname $(realpath "${0}"))
    mkdir -p "${ROOT_DIR}/dist"
    echo "CSM_BASE_VERSION is set to ${CSM_BASE_VERSION}"
    if [ -d "${ROOT_DIR}/dist/csm-${CSM_BASE_VERSION}" ]; then
        echo "dist/csm-${CSM_BASE_VERSION} is already present, reusing"
    else
        for filename in "csm-${CSM_BASE_VERSION}-images.txt" "csm-${CSM_BASE_VERSION}.tar.gz"; do
            if [ -f "${ROOT_DIR}/dist/${filename}" ]; then
                echo "dist/${filename} is already downloaded, reusing"
            else
                echo "Downloading ${ROOT_DIR}/dist/${filename} ..."
                wget -nv --http-user="${ARTIFACTORY_USER}" --http-password="${ARTIFACTORY_TOKEN}" -O "${ROOT_DIR}/dist/${filename}" \
                    "https://artifactory.algol60.net/artifactory/csm-releases/csm/${CSM_FOLDER}/${filename}"
            fi
        done
        echo "Unpacking base CSM distribution ..."
        cd "${ROOT_DIR}/dist"
        tar xfz "csm-${CSM_BASE_VERSION}.tar.gz"
        rm "csm-${CSM_BASE_VERSION}.tar.gz"
    fi
else
    echo "Environment variable CSM_BASE_VERSION is not set, will pull fresh artifacts."
fi
