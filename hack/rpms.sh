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
            -v "$(realpath "${BUILDDIR}/security/"):/keys" \
            "${PACKAGING_TOOLS_IMAGE}" \
            rpm-sync ${REPO_CREDS_RPMSYNC_OPTIONS} -n 1 -s -v -k /keys/hpe-signing-key.asc -d /data /index.yaml
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

if [ "${VALIDATE}" != "1" ] && ! [ -f "${BUILDDIR}/security/hpe-signing-key.asc" ]; then
    echo "Downloading HPE signing key"
    mkdir -p "${BUILDDIR}/security"
    wget -q -O "${BUILDDIR}/security/hpe-signing-key.asc" "${HPE_SIGNING_KEY}"
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
    # Special processing for docs-csm, as we don't know exact version before build starts, so can't include it into rpm indexes.
    # Can't include docs-csm-latest either, because it is not unique. Get version from right docs-csm-latest, then download actual rpm file.
    DOCS_CSM_MAJOR_MINOR="${DOCS_CSM_MAJOR_MINOR:-${RELEASE_VERSION_MAJOR}.${RELEASE_VERSION_MINOR}}"
    DOCS_CSM_VERSION=$(acurl -sSL "https://artifactory.algol60.net/artifactory/api/storage/csm-rpms/hpe/stable/noos/docs-csm/${DOCS_CSM_MAJOR_MINOR}/noarch/docs-csm-latest.noarch.rpm?properties" | jq -r '.properties["rpm.metadata.version"][0]')
    mkdir -p "${BUILDDIR}/rpm/cray/csm/noos/noarch"
    acurl -sSL -o "${BUILDDIR}/rpm/cray/csm/noos/noarch/docs-csm-1.6.45-1.noarch.rpm" \
        "https://artifactory.algol60.net/artifactory/csm-rpms/hpe/stable/noos/docs-csm/1.6/noarch/docs-csm-1.6.45-1.noarch.rpm"
    rpm -qpi "${BUILDDIR}/rpm/cray/csm/noos/noarch/docs-csm-1.6.45-1.noarch.rpm" | grep -q -E "Signature\s*:\s*\(none\)" && (echo "ERROR: RPM package docs-csm-1.6.45-1.noarch.rpm is not signed"; exit 1)

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
