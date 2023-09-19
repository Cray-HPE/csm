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
source "${ROOTDIR}/vendor/github.hpe.com/hpe/hpc-shastarelm-release/lib/release.sh"

if [ -z "${ARTIFACTORY_USER}" ] || [ -z "${ARTIFACTORY_TOKEN}" ]; then
    echo "Missing authentication information for image download. Please set ARTIFACTORY_USER and ARTIFACTORY_TOKEN environment variables."
    exit 1
fi

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

echo "Downloading repo configs ..."
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
     | sed -e 's/15-SP4/\${releasever_major}-SP\${releasever_minor}/' \
     | sort -u > "${TMPDIR}/ncn.repo-list.releasever"

# Append update_debug repos, where kernel-default-debuginfo package is provided
if [ -n "$KERNEL_DEFAULT_DEBUGINFO_VERSION" ]; then
    # Specific kernel version for release/1.4
    echo 'https://artifactory.algol60.net/artifactory/suse-external/PTF.1204911/15-SP4/x86_64/' >> "${TMPDIR}/ncn.repo-list.releasever"
fi

# Manual repo list adjustments for release/1.4
# cray-auth-utils-0.2.2-2.3_20220329153245__g3a392f2
# cray-heartbeat-1.6.0-2.3_3.2__gb2e7d63.shasta
# cray-power-button-1.3.1-2.3_20220329162359__g0ddf9af
# spire-agent-0.12.2-2.3_20220420125806__gf6cdaa8
echo 'https://artifactory.algol60.net/artifactory/dst-rpm-mirror/cos-rpm-stable-local/release/cos-2.3/sle15_sp3_ncn/' >> "${TMPDIR}/ncn.repo-list.releasever"
# mft-4.20.0-34
echo 'https://artifactory.algol60.net/artifactory/dst-rpm-mirror/slingshot-host-software-rpm-stable-local/release/slingshot-2.0/csm_1_4_sle15_sp4_ncn/' >> "${TMPDIR}/ncn.repo-list.releasever"
# python3-requests-2.24.0-6.10.2.noarch.rpm
echo 'https://artifactory.algol60.net/artifactory/sles-mirror/Updates/SLE-Module-Basesystem/15-SP2/x86_64/update' >> "${TMPDIR}/ncn.repo-list.releasever"
# python3-colorama-0.4.4-5.4.1.noarch.rpm
echo 'https://artifactory.algol60.net/artifactory/sles-mirror/Updates/SLE-Module-Public-Cloud/15-SP2/x86_64/update' >> "${TMPDIR}/ncn.repo-list.releasever"

# Try repos for SLES 15 SP3 and SP4
(
    cat "${TMPDIR}/ncn.repo-list.releasever" \
        | sed -e "s/\${basearch}/${NCN_ARCH}/g" \
        | sed -e "s/\${releasever_major}/15/g" \
        | sed -e "s/\${releasever_minor}/4/g" \
        | sed -e "s/\${releasever}/15.4/g"
    cat "${TMPDIR}/ncn.repo-list.releasever" \
        | sed -e "s/\${basearch}/${NCN_ARCH}/g" \
        | sed -e "s/\${releasever_major}/15/g" \
        | sed -e "s/\${releasever_minor}/3/g" \
        | sed -e "s/\${releasever}/15.3/g"
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

echo "Building RPM package index ..."
# In validate mode, also produce YAML file, which can be used by setup-nexus.sh script
if [ "${1}" == "--validate" ]; then
    mkdir -p "${ROOTDIR}/rpm/embedded"
    OUTPUT_FILE="${ROOTDIR}/rpm/embedded/index.yaml"
    OUTPUT_FORMAT="YAML"
else
    OUTPUT_FILE="${TMPDIR}/embedded.url-list"
    OUTPUT_FORMAT="DOWNLOAD_CSV"
fi
export REPOCREDSVAR=$(jq --null-input --arg url "https://artifactory.algol60.net/artifactory/" --arg realm "Artifactory Realm" --arg user "$ARTIFACTORY_USER" --arg password "$ARTIFACTORY_TOKEN" '{($url): {"realm": $realm, "user": $user, "password": $password}}')
# Filtering out conntrack package, because it is not in our repos, and gets into NCN image from local mount during build
# Specific for release/1.4 - filtering out hpe-csm-goss-package-0.3.13, as we already have 0.3.21 in rpms/
(cat "${TMPDIR}/ncn.rpm-list" \
    | grep -v conntrack-1-1 \
    | grep -v ses-release \
    | grep -v hpe-csm-goss-package \
    | docker run -e REPOCREDSVAR --rm -i "${PACKAGING_TOOLS_IMAGE}" rpm-index -c REPOCREDSVAR -v \
    --input-format NEVR \
    --output-format "${OUTPUT_FORMAT}" \
    $(sed -e 's/^/-d /' "${TMPDIR}/ncn.repo-list") \
   -
)> "${OUTPUT_FILE}"

if [ "${1}" == "--validate" ]; then
    echo "All RPM packages were resolved successfully"
else
    TARGET_DIR=$(realpath "${1}")
    DUPLICATES_DIR=$(realpath "${2}")
    DUPLICATES=$(find "${DUPLICATES_DIR}" -name '*.rpm' -not -wholename "${TARGET_DIR}/*" -exec basename '{}' ';')
    cat "${OUTPUT_FILE}" | while IFS="," read -r dir url; do
        file=$(basename "${url}")
        if echo "${DUPLICATES}" | grep -q -x -F "${file}"; then
            echo "Skipping ${file} - already present in ${2}"
        else
            echo "Downloading ${url} ..."
            mkdir -p "${TARGET_DIR}/${dir}"
            curl -Ss -f -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" -o "${TARGET_DIR}/${dir}/${file}" "${url}"
        fi
    done
    # Create repository for node image RPMs
    createrepo "${TARGET_DIR}"
fi
