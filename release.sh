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

# copy manifests
rsync -aq "${ROOTDIR}/manifests/" "${BUILDDIR}/manifests/"

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

# apply fixes

# fetch workarounds to the "fix/" directory
: "${FIX_REPO_URL:="ssh://git@stash.us.cray.com:7999/spet/csm-installer-workarounds.git"}"
: "${FIX_REPO_BRANCH:="master"}"
git archive --prefix=fix/ --remote "$FIX_REPO_URL" "$FIX_REPO_BRANCH" | tar -xv -C "${BUILDDIR}"

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
reposync "${BLOBLET_URL}/rpm/csm-sle-15sp2-compute" "${BUILDDIR}/rpm/csm-sle-15sp2-compute"

reposync "http://dst.us.cray.com/dstrepo/bloblets/shasta-firmware/${BLOBLET_REF}/shasta-firmware/" "${BUILDDIR}/rpm/shasta-firmware"

# XXX Should this come from the bloblet?
(
    cd "${BUILDDIR}"
    curl -sfSLO "http://car.dev.cray.com/artifactory/csm/MTL/sle15_sp2_ncn/x86_64/${BLOBLET_REF}/metal-team/cray-pre-install-toolkit-latest.iso"
)

# Download Kubernetes images
: "${KUBERNETES_IMAGES_URL:="https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/kubernetes"}"
: "${KUBERNETES_IMAGE_VERSION:="0.0.12"}"
(
    mkdir -p "${BUILDDIR}/images/kubernetes"
    cd "${BUILDDIR}/images/kubernetes"
    curl -sfSLO "${KUBERNETES_IMAGES_URL}/${KUBERNETES_IMAGE_VERSION}/kubernetes-${KUBERNETES_IMAGE_VERSION}.squashfs"
    curl -sfSLO "${KUBERNETES_IMAGES_URL}/${KUBERNETES_IMAGE_VERSION}/5.3.18-24.43-default-${KUBERNETES_IMAGE_VERSION}.kernel"
    curl -sfSLO "${KUBERNETES_IMAGES_URL}/${KUBERNETES_IMAGE_VERSION}/initrd.img-${KUBERNETES_IMAGE_VERSION}.xz"
)

# Download Ceph images
: "${STORAGE_CEPH_IMAGES_URL:="https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/storage-ceph"}"
: "${STORAGE_CEPH_IMAGE_VERSION:="0.0.9"}"
(
    mkdir -p "${BUILDDIR}/images/storage-ceph"
    cd "${BUILDDIR}/images/storage-ceph"
    curl -sfSLO "${STORAGE_CEPH_IMAGES_URL}/${STORAGE_CEPH_IMAGE_VERSION}/storage-ceph-${STORAGE_CEPH_IMAGE_VERSION}.squashfs"
    curl -sfSLO "${STORAGE_CEPH_IMAGES_URL}/${STORAGE_CEPH_IMAGE_VERSION}/5.3.18-24.43-default-${STORAGE_CEPH_IMAGE_VERSION}.kernel"
    curl -sfSLO "${STORAGE_CEPH_IMAGES_URL}/${STORAGE_CEPH_IMAGE_VERSION}/initrd.img-${STORAGE_CEPH_IMAGE_VERSION}.xz"
)

# save cray/nexus-setup and quay.io/skopeo/stable images for use in install.sh
vendor-install-deps "$(basename "$BUILDDIR")" "${BUILDDIR}/vendor"

# Package the distribution into an archive
tar -C "${BUILDDIR}/.." -cvzf "${BUILDDIR}/../$(basename "$BUILDDIR").tar.gz" "$(basename "$BUILDDIR")/" --remove-files

# TODO Upload to https://arti.dev.cray.com:443/artifactory/csm-distribution-{un}stable-local/
