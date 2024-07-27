#!/usr/bin/env bash
set -e -o pipefail

ROOTDIR=$(realpath "${ROOTDIR:-$(dirname "${BASH_SOURCE[0]}")/..}")
source "${ROOTDIR}/assets.sh"
source "${ROOTDIR}/common.sh"

if [ $# -ne 1 ] || ([ "${1}" != "--validate" ] && [ "${1}" != "--download" ]); then
    echo "Usage: $0 [--validate|--download]"
    echo ""
    echo "Manage RPM repo from PIT/NCN package lists (so called 'embedded repo')."
    echo "Lists of packages and repo configurations, installed onto NCN images, "
    echo "are expected to be published along with NCN image files as:"
    echo ""
    echo "    csm-images/unstable/<ncn_type>/<ncn_version>/installed-<ncn_version>-<arch>.packages"
    echo "    csm-images/unstable/<ncn_type>/<ncn_version>/installed.deps-<ncn_version>-<arch>.packages"
    echo "    csm-images/unstable/<ncn_type>/<ncn_version>/installed-<ncn_version>-<arch>.repos"
    echo ""
    echo "With --validate, validate presence of all RPM packages in repositories."
    echo "With --download, download RPMs into ${BUILDDIR}/rpm/embedded, filtering out those which are alredy in ${BUILDDIR}/rpm,"
    echo "and calculate RPM metadata."
    exit 1
fi

[ "${1}" == "--validate" ] && VALIDATE=1 || VALIDATE=0
TARGET_DIR="${BUILDDIR}/rpm/embedded"
DUPLICATES_DIR="${BUILDDIR}/rpm"
TMPDIR=$(mktemp -d)
trap "rm -fr '$TMPDIR'" EXIT

echo "Downloading package lists ..."
for LIST_TYPE in installed installed.deps; do
    for LIST_URL in \
        "pre-install-toolkit/${PIT_IMAGE_ID}/${LIST_TYPE}-${PIT_IMAGE_ID}-${NCN_ARCH}.packages" \
        "kubernetes/${KUBERNETES_IMAGE_ID}/${LIST_TYPE}-${KUBERNETES_IMAGE_ID}-${NCN_ARCH}.packages" \
        "storage-ceph/${STORAGE_CEPH_IMAGE_ID}/${LIST_TYPE}-${STORAGE_CEPH_IMAGE_ID}-${NCN_ARCH}.packages"; do
            curl -Ss -f -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" "https://artifactory.algol60.net/artifactory/csm-images/unstable/${LIST_URL}"
    done
done | tr '=' '-' | sort -u > "${TMPDIR}/ncn.rpm-list"

# Explicitly append kernel-default, kernel-default-debuginfo, and kernel-source packages to rpm list
if [ -n "$KERNEL_DEFAULT_DEBUGINFO_VERSION" ]; then
    echo "kernel-default-${KERNEL_DEFAULT_DEBUGINFO_VERSION}" >> "${TMPDIR}/ncn.rpm-list"
    echo "kernel-default-debuginfo-${KERNEL_DEFAULT_DEBUGINFO_VERSION}" >> "${TMPDIR}/ncn.rpm-list"
    echo "kernel-source-${KERNEL_DEFAULT_DEBUGINFO_VERSION}" >> "${TMPDIR}/ncn.rpm-list"
fi

echo "List of packages for embedded repo:"
cat "${TMPDIR}/ncn.rpm-list" | sed 's/^/    /'

echo "Downloading and testing repo configs ..."
for REPOS_URL in \
    "pre-install-toolkit/${PIT_IMAGE_ID}/installed-${PIT_IMAGE_ID}-${NCN_ARCH}.repos" \
    "kubernetes/${KUBERNETES_IMAGE_ID}/installed-${KUBERNETES_IMAGE_ID}-${NCN_ARCH}.repos" \
    "storage-ceph/${STORAGE_CEPH_IMAGE_ID}/installed-${STORAGE_CEPH_IMAGE_ID}-${NCN_ARCH}.repos"; do
        curl -Ss -f -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" "https://artifactory.algol60.net/artifactory/csm-images/unstable/${REPOS_URL}"
done | grep -E '^baseurl=https://' \
     | sed -e 's/^baseurl=//' \
     | sed -e 's|https://[^@]*@|https://|' \
     | sed -e 's/\?auth=basic$//' \
     | sed -e 's/\/$//' \
     | sort -u > "${TMPDIR}/ncn.repo-list.releasever"

# Append update_debug repos, where kernel-default-debuginfo package is provided
if [ -n "$KERNEL_DEFAULT_DEBUGINFO_VERSION" ]; then
    echo 'https://artifactory.algol60.net/artifactory/sles-mirror/Updates/SLE-Module-Basesystem/${releasever_major}-SP${releasever_minor}/${basearch}/update_debug' >> "${TMPDIR}/ncn.repo-list.releasever"
fi

# Try repos for SLES 15 SP5 and SP6
# Filter out openSUSE:Backports repos - we have these packages in SLES RMT and should prefer that
(
    cat "${TMPDIR}/ncn.repo-list.releasever" \
        | sed -e "s/\${basearch}/${NCN_ARCH}/g" \
        | sed -e "s/\${releasever_major}/15/g" \
        | sed -e "s/\${releasever_minor}/5/g" \
        | sed -e "s/\${releasever}/15.5/g"
    cat "${TMPDIR}/ncn.repo-list.releasever" \
        | sed -e "s/\${basearch}/${NCN_ARCH}/g" \
        | sed -e "s/\${releasever_major}/15/g" \
        | sed -e "s/\${releasever_minor}/6/g" \
        | sed -e "s/\${releasever}/15.6/g"
) \
    | grep -v openSUSE:Backports \
    | sort -u > "${TMPDIR}/ncn.repo-list.unverified"

# Filter out non-existent repos and generate directory names for rpm-index input
echo -ne > "${TMPDIR}/ncn.repo-list"
while read -r url; do
    if acurl -I -Ss -f "$url/repodata/repomd.xml" >/dev/null 2>/dev/null; then
        dir="${url#https://}"
        dir="${dir#artifactory.algol60.net/artifactory/}"
        dir="${dir//-mirror/}"
        echo "$url" "$dir" >> "${TMPDIR}/ncn.repo-list"
    fi
done < "${TMPDIR}/ncn.repo-list.unverified"

echo "List of repositories for embedded repo:"
cat "${TMPDIR}/ncn.repo-list" | sed 's/^/    /'

if [ -n "${CSM_BASE_VERSION}" ]; then
    echo "Detected CSM base version ${CSM_BASE_VERSION}, will re-use RPMs:"
    CSM_BASE_RPMS=$(cd "${ROOTDIR}/dist/csm-${CSM_BASE_VERSION}/rpm/embedded"; find . -name '*.rpm' | sed -e 's|^\./||' | sort -u)
    echo -ne > "${TMPDIR}/ncn.file-list.csm-base"
    echo -ne > "${TMPDIR}/ncn.rpm-list.csm-base"
    cat "${TMPDIR}/ncn.rpm-list" | while read -r nevr; do
        file=$(echo "${CSM_BASE_RPMS}" | grep -F "/${nevr}." | head -1 || true)
        if [ -n "${file}" ]; then
            echo "    Reusing ${nevr} from CSM base ${CSM_BASE_VERSION}"
            echo "${file}" >> "${TMPDIR}/ncn.file-list.csm-base"
        else
            echo "    Did not find ${nevr} in CSM base ${CSM_BASE_VERSION}, will download from external location"
            echo "${nevr}" >> "${TMPDIR}/ncn.rpm-list.csm-base"
        fi
    done
    echo "Total to be downloaded: $(cat "${TMPDIR}/ncn.rpm-list.csm-base" | wc -l)"
    echo "Total to be reused: $(cat "${TMPDIR}/ncn.file-list.csm-base" | wc -l)"
    INPUT_FILE="${TMPDIR}/ncn.rpm-list.csm-base"
else
    INPUT_FILE="${TMPDIR}/ncn.rpm-list"
fi

echo "Building RPM package index ..."
# Filtering out conntrack package, because it is not in our repos, and gets into NCN image from local mount during build
(cat "${INPUT_FILE}" \
    | grep -v conntrack-1-1 \
    | docker run -e REPOCREDSVAR --rm -i "${PACKAGING_TOOLS_IMAGE}" rpm-index -c REPOCREDSVAR -v \
    --input-format NEVR \
    $(sed -e 's/^/-d /' "${TMPDIR}/ncn.repo-list") \
   -
)> "${TMPDIR}/embedded.yaml"

if [ "${VALIDATE}" == "1" ]; then
    echo "All RPM packages were resolved successfully"
else
    # Download and store RPM signing keys (if not yet downloaded by rpm.sh)
    SIGNING_KEYS=""
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

    echo "Downloading RPM packages into ${TARGET_DIR} ..."
    mkdir -p "${TARGET_DIR}"
    docker run ${REPO_CREDS_DOCKER_OPTIONS} --rm -i -u "$(id -u):$(id -g)" \
            -v "$(realpath "${TMPDIR}/embedded.yaml"):/index.yaml:ro" \
            -v "$(realpath "${TARGET_DIR}"):/data" \
            -v "$(realpath "${BUILDDIR}/security/keys/rpm/"):/keys" \
            "${PACKAGING_TOOLS_IMAGE}" \
            rpm-sync ${REPO_CREDS_RPMSYNC_OPTIONS} -n 1 -s -v ${SIGNING_KEYS} -d /data /index.yaml

    # Copy packages from CSM_BASE which did not change
    if [ -n "${CSM_BASE_VERSION}" ]; then
        cat "${TMPDIR}/ncn.file-list.csm-base" | while read -r file; do
            echo "Reusing ${file} from CSM base ${CSM_BASE_VERSION}"
            mkdir -p "${TARGET_DIR}/$(dirname "${file}")"
            cp "${ROOTDIR}/dist/csm-${CSM_BASE_VERSION}/rpm/embedded/${file}" "${TARGET_DIR}/${file}"
        done
    fi

    # Remove possible duplicates in "${BUILDDIR}/rpm/cray" and "${BUILDDIR}/rpm/embedded"
    DUPLICATES=$(test -d "${DUPLICATES_DIR}" && find "${DUPLICATES_DIR}" -name '*.rpm' -not -wholename "${TARGET_DIR}/*" -exec basename '{}' ';')
    find "${TARGET_DIR}" -name '*.rpm' -type f | while read -r filename; do
        file=$(basename "${filename}")
        if echo "${DUPLICATES}" | grep -q -x -F "${file}"; then
            echo "Removing ${file} - already present in ${DUPLICATES_DIR}"
            rm "${filename}"
        fi
    done

    # Create repository for node image RPMs
    docker run --rm -u "$(id -u):$(id -g)" -v "${TARGET_DIR}:/data" "${RPM_TOOLS_IMAGE}" createrepo --verbose /data
fi
