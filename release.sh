#!/usr/bin/env bash

# Copyright 2020 Hewlett Packard Enterprise Development LP

set -ex
set -o pipefail

: "${RELEASE:="${RELEASE_NAME:="csm"}-${RELEASE_VERSION:="0.0.0"}"}"

# import release utilities
ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOTDIR}/vendor/stash.us.cray.com/scm/shastarelm/release/lib/release.sh"

requires curl git rsync sed

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
    : "${INSTALLDOCS_REPO_BRANCH:="master"}"
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
reposync "${BLOBLET_URL}/rpm/csm-sle-15sp1"         "${BUILDDIR}/rpm/csm-sle-15sp1"
reposync "${BLOBLET_URL}/rpm/csm-sle-15sp1-compute" "${BUILDDIR}/rpm/csm-sle-15sp1-compute"
reposync "${BLOBLET_URL}/rpm/csm-sle-15sp2"         "${BUILDDIR}/rpm/csm-sle-15sp2"

reposync "http://dst.us.cray.com/dstrepo/bloblets/shasta-firmware/${BLOBLET_REF}/shasta-firmware/" "${BUILDDIR}/rpm/shasta-firmware"

# XXX Should this come from the bloblet?
(
    cd "${BUILDDIR}"
    curl -sfSLO "http://car.dev.cray.com/artifactory/csm/MTL/sle15_sp2_ncn/x86_64/${BLOBLET_REF}/metal-team/cray-pre-install-toolkit-latest.iso"
)

# Download Kubernetes images
: "${KUBERNETES_IMAGES_URL:="https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/kubernetes"}"
: "${KUBERNETES_IMAGE_VERSION:="0.0.14"}"
(
    mkdir -p "${BUILDDIR}/images/kubernetes"
    cd "${BUILDDIR}/images/kubernetes"
    curl -sfSLO "${KUBERNETES_IMAGES_URL}/${KUBERNETES_IMAGE_VERSION}/kubernetes-${KUBERNETES_IMAGE_VERSION}.squashfs"
    curl -sfSLO "${KUBERNETES_IMAGES_URL}/${KUBERNETES_IMAGE_VERSION}/5.3.18-24.43-default-${KUBERNETES_IMAGE_VERSION}.kernel"
    curl -sfSLO "${KUBERNETES_IMAGES_URL}/${KUBERNETES_IMAGE_VERSION}/initrd.img-${KUBERNETES_IMAGE_VERSION}.xz"
)

# Download Ceph images
: "${STORAGE_CEPH_IMAGES_URL:="https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/storage-ceph"}"
: "${STORAGE_CEPH_IMAGE_VERSION:="0.0.11"}"
(
    mkdir -p "${BUILDDIR}/images/storage-ceph"
    cd "${BUILDDIR}/images/storage-ceph"
    curl -sfSLO "${STORAGE_CEPH_IMAGES_URL}/${STORAGE_CEPH_IMAGE_VERSION}/storage-ceph-${STORAGE_CEPH_IMAGE_VERSION}.squashfs"
    curl -sfSLO "${STORAGE_CEPH_IMAGES_URL}/${STORAGE_CEPH_IMAGE_VERSION}/5.3.18-24.43-default-${STORAGE_CEPH_IMAGE_VERSION}.kernel"
    curl -sfSLO "${STORAGE_CEPH_IMAGES_URL}/${STORAGE_CEPH_IMAGE_VERSION}/initrd.img-${STORAGE_CEPH_IMAGE_VERSION}.xz"
)

# Generate node images RPM index
[[ -d "${ROOTDIR}/rpm" ]] || mkdir -p "${ROOTDIR}/rpm"
"${ROOTDIR}/hack/list-squashfs-rpms.sh" \
    "${BUILDDIR}/images/kubernetes/kubernetes-${KUBERNETES_IMAGE_VERSION}.squashfs" \
    "${BUILDDIR}/images/storage-ceph/storage-ceph-${STORAGE_CEPH_IMAGE_VERSION}.squashfs" \
| grep -v gpg-pubkey \
| grep -v conntrack-1.1.x86_64 \
| "${ROOTDIR}/hack/gen-rpm-index.sh" \
    > "${ROOTDIR}/rpm/images.yaml"

# Sync RPMs from node images
rpm-sync "${ROOTDIR}/rpm/images.yaml" "${BUILDDIR}/rpm/images"

# Fix-up cray directories by removing *-team directories
find "${BUILDDIR}/rpm/images/cray" -name '*-team' -type d | while read path; do 
    mv "$path"/* "$(dirname "$path")/"
    rmdir "$path"
done

# Fix-up cray RPMs to use architecture-based subdirectories
find "${BUILDDIR}/rpm/images/cray" -name '*.rpm' -type f | while read path; do
    archdir="$(dirname "$path")/$(basename "$path" | sed -e 's/^.\+\.\(.\+\)\.rpm$/\1/')"
    [[ -d "$archdir" ]] || mkdir -p "$archdir"
    mv "$path" "${archdir}/"
done

# Ensure we don't ship multiple copies of RPMs already in a CSM repo
find "${BUILDDIR}/rpm" -mindepth 1 -maxdepth 1 -type d ! -name images | while read path; do
    find "$path" -type f -name "*.rpm" -print0 | xargs -0 basename -a | while read filename; do
        find "${BUILDDIR}/rpm/images/cray" -type f -name "$filename" -exec rm -rf {} \;
    done
done

# Create repository for node image RPMs
find "${BUILDDIR}/rpm/images" -empty -type d -delete
createrepo "${BUILDDIR}/rpm/images"

# save cray/nexus-setup and quay.io/skopeo/stable images for use in install.sh
vendor-install-deps "$(basename "$BUILDDIR")" "${BUILDDIR}/vendor"

# Package the distribution into an archive
tar -C "${BUILDDIR}/.." -cvzf "${BUILDDIR}/../$(basename "$BUILDDIR").tar.gz" "$(basename "$BUILDDIR")/" --remove-files

# TODO Upload to https://arti.dev.cray.com:443/artifactory/csm-distribution-{un}stable-local/
