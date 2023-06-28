#!/usr/bin/env bash
set -e -o pipefail

if [ $# -ne 1 ]; then
    echo "Manage RPM repo from PIT/NCN package lists (so called 'embedded repo')."
    echo "Lists of packages and repo configurations, installed onto NCN images, "
    echo "are expected to be published along with NCN image files as:"
    echo ""
    echo "    csm-images/stable/<ncn_type>/<ncn_version>/installed-<ncn_version>-<arch>.packages"
    echo "    csm-images/stable/<ncn_type>/<ncn_version>/installed.deps-<ncn_version>-<arch>.packages"
    echo "    csm-images/stable/<ncn_type>/<ncn_version>/installed-<ncn_version>-<arch>.repos"
    echo ""
    echo "With --validate, only validate presence of all RPM packages in repositories."
    echo "Otherwise, download RPMs into <target_dir> and calculate RPM metadata."
    echo "Usage: $0 [<target_dir>|--validate]"
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
            curl -Ss -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" "https://artifactory.algol60.net/artifactory/csm-images/stable/${LIST_URL}"
    done
done | tr '=' '-' | sort -u > "${TMPDIR}/ncn.rpm-list"

# append kernel-default-debuginfo package to rpm list
if [ -n "$KERNEL_DEFAULT_DEBUGINFO_VERSION" ]; then
    echo "kernel-default-debuginfo-${KERNEL_DEFAULT_DEBUGINFO_VERSION}" >> "${TMPDIR}/ncn.rpm-list"
fi

echo "List of packages for embedded repo:"
cat "${TMPDIR}/ncn.rpm-list" | sed 's/^/    /'

echo "Downloading repo configs ..."
for REPOS_URL in \
    "pre-install-toolkit/${PIT_IMAGE_ID}/installed-${PIT_IMAGE_ID}-${NCN_ARCH}.repos" \
    "kubernetes/${KUBERNETES_IMAGE_ID}/installed-${KUBERNETES_IMAGE_ID}-${NCN_ARCH}.repos" \
    "storage-ceph/${STORAGE_CEPH_IMAGE_ID}/installed-${STORAGE_CEPH_IMAGE_ID}-${NCN_ARCH}.repos"; do
        curl -Ss -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" "https://artifactory.algol60.net/artifactory/csm-images/stable/${REPOS_URL}"
done | grep -E '^baseurl=https://' \
     | sed -e 's/^baseurl=//' \
     | sed -e 's|https://[^@]*@|https://|' \
     | sed -e 's/\?auth=basic$//' \
     | sort -u > "${TMPDIR}/ncn.repo-list.releasever"

# Append update_debug repos, where kernel-default-debuginfo package is provided
if [ -n "$KERNEL_DEFAULT_DEBUGINFO_VERSION" ]; then
    echo 'https://artifactory.algol60.net/artifactory/sles-mirror/Updates/SLE-Module-Legacy/${releasever_major}-SP${releasever_minor}/${basearch}/update_debug' >> "${TMPDIR}/ncn.repo-list.releasever"
fi

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
export REPOCREDSVAR=$(jq --null-input --arg url "https://artifactory.algol60.net/artifactory/" --arg realm "Artifactory Realm" --arg user "$ARTIFACTORY_USER" --arg password "$ARTIFACTORY_TOKEN" '{($url): {"realm": $realm, "user": $user, "password": $password}}')
# Filtering out conntrack package, because it is not in our repos, and gets into NCN image from local mount during build
(cat "${TMPDIR}/ncn.rpm-list" \
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
    cat "${TMPDIR}/embedded.url-list" | while IFS="," read -r dir url; do
        echo "Downloading ${url} ..."
        file=$(basename "${url}")
        mkdir -p "${TARGET_DIR}/${dir}"
        curl -Ss -f -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" -o "${TARGET_DIR}/${dir}/${file}" "${url}"
    done
    # Create repository for node image RPMs
    createrepo "${TARGET_DIR}"
fi
