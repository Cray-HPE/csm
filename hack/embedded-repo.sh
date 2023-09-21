#!/usr/bin/env bash
set -e -o pipefail

if ! ([ $# -eq 1 ] && [ "$1" == "--validate" ]) && [ $# -ne 2 ]; then
    echo "Manage RPM repo from PIT/NCN package lists (so called 'embedded repo')."
    echo "Lists of packages and repo configurations, installed onto NCN images, "
    echo "are expected to be published along with NCN image files as:"
    echo ""
    echo "    csm-images/stable/<ncn_type>/<ncn_version>/installed-<ncn_version>-<arch>.packages"
    echo "    csm-images/stable/<ncn_type>/<ncn_version>/installed.deps-<ncn_version>-<arch>.packages"
    echo "    csm-images/stable/<ncn_type>/<ncn_version>/installed-<ncn_version>-<arch>.repos"
    echo ""
    echo "With --validate, validate presence of all RPM packages in repositories."
    echo "Otherwise, download RPMs into <target_dir>, filtering out those which are alredy in <duplicates_dir>,"
    echo "and calculate RPM metadata."
    echo "Usage: $0 [--validate] | [<target_dir> <duplicates_dir>]"
    exit 1
fi

TMPDIR=$(mktemp -d)
trap "rm -fr '$TMPDIR'" EXIT

ROOTDIR=$(realpath "${ROOTDIR:-$(dirname "${BASH_SOURCE[0]}")/..}")
source "${ROOTDIR}/assets.sh"
source "${ROOTDIR}/common.sh"

echo "Downloading package lists ..."
for LIST_TYPE in installed installed.deps; do
    for LIST_URL in \
        "pre-install-toolkit/${PIT_IMAGE_ID}/${LIST_TYPE}-${PIT_IMAGE_ID}-${NCN_ARCH}.packages" \
        "kubernetes/${KUBERNETES_IMAGE_ID}/${LIST_TYPE}-${KUBERNETES_IMAGE_ID}-${NCN_ARCH}.packages" \
        "storage-ceph/${STORAGE_CEPH_IMAGE_ID}/${LIST_TYPE}-${STORAGE_CEPH_IMAGE_ID}-${NCN_ARCH}.packages"; do
            curl -Ss -f -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" "https://artifactory.algol60.net/artifactory/csm-images/stable/${LIST_URL}"
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
        curl -Ss -f -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" "https://artifactory.algol60.net/artifactory/csm-images/stable/${REPOS_URL}"
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

# Try repos for SLES 15 SP4 and SP5
(
    cat "${TMPDIR}/ncn.repo-list.releasever" \
        | sed -e "s/\${basearch}/${NCN_ARCH}/g" \
        | sed -e "s/\${releasever_major}/15/g" \
        | sed -e "s/\${releasever_minor}/4/g" \
        | sed -e "s/\${releasever}/15.4/g"
    cat "${TMPDIR}/ncn.repo-list.releasever" \
        | sed -e "s/\${basearch}/${NCN_ARCH}/g" \
        | sed -e "s/\${releasever_major}/15/g" \
        | sed -e "s/\${releasever_minor}/5/g" \
        | sed -e "s/\${releasever}/15.5/g"
) | sort -u > "${TMPDIR}/ncn.repo-list.unverified"

# Filter out non-existent repos and generate directory names for rpm-index input
echo -ne > "${TMPDIR}/ncn.repo-list"
cat "${TMPDIR}/ncn.repo-list.unverified" | while read url; do
    if curl -I -Ss -f -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" "$url/repodata/repomd.xml" >/dev/null 2>/dev/null; then
        dir="${url#https://}"
        dir="${dir#artifactory.algol60.net/artifactory/}"
        dir="${dir//-mirror/}"
        echo "$url" "$dir" >> "${TMPDIR}/ncn.repo-list"
    fi
done

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
    CSM_BASE_RPMS=""
    INPUT_FILE="${TMPDIR}/ncn.rpm-list"
fi

echo "Building RPM package index ..."
# Filtering out conntrack package, because it is not in our repos, and gets into NCN image from local mount during build
(cat "${INPUT_FILE}" \
    | grep -v conntrack-1-1 \
    | docker run -e REPOCREDSVAR --rm -i "${PACKAGING_TOOLS_IMAGE}" rpm-index -c REPOCREDSVAR -v \
    --input-format NEVR \
    --output-format DOWNLOAD_CSV \
    $(sed -e 's/^/-d /' "${TMPDIR}/ncn.repo-list") \
   -
)> "${TMPDIR}/embedded.url-list"

if [ "${1}" == "--validate" ]; then
    echo "All RPM packages were resolved successfully"
else
    TARGET_DIR=$(realpath "${1}")
    DUPLICATES_DIR=$(realpath "${2}")
    DUPLICATES=$(find "${DUPLICATES_DIR}" -name '*.rpm' -not -wholename "${TARGET_DIR}/*" -exec basename '{}' ';')
    cat "${TMPDIR}/embedded.url-list" | while IFS="," read -r dir url; do
        file=$(basename "${url}")
        if echo "${DUPLICATES}" | grep -q -x -F "${file}"; then
            echo "    Skipping ${file} - already present in ${2}"
        else
            echo "    Downloading ${url} ..."
            mkdir -p "${TARGET_DIR}/${dir}"
            curl -Ss -f -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" -o "${TARGET_DIR}/${dir}/${file}" "${url}"
        fi
    done
    if [ -n "${CSM_BASE_VERSION}" ]; then
        cat "${TMPDIR}/ncn.file-list.csm-base" | while read -r file; do
            echo "    Reusing ${file} from CSM base ${CSM_BASE_VERSION}"
            mkdir -p "${TARGET_DIR}/$(dirname "${file}")"
            cp "${ROOTDIR}/dist/csm-${CSM_BASE_VERSION}/rpm/embedded/${file}" "${TARGET_DIR}/${file}"
        done
    fi

    # Create repository for node image RPMs
    docker run --rm -u "$(id -u):$(id -g)" -v "${TARGET_DIR}:/data" "${RPM_TOOLS_IMAGE}" createrepo --verbose /data
fi
