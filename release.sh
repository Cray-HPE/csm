#!/usr/bin/env bash

# Copyright 2020 Hewlett Packard Enterprise Development LP

set -ex

: "${RELEASE:="${RELEASE_NAME:="csm"}-${RELEASE_VERSION:="0.0.0"}"}"
: "${RELEASE_BRANCH:="master"}"

# assemble bloblet URL
case "$RELEASE_BRANCH" in
master) BLOBLET_DIR="dev/master" ;;
*) BLOBLET_DIR="$RELEASE_BRANCH" ;;
esac

: "${BLOBLET_URL:="http://dst.us.cray.com/dstrepo/bloblets/csm/${BLOBLET_DIR}"}"

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
sed -e "s/0.0.0/${RELEASE_VERSION}/g" "${ROOTDIR}/nexus-repositories.yaml" \
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
#helm-sync "${ROOTDIR}/helm/index.yaml" "${BUILDDIR}/helm"

# sync container images
#skopeo-sync "${ROOTDIR}/docker/index.yaml" "${BUILDDIR}/docker"

# sync bloblet repos
#reposync "${BLOBLETS_URL}/rpms/csm-sle015sp1"         "${BUILDDIR}/rpms/csm-sle-15sp1"
#reposync "${BLOBLETS_URL}/rpms/csm-sle-15sp1-compute" "${BUILDDIR}/rpms/csm-sle-15sp1-compute"
reposync "${BLOBLETS_URL}/rpms/csm-sle-15sp2"         "${BUILDDIR}/rpms/csm-sle-15sp2"
reposync "${BLOBLETS_URL}/rpms/csm-sle-15sp2-compute" "${BUILDDIR}/rpms/csm-sle-15sp2-compute"

# XXX Should this come from the bloblet?
(
    cd "${BUILDDIR}"
    curl -sfSLO "http://car.dev.cray.com/artifactory/csm/MTL/sle15_sp2_ncn/x86_64/dev/master/metal-team/cray-pre-install-toolkit-latest.iso"
)

# Download Kubernetes images
: "${KUBERNETES_IMAGES_URL:="https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/kubernetes"}"
(
    mkdir -p "${BUILDDIR}/images/kubernetes"
    cd "${BUILDDIR}/images/kubernetes"
    curl -sfSLO "${KUBERNETES_IMAGES_URL}/0.0.5/kubernetes-0.0.5.squashfs"
)

# Download Ceph images
: "${STORAGE_CEPH_IMAGES_URL:="https://arti.dev.cray.com/artifactory/node-images-stable-local/shasta/storage-ceph"}"
(
    mkdir -p "${BUILDDIR}/images/storage-ceph"
    cd "${BUILDDIR}/images/storage-ceph"
    curl -sfSLO "${STORAGE_CEPH_IMAGES_URL}/0.0.4/storage-ceph-0.0.4.squashfs"
    curl -sfSLO "${STORAGE_CEPH_IMAGES_URL}/0.0.4/5.3.18-24.37-default-0.0.4.kernel"
    curl -sfSLO "${STORAGE_CEPH_IMAGES_URL}/0.0.4/initrd.img-0.0.4.xz"
)

# save cray/nexus-setup and quay.io/skopeo/stable images for use in install.sh
vendor-install-deps "$(basename "$BUILDDIR")" "${BUILDDIR}/vendor"

# Package the distribution into an archive
exit
tar -C "${BUILDDIR}/.." -cvzf "$(basename "$BUILDDIR").tar.gz" "$(basename "$BUILDDIR")/" --remove-files

# TODO Upload to https://arti.dev.cray.com:443/artifactory/csm-distribution-{un}stable-local/
