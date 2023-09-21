#!/usr/bin/env bash

# Copyright 2023 Hewlett Packard Enterprise Development LP

set -o errexit
set -o pipefail

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."
source "${ROOTDIR}/common.sh"

function rpm-validate-with-csm-base() {
    path="${1}"
    if [ -n "${CSM_BASE_VERSION}" ]; then
        tmpdir=$(mktemp -d)
        trap 'rm -rf "${tmpdir}"' RETURN
        existing=$(cd "${ROOTDIR}/dist/csm-${CSM_BASE_VERSION}/${path}"; find . -name '*.rpm' | sort -u)
        cat "${ROOTDIR}/${path}/index.yaml" | $YQ e '.*.rpms.[] | ((path | (.[0])) + " " + .)' | sort -u | while read -r repo nevra; do
            relpath=$(echo "${existing}" | grep -F "/${nevra}.rpm" | head -1 || true)
            if [ -n "${relpath}" ]; then
                echo "[INFO] Reusing ${nevra} from CSM base ${CSM_BASE_VERSION}"
            else
                echo "[WARNING] Did not find ${nevra} in CSM base ${CSM_BASE_VERSION}, will download from external location"
                test -f "${tmpdir}/index.txt" && (echo " |" >> "${tmpdir}/index.txt")
                echo -ne ".[\"${repo}\"].rpms += [\"${nevra}\"]" >> "${tmpdir}/index.txt"
            fi
        done
        if [ -f "${tmpdir}/index.txt" ]; then
            docker run --rm -i -u "$(id -u):$(id -g)" -v "${tmpdir}:/tmp/yq" "${YQ_IMAGE}" -n --from-file /tmp/yq/index.txt > "${tmpdir}/index.yaml"
            $RPM_SYNC -v -n 1 - < "${tmpdir}/index.yaml"
        fi
    else
        $RPM_SYNC -v -n 1 - < "${ROOTDIR}/${path}/index.yaml"
    fi
}

export RPM_SYNC_NUM_CONCURRENT_DOWNLOADS=1
rpm-validate-with-csm-base "rpm/cray/csm/sle-15sp2"
rpm-validate-with-csm-base "rpm/cray/csm/sle-15sp2-compute"
rpm-validate-with-csm-base "rpm/cray/csm/sle-15sp3"
rpm-validate-with-csm-base "rpm/cray/csm/sle-15sp3-compute"
rpm-validate-with-csm-base "rpm/cray/csm/sle-15sp4"
rpm-validate-with-csm-base "rpm/cray/csm/sle-15sp4-compute"
rpm-validate-with-csm-base "rpm/cray/csm/noos"
