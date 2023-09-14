#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2022-2023 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
set -euo pipefail
set -o xtrace

: "${RELEASE:="${RELEASE_NAME:="csm"}-${RELEASE_VERSION:="0.0.0"}"}"

# Define maximums for retries on skopeo i/o timeout bandaid logic
export MAX_SKOPEO_RETRY_ATTEMPTS=20
export MAX_SKOPEO_RETRY_TIME_MINUTES=30

# import release utilities
ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOTDIR}/vendor/github.hpe.com/hpe/hpc-shastarelm-release/lib/release.sh"

requires curl docker git perl rsync sed

# Valid SemVer regex, see https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string
# semver_regex='^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$'
# For 1.3, we also forbid capital letters in release version
semver_regex='^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-z-][0-9a-z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-z-][0-9a-z-]*))*))?(?:\+([0-9a-z-]+(?:\.[0-9a-z-]+)*))?$'

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

#
# Setup
#

#code to store credentials in environment variable
if [ ! -z "$ARTIFACTORY_USER" ] && [ ! -z "$ARTIFACTORY_TOKEN" ]; then
    export REPOCREDSVARNAME="REPOCREDSVAR"
    export REPOCREDSVAR=$(jq --null-input --arg url "https://artifactory.algol60.net/artifactory/" --arg realm "Artifactory Realm" --arg user "$ARTIFACTORY_USER"   --arg password "$ARTIFACTORY_TOKEN"   '{($url): {"realm": $realm, "user": $user, "password": $password}}')
fi

# Load and verify assets
source "${ROOTDIR}/assets.sh"

# Build image list (and sync charts to build/.helm/cache/repository
make -C "$ROOTDIR" images

# Pull release tools
cmd_retry docker pull "$PACKAGING_TOOLS_IMAGE"
cmd_retry docker pull "$RPM_TOOLS_IMAGE"
cmd_retry docker pull "$SKOPEO_IMAGE"
cmd_retry docker pull "$CRAY_NEXUS_SETUP_IMAGE"

# Build image to aggregate Snyk scan results
make -C "${ROOTDIR}/security/snyk-aggregate-results"

#
# Build
#

BUILDDIR="${1:-"$(realpath -m "$ROOTDIR/dist/${RELEASE}")"}"

# Initialize build directory
[[ -d "$BUILDDIR" ]] && rm -fr "$BUILDDIR"
mkdir -p "$BUILDDIR"

# Process local files
rsync -aq "${ROOTDIR}/docs/README" "${BUILDDIR}/"
rsync -aq "${ROOTDIR}/docs/INSTALL" "${BUILDDIR}/"
rsync -aq "${ROOTDIR}/CHANGELOG.md" "${BUILDDIR}/"

# Copy install scripts
rsync -aq "${ROOTDIR}/lib/" "${BUILDDIR}/lib/"
gen-version-sh "$RELEASE_NAME" "$RELEASE_VERSION" >"${BUILDDIR}/lib/version.sh"
chmod +x "${BUILDDIR}/lib/version.sh"
rsync -aq "${ROOTDIR}/vendor/github.hpe.com/hpe/hpc-shastarelm-release/lib/install.sh" "${BUILDDIR}/lib/install.sh"
rsync -aq "${ROOTDIR}/install.sh" "${BUILDDIR}/"
rsync -aq "${ROOTDIR}/chrony/" "${BUILDDIR}/chrony/"
rsync -aq "${ROOTDIR}/upgrade.sh" "${BUILDDIR}/"
rsync -aq "${ROOTDIR}/hack/load-container-image.sh" "${BUILDDIR}/hack/"
rsync -aq "${ROOTDIR}/update-mgmt-ncn-cfs-config.sh" "${BUILDDIR}/"
chmod 755 "${BUILDDIR}/update-mgmt-ncn-cfs-config.sh"

# Copy manifests
rsync -aq "${ROOTDIR}/manifests/" "${BUILDDIR}/manifests/"

# Configure yq
shopt -s expand_aliases
alias yq="${ROOTDIR}/vendor/stash.us.cray.com/scm/shasta-cfg/stable/utils/bin/$(uname | awk '{print tolower($0)}')/yq"

# Rewrite manifest spec.sources.charts to reference local helm directory
find "${BUILDDIR}/manifests/" -name '*.yaml' | while read manifest; do
    yq w -i -s - "$manifest" << EOF
- command: update
  path: spec.sources.charts[*].type
  value: directory
- command: update
  path: spec.sources.charts[*].location
  value: ./helm
- command: delete
  path: spec.sources.charts[*].credentialsSecret
EOF
done

# Embed the CSM release version into the csm-config and cray-csm-barebones-recipe-install charts
yq write -i ${BUILDDIR}/manifests/sysmgmt.yaml 'spec.charts.(name==csm-config).values.cray-import-config.import_job.CF_IMPORT_PRODUCT_NAME' "$RELEASE_NAME"
yq write -i ${BUILDDIR}/manifests/sysmgmt.yaml 'spec.charts.(name==csm-config).values.cray-import-config.import_job.CF_IMPORT_PRODUCT_VERSION' "$RELEASE_VERSION"
yq write -i ${BUILDDIR}/manifests/sysmgmt.yaml 'spec.charts.(name==csm-config).values.cray-import-config.import_job.CF_IMPORT_GITEA_REPO' "${RELEASE_NAME}-config-management"
yq write -i ${BUILDDIR}/manifests/sysmgmt.yaml 'spec.charts.(name==cray-csm-barebones-recipe-install).values.cray-import-kiwi-recipe-image.import_job.PRODUCT_VERSION' "${RELEASE_VERSION}"
yq write -i ${BUILDDIR}/manifests/sysmgmt.yaml 'spec.charts.(name==cray-csm-barebones-recipe-install).values.cray-import-kiwi-recipe-image.import_job.PRODUCT_NAME' "${RELEASE_NAME}"
yq write -i ${BUILDDIR}/manifests/sysmgmt.yaml 'spec.charts.(name==cray-csm-barebones-recipe-install).values.cray-import-kiwi-recipe-image.import_job.name' "${RELEASE_NAME}-image-recipe-import-${RELEASE_VERSION}"

# Include the tds yaml in the tarball
cp "${ROOTDIR}/tds_cpu_requests.yaml" "${BUILDDIR}/tds_cpu_requests.yaml"

# Generate Nexus blob store configuration
generate-nexus-config blobstore <"${ROOTDIR}/nexus-blobstores.yaml" >"${BUILDDIR}/nexus-blobstores.yaml"

# Generate Nexus repositories configuration
# Update repository names based on the release version
sed -e "s/-0.0.0/-${RELEASE_VERSION}/g" "${ROOTDIR}/nexus-repositories.yaml" \
    | generate-nexus-config repository >"${BUILDDIR}/nexus-repositories.yaml"

# Sync shasta-cfg
mkdir "${BUILDDIR}/shasta-cfg"
"${ROOTDIR}/vendor/stash.us.cray.com/scm/shasta-cfg/stable/package/make-dist.sh" "${BUILDDIR}/shasta-cfg"

# Sync Helm charts from cache
rsync -aq "${ROOTDIR}/build/.helm/cache/repository"/*.tgz "${BUILDDIR}/helm"

# Sync container images
parallel -j 75% --retries 5 --halt-on-error now,fail=1 -v \
    -a "${ROOTDIR}/build/images/index.txt" --colsep '\t' \
    "${ROOTDIR}/build/images/sync.sh" "docker://{2}" "dir:${BUILDDIR}/docker/{1}"

# Sync RPM manifests
export RPM_SYNC_NUM_CONCURRENT_DOWNLOADS=1
rpm-sync "${ROOTDIR}/rpm/cray/csm/sle-15sp2/index.yaml" "${BUILDDIR}/rpm/cray/csm/sle-15sp2" -s
rpm-sync "${ROOTDIR}/rpm/cray/csm/sle-15sp2-compute/index.yaml" "${BUILDDIR}/rpm/cray/csm/sle-15sp2-compute" -s
rpm-sync "${ROOTDIR}/rpm/cray/csm/sle-15sp3/index.yaml" "${BUILDDIR}/rpm/cray/csm/sle-15sp3" -s
rpm-sync "${ROOTDIR}/rpm/cray/csm/sle-15sp3-compute/index.yaml" "${BUILDDIR}/rpm/cray/csm/sle-15sp3-compute" -s
rpm-sync "${ROOTDIR}/rpm/cray/csm/sle-15sp4/index.yaml" "${BUILDDIR}/rpm/cray/csm/sle-15sp4" -s
rpm-sync "${ROOTDIR}/rpm/cray/csm/sle-15sp4-compute/index.yaml" "${BUILDDIR}/rpm/cray/csm/sle-15sp4-compute" -s
#rpm-sync "${ROOTDIR}/rpm/cray/csm/sle-15sp2/index.yaml" "${BUILDDIR}/rpm/cray/csm/sle-15sp2" 
#rpm-sync "${ROOTDIR}/rpm/cray/csm/sle-15sp2-compute/index.yaml" "${BUILDDIR}/rpm/cray/csm/sle-15sp2-compute" 
#rpm-sync "${ROOTDIR}/rpm/cray/csm/sle-15sp3/index.yaml" "${BUILDDIR}/rpm/cray/csm/sle-15sp3" 
#rpm-sync "${ROOTDIR}/rpm/cray/csm/sle-15sp3-compute/index.yaml" "${BUILDDIR}/rpm/cray/csm/sle-15sp3-compute" 
#rpm-sync "${ROOTDIR}/rpm/cray/csm/sle-15sp4/index.yaml" "${BUILDDIR}/rpm/cray/csm/sle-15sp4" 
#rpm-sync "${ROOTDIR}/rpm/cray/csm/sle-15sp4-compute/index.yaml" "${BUILDDIR}/rpm/cray/csm/sle-15sp4-compute" 

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
createrepo "${BUILDDIR}/rpm/cray/csm/sle-15sp3"
createrepo "${BUILDDIR}/rpm/cray/csm/sle-15sp3-compute"
createrepo "${BUILDDIR}/rpm/cray/csm/sle-15sp4"
createrepo "${BUILDDIR}/rpm/cray/csm/sle-15sp4-compute"

# Extract docs RPM into release
mkdir -p "${BUILDDIR}/tmp/docs"
(
    cd "${BUILDDIR}/tmp/docs"
    find "${BUILDDIR}/rpm/cray/csm/sle-15sp2" -type f -name docs-csm-\*.rpm | head -n 1 | xargs -n 1 rpm2cpio | cpio -idvm ./usr/share/doc/csm/*
)
mv "${BUILDDIR}/tmp/docs/usr/share/doc/csm" "${BUILDDIR}/docs"

# Extract wars RPM into release
mkdir -p "${BUILDDIR}/tmp/wars"
(
    cd "${BUILDDIR}/tmp/wars"
    find "${BUILDDIR}/rpm/cray/csm/sle-15sp2" -type f -name csm-install-workarounds-\*.rpm | head -n 1 | xargs -n 1 rpm2cpio | cpio -idvm ./opt/cray/csm/workarounds/*
    find . -type f -name '.keep' -delete
)
mv "${BUILDDIR}/tmp/wars/opt/cray/csm/workarounds" "${BUILDDIR}/workarounds"

# Clean up temp space
rm -fr "${BUILDDIR}/tmp"

# Download pre-install toolkit
# NOTE: This value is printed in #livecd-ci-alerts (slack) when a build STARTS.
(
    cd "${BUILDDIR}"
    for url in "${PIT_ASSETS[@]}"; do cmd_retry curl -sfSLOR -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" "$url"; done
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
    for url in "${KUBERNETES_ASSETS[@]}"; do cmd_retry curl -sfSLOR -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" "$url"; done
)

# Download storage Ceph assets
(
    mkdir -p "${BUILDDIR}/images/storage-ceph"
    cd "${BUILDDIR}/images/storage-ceph"
    for url in "${STORAGE_CEPH_ASSETS[@]}"; do cmd_retry curl -sfSLOR -u "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}" "$url"; done
)

if [[ "${EMBEDDED_REPO_ENABLED:-yes}" = "yes" ]]; then
    # Generate node images RPM index
    [[ -d "${ROOTDIR}/rpm" ]] || mkdir -p "${ROOTDIR}/rpm"
    "${ROOTDIR}/hack/list-squashfs-rpms.sh" \
        "${BUILDDIR}"/images/kubernetes/kubernetes-*.squashfs \
        "${BUILDDIR}"/images/storage-ceph/storage-ceph-*.squashfs \
    > "${ROOTDIR}/rpm/images.rpm-list"

    #append kernel-default-debuginfo package to rpm list 
    if [ ! -z "$KERNEL_DEFAULT_DEBUGINFO_VERSION" ]; then
        echo "kernel-default-debuginfo-${KERNEL_DEFAULT_DEBUGINFO_VERSION}" >> "${ROOTDIR}/rpm/images.rpm-list"
    fi

    # Generate RPM index from pit and node images
    cat "${ROOTDIR}/rpm/pit.rpm-list" "${ROOTDIR}/rpm/images.rpm-list" \
    | sort -u \
    | grep -v gpg-pubkey \
    | grep -v aaa_base \
    | grep -v hpe-csm-goss-package-0.3.13 \
    | "${ROOTDIR}/hack/gen-rpm-index.sh" \
    > "${ROOTDIR}/rpm/embedded.yaml"

    # Sync RPMs from node images
    rpm-sync "${ROOTDIR}/rpm/embedded.yaml" "${BUILDDIR}/rpm/embedded" -s

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

# Download HPE GPG signing key (for verifying signed RPMs)
cmd_retry curl -sfSLRo "${BUILDDIR}/hpe-signing-key.asc" "$HPE_SIGNING_KEY"

# Use a newer version of cfs-config-util that hasn't rolled out to other products yet
CFS_CONFIG_UTIL_IMAGE="arti.hpc.amslabs.hpecorp.net/csm-docker-remote/stable/cfs-config-util:5.0.0"
# Save cray/nexus-setup, quay.io/skopeo/stable, and cfs-config-util images for use in install.sh
vendor-install-deps --include-cfs-config-util "$(basename "$BUILDDIR")" "${BUILDDIR}/vendor"

# Scan container images
parallel -j 75% --halt-on-error now,fail=1 -v \
    -a "${ROOTDIR}/build/images/index.txt" --colsep '\t' \
    "${ROOTDIR}/hack/snyk-scan.sh" "${BUILDDIR}/scans/docker" '{2}' '{1}'
cp "${ROOTDIR}/build/images/chartmap.csv" "${BUILDDIR}/scans/docker/"
${ROOTDIR}/hack/snyk-aggregate-results.sh "${BUILDDIR}/scans/docker" --helm-chart-map "/data/chartmap.csv" --sheet-name "$RELEASE"
${ROOTDIR}/hack/snyk-to-html.sh "${BUILDDIR}/scans/docker"

# Save scans to release distirbution
scandir="$(realpath -m "$ROOTDIR/dist/${RELEASE}-scans")"
mkdir -p "$scandir"
rsync -aq "${BUILDDIR}/scans/" "${scandir}/"

# Save snyk results spreadsheet as a separate asset
cp "${scandir}/docker/snyk-results.xlsx" "${ROOTDIR}/dist/${RELEASE}-snyk-results.xlsx"

# Save image digest as a separate asset
cp "${ROOTDIR}/build/images/index.txt" "${ROOTDIR}/dist/${RELEASE}-images.txt"

# Package scans as an independent archive
tar -C "${scandir}/.." --owner=0 --group=0 -cvzf "${scandir}/../$(basename "$scandir").tar.gz" "$(basename "$scandir")/" --remove-files

# Package the distribution into an archive
tar -C "${BUILDDIR}/.." --owner=0 --group=0 -cvzf "${BUILDDIR}/../$(basename "$BUILDDIR").tar.gz" "$(basename "$BUILDDIR")/" --remove-files
