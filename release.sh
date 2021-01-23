#!/usr/bin/env bash

# Copyright 2020 Hewlett Packard Enterprise Development LP

set -ex
set -o pipefail

: "${RELEASE:="${RELEASE_NAME:="csm"}-${RELEASE_VERSION:="0.0.0"}"}"

# import release utilities
ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOTDIR}/vendor/stash.us.cray.com/scm/shastarelm/release/lib/release.sh"

requires curl git rsync sed

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

# copy install scripts
mkdir -p "${BUILDDIR}/lib"
gen-version-sh "$RELEASE_NAME" "$RELEASE_VERSION" >"${BUILDDIR}/lib/version.sh"
chmod +x "${BUILDDIR}/lib/version.sh"
rsync -aq "${ROOTDIR}/vendor/stash.us.cray.com/scm/shastarelm/release/lib/install.sh" "${BUILDDIR}/lib/install.sh"
rsync -aq "${ROOTDIR}/install.sh" "${BUILDDIR}/"
rsync -aq "${ROOTDIR}/uninstall.sh" "${BUILDDIR}/"
rsync -aq "${ROOTDIR}/hack/load-container-image.sh" "${BUILDDIR}/hack/"

# copy manifests
rsync -aq "${ROOTDIR}/manifests/" "${BUILDDIR}/manifests/"

# copy workarounds 
rsync -aq "${ROOTDIR}/fix/" "${BUILDDIR}/fix/"

# generate Nexus blob store configuration
generate-nexus-config blobstore <"${ROOTDIR}/nexus-blobstores.yaml" >"${BUILDDIR}/nexus-blobstores.yaml"

# generate Nexus repositories configuration
# update repository names based on the release version
sed -e "s/-0.0.0/-${RELEASE_VERSION}/g" "${ROOTDIR}/nexus-repositories.yaml" \
    | generate-nexus-config repository >"${BUILDDIR}/nexus-repositories.yaml"

# Process remote repos

# copy docs
if [[ "${INSTALLDOCS_ENABLE:="yes"}" == "yes" ]]; then
    : "${INSTALLDOCS_REPO_URL:="ssh://git@stash.us.cray.com:7999/mtl/docs-csm-install.git"}"
    : "${INSTALLDOCS_REPO_BRANCH:="v${RELEASE_VERSION}"}"
    git archive --prefix=docs/ --remote "$INSTALLDOCS_REPO_URL" "$INSTALLDOCS_REPO_BRANCH" | tar -xv -C "${BUILDDIR}"
    # clean-up
    rm -f "${BUILDDIR}/docs/.gitignore"
    rm -f "${BUILDDIR}/docs/007-NCN-NEXUS-INSTALL.md"
    rm -f "${BUILDDIR}/docs/docs-csm-install.spec"
    rm -f "${BUILDDIR}/docs/Jenkinsfile"
    rm -fr "${BUILDDIR}/docs/nexus"
fi

# sync helm charts
helm-sync "${ROOTDIR}/helm/index.yaml" "${BUILDDIR}/helm"

# sync container images
skopeo-sync "${ROOTDIR}/docker/index.yaml" "${BUILDDIR}/docker"

# sync bloblet repos
: "${BLOBLET_REF:="release/shasta-1.4"}"
: "${BLOBLET_URL:="http://dst.us.cray.com/dstrepo/bloblets/csm/${BLOBLET_REF}"}"
reposync "${BLOBLET_URL}/rpm/csm-sle-15sp1"         "${BUILDDIR}/rpm/cray/csm/sle-15sp1"
reposync "${BLOBLET_URL}/rpm/csm-sle-15sp1-compute" "${BUILDDIR}/rpm/cray/csm/sle-15sp1-compute"
reposync "${BLOBLET_URL}/rpm/csm-sle-15sp2"         "${BUILDDIR}/rpm/cray/csm/sle-15sp2"

# Sync RPM manifests
rpm-sync "${ROOTDIR}/rpm/cray/csm/sle-15sp1/index.yaml" "${BUILDDIR}/rpm/cray/csm/sle-15sp1"
rpm-sync "${ROOTDIR}/rpm/cray/csm/sle-15sp1-compute/index.yaml" "${BUILDDIR}/rpm/cray/csm/sle-15sp1-compute"
rpm-sync "${ROOTDIR}/rpm/cray/csm/sle-15sp2/index.yaml" "${BUILDDIR}/rpm/cray/csm/sle-15sp2"

# Fix-up cray directories by removing *-team directories
find "${BUILDDIR}/rpm/cray" -name '*-team' -type d | while read path; do 
    mv "$path"/* "$(dirname "$path")/"
    rmdir "$path"
done

# Remove empty directories
find "${BUILDDIR}/rpm/cray" -empty -type d -delete

# Create CSM repositories
createrepo "${BUILDDIR}/rpm/cray/csm/sle-15sp1"
createrepo "${BUILDDIR}/rpm/cray/csm/sle-15sp1-compute"
createrepo "${BUILDDIR}/rpm/cray/csm/sle-15sp2"

reposync "http://dst.us.cray.com/dstrepo/bloblets/shasta-firmware/${BLOBLET_REF}/shasta-firmware/" "${BUILDDIR}/rpm/shasta-firmware"

# Download pre-install toolkit
# NOTE: This value is printed in #livecd-ci-alerts (slack) when a build STARTS.
: "${CRAY_PIT_VERSION:="sle15sp2.x86_64-1.3.0-20210123000044-g6527f47"}"
: "${CRAY_PIT_URL:="http://car.dev.cray.com/artifactory/csm/MTL/sle15_sp2_ncn/x86_64/${BLOBLET_REF}/metal-team/cray-pre-install-toolkit-${CRAY_PIT_VERSION}.iso"}"
(
    cd "${BUILDDIR}"
    curl -sfSLOR "$CRAY_PIT_URL"
)

# Generate list of installed RPMs; see
# https://github.com/OSInside/kiwi/blob/master/kiwi/system/setup.py#L1067
# for how the .packages file is generated.
[[ -d "${ROOTDIR}/rpm" ]] || mkdir -p "${ROOTDIR}/rpm"
curl -sfSL "${CRAY_PIT_URL%.iso}.packages" \
| cut -d '|' -f 1-5 \
| sed -e 's/(none)//' \
| sed -e 's/\(.*\)|\([^|]\+\)$/\1.\2/g' \
| sed -e 's/|\+/-/g' \
> "${ROOTDIR}/rpm/pit.rpm-list"

# Download Kubernetes images
: "${KUBERNETES_IMAGES_URL:="https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/kubernetes"}"
: "${KUBERNETES_IMAGE_VERSION:="0.0.16"}"
(
    mkdir -p "${BUILDDIR}/images/kubernetes"
    cd "${BUILDDIR}/images/kubernetes"
    curl -sfSLOR "${KUBERNETES_IMAGES_URL}/${KUBERNETES_IMAGE_VERSION}/kubernetes-${KUBERNETES_IMAGE_VERSION}.squashfs"
    curl -sfSLOR "${KUBERNETES_IMAGES_URL}/${KUBERNETES_IMAGE_VERSION}/5.3.18-24.43-default-${KUBERNETES_IMAGE_VERSION}.kernel"
    curl -sfSLOR "${KUBERNETES_IMAGES_URL}/${KUBERNETES_IMAGE_VERSION}/initrd.img-${KUBERNETES_IMAGE_VERSION}.xz"
)

# Download Ceph images
: "${STORAGE_CEPH_IMAGES_URL:="https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/storage-ceph"}"
: "${STORAGE_CEPH_IMAGE_VERSION:="0.0.14"}"
(
    mkdir -p "${BUILDDIR}/images/storage-ceph"
    cd "${BUILDDIR}/images/storage-ceph"
    curl -sfSLOR "${STORAGE_CEPH_IMAGES_URL}/${STORAGE_CEPH_IMAGE_VERSION}/storage-ceph-${STORAGE_CEPH_IMAGE_VERSION}.squashfs"
    curl -sfSLOR "${STORAGE_CEPH_IMAGES_URL}/${STORAGE_CEPH_IMAGE_VERSION}/5.3.18-24.43-default-${STORAGE_CEPH_IMAGE_VERSION}.kernel"
    curl -sfSLOR "${STORAGE_CEPH_IMAGES_URL}/${STORAGE_CEPH_IMAGE_VERSION}/initrd.img-${STORAGE_CEPH_IMAGE_VERSION}.xz"
)

# Generate node images RPM index
[[ -d "${ROOTDIR}/rpm" ]] || mkdir -p "${ROOTDIR}/rpm"
"${ROOTDIR}/hack/list-squashfs-rpms.sh" \
    "${BUILDDIR}/images/kubernetes/kubernetes-${KUBERNETES_IMAGE_VERSION}.squashfs" \
    "${BUILDDIR}/images/storage-ceph/storage-ceph-${STORAGE_CEPH_IMAGE_VERSION}.squashfs" \
| grep -v gpg-pubkey \
| grep -v conntrack-1.1.x86_64 \
> "${ROOTDIR}/rpm/images.rpm-list"

# Generate RPM index from pit and node images
cat "${ROOTDIR}/rpm/pit.rpm-list" "${ROOTDIR}/rpm/images.rpm-list" \
| sort -u \
| "${ROOTDIR}/hack/gen-rpm-index.sh" \
> "${ROOTDIR}/rpm/embedded.yaml"

# Sync RPMs from node images
rpm-sync "${ROOTDIR}/rpm/embedded.yaml" "${BUILDDIR}/rpm/embedded"

# Fix-up cray directories by removing *-team directories
find "${BUILDDIR}/rpm/embedded/cray" -name '*-team' -type d | while read path; do 
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

# save cray/nexus-setup and quay.io/skopeo/stable images for use in install.sh
vendor-install-deps "$(basename "$BUILDDIR")" "${BUILDDIR}/vendor"

# Package the distribution into an archive
tar -C "${BUILDDIR}/.." -cvzf "${BUILDDIR}/../$(basename "$BUILDDIR").tar.gz" "$(basename "$BUILDDIR")/" --remove-files
