#!/usr/bin/env bash

# Copyright 2020 Hewlett Packard Enterprise Development LP

set -o errexit
set -o pipefail
set -o xtrace

: "${RELEASE:="${RELEASE_NAME:="csm"}-${RELEASE_VERSION:="0.0.0"}"}"

# import release utilities
ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOTDIR}/vendor/stash.us.cray.com/scm/shastarelm/release/lib/release.sh"

requires curl git perl rsync sed

# Valid SemVer regex, see https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string
semver_regex='^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$'

# Release version must be a valid semver
if [[ -z "$(echo "$RELEASE_VERSION" | perl -ne "print if /$semver_regex/")" ]]; then
    echo >&2 "error: invalid RELEASE_VERSION: ${RELEASE_VERSION}"
    exit
fi

# Parse components of version
RELEASE_VERSION_MAJOR="$(echo "$RELEASE_VERSION" | perl -pe "s/${semver_regex}/\1/")"
RELEASE_VERSION_MINOR="$(echo "$RELEASE_VERSION" | perl -pe "s/${semver_regex}/\2/")"
RELEASE_VERSION_PATCH="$(echo "$RELEASE_VERSION" | perl -pe "s/${semver_regex}/\3/")"
RELEASE_VERSION_PRERELEASE="$(echo "$RELEASE_VERSION" | perl -pe "s/${semver_regex}/\4/")"
RELEASE_VERSION_BUILDMETADATA="$(echo "$RELEASE_VERSION" | perl -pe "s/${semver_regex}/\5/")"

# Generate and verify the helm index
"${ROOTDIR}/hack/gen-helm-index.sh"
"${ROOTDIR}/hack/verify-helm-index.sh"

# Load and verify assets
source "${ROOTDIR}/assets.sh"

# Pull release tools
docker pull "$PACKAGING_TOOLS_IMAGE"
docker pull "$RPM_TOOLS_IMAGE"
docker pull "$SKOPEO_IMAGE"
docker pull "$CRAY_NEXUS_SETUP_IMAGE"

BUILDDIR="${1:-"$(realpath -m "$ROOTDIR/dist/${RELEASE}")"}"

# initialize build directory
[[ -d "$BUILDDIR" ]] && rm -fr "$BUILDDIR"
mkdir -p "$BUILDDIR"

# Process local files
rsync -aq "${ROOTDIR}/docs/README" "${BUILDDIR}/"
rsync -aq "${ROOTDIR}/docs/INSTALL" "${BUILDDIR}/"
rsync -aq "${ROOTDIR}/CHANGELOG.md" "${BUILDDIR}/"

# copy install scripts
rsync -aq "${ROOTDIR}/lib/" "${BUILDDIR}/lib/"
gen-version-sh "$RELEASE_NAME" "$RELEASE_VERSION" >"${BUILDDIR}/lib/version.sh"
chmod +x "${BUILDDIR}/lib/version.sh"
rsync -aq "${ROOTDIR}/vendor/stash.us.cray.com/scm/shastarelm/release/lib/install.sh" "${BUILDDIR}/lib/install.sh"
rsync -aq "${ROOTDIR}/install.sh" "${BUILDDIR}/"
#rsync -aq "${ROOTDIR}/uninstall.sh" "${BUILDDIR}/"
rsync -aq "${ROOTDIR}/upgrade.sh" "${BUILDDIR}/"
rsync -aq "${ROOTDIR}/hack/load-container-image.sh" "${BUILDDIR}/hack/"

# copy manifests
rsync -aq "${ROOTDIR}/manifests/" "${BUILDDIR}/manifests/"

# Embed the CSM release version into the csm-config and cray-csm-barebones-recipe-install charts
shopt -s expand_aliases
alias yq="${ROOTDIR}/vendor/stash.us.cray.com/scm/shasta-cfg/stable/utils/bin/$(uname | awk '{print tolower($0)}')/yq"
yq write -i ${BUILDDIR}/manifests/sysmgmt.yaml 'spec.charts.(name==csm-config).values.cray-import-config.import_job.CF_IMPORT_PRODUCT_NAME' "$RELEASE_NAME"
yq write -i ${BUILDDIR}/manifests/sysmgmt.yaml 'spec.charts.(name==csm-config).values.cray-import-config.import_job.CF_IMPORT_PRODUCT_VERSION' "$RELEASE_VERSION"
yq write -i ${BUILDDIR}/manifests/sysmgmt.yaml 'spec.charts.(name==csm-config).values.cray-import-config.import_job.CF_IMPORT_GITEA_REPO' "${RELEASE_NAME}-config-management"
yq write -i ${BUILDDIR}/manifests/sysmgmt.yaml 'spec.charts.(name==cray-csm-barebones-recipe-install).values.cray-import-kiwi-recipe-image.import_job.PRODUCT_VERSION' "${RELEASE_VERSION}"
yq write -i ${BUILDDIR}/manifests/sysmgmt.yaml 'spec.charts.(name==cray-csm-barebones-recipe-install).values.cray-import-kiwi-recipe-image.import_job.PRODUCT_NAME' "${RELEASE_NAME}"
yq write -i ${BUILDDIR}/manifests/sysmgmt.yaml 'spec.charts.(name==cray-csm-barebones-recipe-install).values.cray-import-kiwi-recipe-image.import_job.name' "${RELEASE_NAME}-image-recipe-import-${RELEASE_VERSION}"

# generate Nexus blob store configuration
generate-nexus-config blobstore <"${ROOTDIR}/nexus-blobstores.yaml" >"${BUILDDIR}/nexus-blobstores.yaml"

# generate Nexus repositories configuration
# update repository names based on the release version
sed -e "s/-0.0.0/-${RELEASE_VERSION}/g" "${ROOTDIR}/nexus-repositories.yaml" \
    | generate-nexus-config repository >"${BUILDDIR}/nexus-repositories.yaml"

# sync shasta-cfg
mkdir "${BUILDDIR}/shasta-cfg"
"${ROOTDIR}/vendor/stash.us.cray.com/scm/shasta-cfg/stable/package/make-dist.sh" "${BUILDDIR}/shasta-cfg"

export HELM_SYNC_NUM_CONCURRENT_DOWNLOADS=32
export RPM_SYNC_NUM_CONCURRENT_DOWNLOADS=32

# sync helm charts
helm-sync "${ROOTDIR}/helm/index.yaml" "${BUILDDIR}/helm"

# Sync container images
skopeo-sync "${ROOTDIR}/docker/index.yaml" "${BUILDDIR}/docker"
# Transform images to 1.4 dtr.dev.cray.com structure
${ROOTDIR}/docker/transform.sh "${BUILDDIR}/docker"
# Remove empty directories
find "${BUILDDIR}/docker" -empty -type d -delete

# Sync RPM manifests
rpm-sync "${ROOTDIR}/rpm/cray/csm/sle-15sp2/index.yaml" "${BUILDDIR}/rpm/cray/csm/sle-15sp2"
rpm-sync "${ROOTDIR}/rpm/cray/csm/sle-15sp2-compute/index.yaml" "${BUILDDIR}/rpm/cray/csm/sle-15sp2-compute"

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
createrepo "${BUILDDIR}/rpm/cray/csm/sle-15sp2"
createrepo "${BUILDDIR}/rpm/cray/csm/sle-15sp2-compute"

# Extract docs RPM into release
mkdir -p "${BUILDDIR}/tmp/docs"
(
    cd "${BUILDDIR}/tmp/docs"
    rpm2cpio "${BUILDDIR}"/rpm/cray/csm/sle-15sp2/noarch/docs-csm-install-*.rpm | cpio -idvm ./usr/share/doc/csm/*
)
mv "${BUILDDIR}/tmp/docs/usr/share/doc/csm" "${BUILDDIR}/docs"

# Extract wars RPM into release
mkdir -p "${BUILDDIR}/tmp/wars"
(
    cd "${BUILDDIR}/tmp/wars"
    rpm2cpio "${BUILDDIR}"/rpm/cray/csm/sle-15sp2/noarch/csm-install-workarounds-*.rpm | cpio -idmv ./opt/cray/csm/workarounds/*
    find . -type f -name '.keep' -delete
)
mv "${BUILDDIR}/tmp/wars/opt/cray/csm/workarounds" "${BUILDDIR}/workarounds"

# clean up temp space
rm -fr "${BUILDDIR}/tmp"

# Create shasta-firwmware repository
rpm-sync "${ROOTDIR}/rpm/shasta-firmware/index.yaml" "${BUILDDIR}/rpm/shasta-firmware"

# Fix-up firmware directories by removing misc subdirectories
find "${BUILDDIR}/rpm/shasta-firmware" -name '*-team' -type d | while read path; do
    mv "$path"/* "$(dirname "$path")/"
    rmdir "$path"
done

# Remove empty directories
find "${BUILDDIR}/rpm/shasta-firmware" -empty -type d -delete

createrepo "${BUILDDIR}/rpm/shasta-firmware"

# Download pre-install toolkit
# NOTE: This value is printed in #livecd-ci-alerts (slack) when a build STARTS.
(
    cd "${BUILDDIR}"
    for url in "${PIT_ASSETS[@]}"; do curl -sfSLOR "$url"; done
)

# Generate list of installed RPMs; see
# https://github.com/OSInside/kiwi/blob/master/kiwi/system/setup.py#L1067
# for how the .packages file is generated.
[[ -d "${ROOTDIR}/rpm" ]] || mkdir -p "${ROOTDIR}/rpm"
cat "${BUILDDIR}"/cray-pre-install-toolkit-*.packages \
| cut -d '|' -f 1-5 \
| sed -e 's/(none)//' \
| sed -e 's/\(.*\)|\([^|]\+\)$/\1.\2/g' \
| sed -e 's/|\+/-/g' \
> "${ROOTDIR}/rpm/pit.rpm-list"

# Download Kubernetes assets
(
    mkdir -p "${BUILDDIR}/images/kubernetes"
    cd "${BUILDDIR}/images/kubernetes"
    for url in "${KUBERNETES_ASSETS[@]}"; do curl -sfSLOR "$url"; done
)

# Download storage Ceph assets
(
    mkdir -p "${BUILDDIR}/images/storage-ceph"
    cd "${BUILDDIR}/images/storage-ceph"
    for url in "${STORAGE_CEPH_ASSETS[@]}"; do curl -sfSLOR "$url"; done
)

if [[ "${EMBEDDED_REPO_ENABLED:-yes}" = "yes" ]]; then
    # Generate node images RPM index
    [[ -d "${ROOTDIR}/rpm" ]] || mkdir -p "${ROOTDIR}/rpm"
    "${ROOTDIR}/hack/list-squashfs-rpms.sh" \
        "${BUILDDIR}"/images/kubernetes/kubernetes-*.squashfs \
        "${BUILDDIR}"/images/storage-ceph/storage-ceph-*.squashfs \
    | grep -v conntrack-1.1.x86_64 \
    > "${ROOTDIR}/rpm/images.rpm-list"

    cat >> "${ROOTDIR}/rpm/images.rpm-list" <<EOF
kernel-default-debuginfo-5.3.18-24.49.2.x86_64
EOF

    # Generate RPM index from pit and node images
    cat "${ROOTDIR}/rpm/pit.rpm-list" "${ROOTDIR}/rpm/images.rpm-list" \
    | sort -u \
    | grep -v gpg-pubkey \
    | "${ROOTDIR}/hack/gen-rpm-index.sh" \
    > "${ROOTDIR}/rpm/embedded.yaml"

    # Sync RPMs from node images
    rpm-sync "${ROOTDIR}/rpm/embedded.yaml" "${BUILDDIR}/rpm/embedded"

    # Fix-up embedded/cray directories by removing misc subdirectories
    {
        find "${BUILDDIR}/rpm/embedded/cray" -name '*-team' -type d
        find "${BUILDDIR}/rpm/embedded/cray" -name 'github' -type d
    } | while read path; do
        mv "$path"/* "$(dirname "$path")/"
        rmdir "$path"
    done

    # Fix-up cray RPMs to use architecture-based subdirectories
    find "${BUILDDIR}/rpm/embedded/cray" -name '*.rpm' -type f | while read path; do
        archdir="$(dirname "$path")/$(basename "$path" | sed -e 's/^.\+\.\(.\+\)\.rpm$/\1/')"
        [[ -d "$archdir" ]] || mkdir -p "$archdir"
        mv "$path" "${archdir}/"
    done

    # Ensure we don't ship multiple copies of RPMs already in a CSM repo
    find "${BUILDDIR}/rpm" -mindepth 1 -maxdepth 1 -type d ! -name embedded | while read path; do
        find "$path" -type f -name "*.rpm" -print0 | xargs -0 basename -a | while read filename; do
            find "${BUILDDIR}/rpm/embedded/cray" -type f -name "$filename" -exec rm -rf {} \;
        done
    done

    # Create repository for node image RPMs
    find "${BUILDDIR}/rpm/embedded" -empty -type d -delete
    createrepo "${BUILDDIR}/rpm/embedded"
fi

# Download the correct firmware tarball
mkdir -p "${BUILDDIR}/firmware"
curl -sfSL "$FIRMWARE_PACKAGE" | tar -xzvf - -C "${BUILDDIR}/firmware"

# Download HPE GPG signing key (for verifying signed RPMs)
curl -sfSLRo "${BUILDDIR}/hpe-signing-key.asc" "$HPE_SIGNING_KEY"

# save cray/nexus-setup and quay.io/skopeo/stable images for use in install.sh
vendor-install-deps "$(basename "$BUILDDIR")" "${BUILDDIR}/vendor"

# Package the distribution into an archive
tar -C "${BUILDDIR}/.." -cvzf "${BUILDDIR}/../$(basename "$BUILDDIR").tar.gz" "$(basename "$BUILDDIR")/" --remove-files
