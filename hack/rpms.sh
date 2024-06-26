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
SIGNING_KEYS=""

function rpm-sync() {
    index="${1}"
    destdir="${2}"
    if [ "${VALIDATE}" == "1" ]; then
        docker run ${REPO_CREDS_DOCKER_OPTIONS} --rm -i -u "$(id -u):$(id -g)" \
            "${PACKAGING_TOOLS_IMAGE}" \
            rpm-sync ${REPO_CREDS_RPMSYNC_OPTIONS} -n 1 --dry-run -v - < "${index}"
    else
        mkdir -p "${destdir}"
        docker run ${REPO_CREDS_DOCKER_OPTIONS} --rm -i -u "$(id -u):$(id -g)" \
            -v "$(realpath "${index}"):/index.yaml:ro" \
            -v "$(realpath "${destdir}"):/data" \
            -v "$(realpath "${BUILDDIR}/security/keys/rpm/"):/keys" \
            "${PACKAGING_TOOLS_IMAGE}" \
            rpm-sync ${REPO_CREDS_RPMSYNC_OPTIONS} -n 1 -s -v ${SIGNING_KEYS} -d /data /index.yaml
    fi
}

function rpm-sync-with-csm-base() {
    path="${1}"
    if [ -n "${CSM_BASE_VERSION}" ]; then
        tmpdir=$(mktemp -d)
        trap 'rm -rf "${tmpdir}"' RETURN
        existing=$(cd "${ROOTDIR}/dist/csm-${CSM_BASE_VERSION}/${path}"; find . -name '*.rpm' | sort -u)
        cat "${ROOTDIR}/${path}/index.yaml" | yq e '.*.rpms.[] | ((path | (.[0])) + " " + .)' | sort -u | while read -r repo nevra; do
            relpath=$(echo "${existing}" | grep -F "/${nevra}.rpm" | head -1 || true)
            if [ -n "${relpath}" ]; then
                if [ "${VALIDATE}" == "1" ]; then
                    echo "[INFO] Will use ${nevra} from CSM base ${CSM_BASE_VERSION}"
                else
                    echo "[INFO] Reusing ${nevra} from CSM base ${CSM_BASE_VERSION}"
                    relpath="${relpath#./}"
                    mkdir -p "${BUILDDIR}/${path}/$(dirname "${relpath}")"
                    cp -f "${ROOTDIR}/dist/csm-${CSM_BASE_VERSION}/${path}/${relpath}" "${BUILDDIR}/${path}/${relpath}"
                fi
            else
                echo "[WARNING] Did not find ${nevra} in CSM base ${CSM_BASE_VERSION}, will download from external location"
                test -f "${tmpdir}/index.txt" && (echo " |" >> "${tmpdir}/index.txt")
                echo -ne ".[\"${repo}\"].rpms += [\"${nevra}\"]" >> "${tmpdir}/index.txt"
            fi
        done
        if [ -f "${tmpdir}/index.txt" ]; then
            yq -n --from-file "${tmpdir}/index.txt" > "${tmpdir}/index.yaml"
            rpm-sync "${tmpdir}/index.yaml" "${BUILDDIR}/${path}"
        fi
    else
        rpm-sync "${ROOTDIR}/${path}/index.yaml" "${BUILDDIR}/${path}"
    fi
}

function createrepo() {
    local repodir="$1"
    if [[ ! -d "$repodir" ]]; then
        echo >&2 "error: no such directory: ${repodir}"
        return 1
    fi
    docker run --rm -u "$(id -u):$(id -g)" \
        -v "$(realpath "$repodir"):/data" \
        "${RPM_TOOLS_IMAGE}" \
        createrepo --verbose /data
}

if [ "${VALIDATE}" != "1" ]; then
    # Download and store RPM signing keys.
    mkdir -p "${BUILDDIR}/security/keys/rpm"
    for key_url in "${HPE_RPM_SIGNING_KEYS[@]}"; do
        key=$(basename "${key_url}")
        if [ -f "${BUILDDIR}/security/keys/rpm/${key}" ]; then
            echo "Signing key ${key} is already downloaded"
        else
            echo "Downloading ${key} signing key"
            acurl -Ss -o "${BUILDDIR}/security/keys/rpm/${key}" "${key_url}"
        fi
        SIGNING_KEYS="${SIGNING_KEYS} -k /keys/${key}"
    done
fi

rpm-sync-with-csm-base "rpm/cray/csm/sle-15sp2"
rpm-sync-with-csm-base "rpm/cray/csm/sle-15sp3"
rpm-sync-with-csm-base "rpm/cray/csm/sle-15sp4"
rpm-sync-with-csm-base "rpm/cray/csm/sle-15sp5"
rpm-sync-with-csm-base "rpm/cray/csm/noos"

if [ "${VALIDATE}" == "1" ]; then
    echo "RPM indexes validated successfully"
else
    echo "RPM indexes synchronized successfully"
    # Fix-up cray directories by removing misc subdirectories
    {
        find "${BUILDDIR}/rpm/cray" -name '*-team' -type d
        find "${BUILDDIR}/rpm/cray" -name 'github' -type d
    } | while read path; do
        mv "$path"/* "$(dirname "$path")/"
        rmdir "$path"
    done

    # Remove empty directories
    find "${BUILDDIR}/rpm/cray" -empty -type d -delete

    # Create CSM repositories
    mkdir -p "${BUILDDIR}/rpm/cray/csm/sle-15sp2" && createrepo "${BUILDDIR}/rpm/cray/csm/sle-15sp2"
    mkdir -p "${BUILDDIR}/rpm/cray/csm/sle-15sp3" && createrepo "${BUILDDIR}/rpm/cray/csm/sle-15sp3"
    mkdir -p "${BUILDDIR}/rpm/cray/csm/sle-15sp4" && createrepo "${BUILDDIR}/rpm/cray/csm/sle-15sp4"
    mkdir -p "${BUILDDIR}/rpm/cray/csm/sle-15sp5" && createrepo "${BUILDDIR}/rpm/cray/csm/sle-15sp5"
    mkdir -p "${BUILDDIR}/rpm/cray/csm/noos" && createrepo "${BUILDDIR}/rpm/cray/csm/noos"
fi
