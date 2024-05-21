#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2022-2024 Hewlett Packard Enterprise Development LP
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
set -e -o pipefail

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOTDIR}/common.sh"
source "${ROOTDIR}/vendor/github.hpe.com/hpe/hpc-shastarelm-release/lib/release.sh"

# Initialize build directory
mkdir -p "$BUILDDIR"

# Process local files
rsync -aq "${ROOTDIR}/docs/README" "${BUILDDIR}/"
rsync -aq "${ROOTDIR}/docs/INSTALL" "${BUILDDIR}/"

# Store cloud-init.yaml
cp -f "${ROOTDIR}/rpm/cloud-init.yaml" "${BUILDDIR}/rpm/cloud-init.yaml"

# Copy install scripts
rsync -aq "${ROOTDIR}/lib/" "${BUILDDIR}/lib/"
gen-version-sh "$RELEASE_NAME" "$RELEASE_VERSION" >"${BUILDDIR}/lib/version.sh"
chmod +x "${BUILDDIR}/lib/version.sh"
rsync -aq "${ROOTDIR}/vendor/github.hpe.com/hpe/hpc-shastarelm-release/lib/install.sh" "${BUILDDIR}/lib/install.sh"
rsync -aq "${ROOTDIR}/install.sh" "${BUILDDIR}/"
rsync -aq "${ROOTDIR}/upgrade.sh" "${BUILDDIR}/"
rsync -aq "${ROOTDIR}/hack/load-container-image.sh" "${BUILDDIR}/hack/"
rsync -aq "${ROOTDIR}/update-mgmt-ncn-cfs-config.sh" "${BUILDDIR}/"
chmod 755 "${BUILDDIR}/update-mgmt-ncn-cfs-config.sh"

# Copy manifests
rsync -aq "${ROOTDIR}/manifests/" "${BUILDDIR}/manifests/"

# Copy empty directory created for upgrade using IUF
rsync -aq "${ROOTDIR}/dummy/" "${BUILDDIR}/dummy/"

# Copy IUF product manifest
rsync -aq "${ROOTDIR}/iuf-product-manifest.yaml" "${BUILDDIR}/"
# set version of CSM in iuf-product-manifest.yaml according to RELEASE_VERSION
yq e ".version = '${RELEASE_VERSION}'" -i "${BUILDDIR}/iuf-product-manifest.yaml"

# Copy IUF stage hooks
rsync -aq "${ROOTDIR}/hooks/" "${BUILDDIR}/hooks/"
chmod +x "${BUILDDIR}/hooks/pre-install-check-prehook.sh"
chmod +x "${BUILDDIR}/hooks/prepare-images-posthook.sh"
chmod +x "${BUILDDIR}/hooks/management-nodes-rollout-prehook.sh"
chmod +x "${BUILDDIR}/hooks/helm-upgrade-status-check.sh"

# Copy IUF onExit handler
chmod +x "${BUILDDIR}/hooks/deploy-product-onexit.sh"

# Rewrite manifest spec.sources.charts to reference local helm directory
find "${BUILDDIR}/manifests/" -name '*.yaml' | while read -r manifest; do
    yq e '.spec.sources.charts[].type = "directory"' -i "$manifest"
    yq e '.spec.sources.charts[].location = "./helm"' -i "$manifest"
    yq e 'del(.spec.sources.charts[].credentialsSecret)' -i "$manifest"
done

# Embed the CSM release version into the csm-config and cray-csm-barebones-recipe-install charts
yq e "(.spec.charts[] | select(.name == \"csm-config\") | .values.cray-import-config.import_job.CF_IMPORT_PRODUCT_NAME) = \"${RELEASE_NAME}\"" -i "${BUILDDIR}/manifests/sysmgmt.yaml"
yq e "(.spec.charts[] | select(.name == \"csm-config\") | .values.cray-import-config.import_job.CF_IMPORT_PRODUCT_VERSION) = \"${RELEASE_VERSION}\"" -i "${BUILDDIR}/manifests/sysmgmt.yaml"
yq e "(.spec.charts[] | select(.name == \"csm-config\") | .values.cray-import-config.import_job.CF_IMPORT_GITEA_REPO) = \"${RELEASE_NAME}-config-management\"" -i "${BUILDDIR}/manifests/sysmgmt.yaml"
yq e "(.spec.charts[] | select(.name == \"cray-csm-barebones-recipe-install\") | .values.cray-import-kiwi-recipe-image.import_job.PRODUCT_VERSION) = \"${RELEASE_VERSION}\"" -i "${BUILDDIR}/manifests/sysmgmt.yaml"
yq e "(.spec.charts[] | select(.name == \"cray-csm-barebones-recipe-install\") | .values.cray-import-kiwi-recipe-image.import_job.PRODUCT_NAME) = \"${RELEASE_NAME}\"" -i "${BUILDDIR}/manifests/sysmgmt.yaml"
yq e "(.spec.charts[] | select(.name == \"cray-csm-barebones-recipe-install\") | .values.cray-import-kiwi-recipe-image.import_job.name) = \"${RELEASE_NAME}-image-recipe-import-${RELEASE_VERSION}\"" -i "${BUILDDIR}/manifests/sysmgmt.yaml"

# Get the version of the cray-sat container image in this CSM build. There should
# only be one version, but if there is more than one, take the latest.
CRAY_SAT_VERSION="$(yq '."artifactory.algol60.net/csm-docker/stable".images.cray-sat[]' ${ROOTDIR}/docker/index.yaml | sort -Vr | head -n 1)"

# Set cray-sat tag in csm-config Helm chart via the Loftsman manifest
yq e "(.spec.charts[] | select(.name == \"csm-config\") |
       .values.cray-import-config.import_job.initContainers[] |
       select(.name == \"set-sat-version\") | .env[] |
       select(.name == \"CRAY_SAT_VERSION\") | .value) = \"${CRAY_SAT_VERSION}\"" \
    -i "${BUILDDIR}/manifests/sysmgmt.yaml"

# Get Alpine Linux image tag from docker/index.yaml
ALPINE_LINUX_TAG="$(yq '."artifactory.algol60.net/csm-docker/stable".images."docker.io/library/alpine"[]' ${ROOTDIR}/docker/index.yaml | sort -Vr | head -n 1)"

# Set Alpine Linux image in csm-config Helm chart via the Loftsman manifest
yq e "(.spec.charts[] | select(.name == \"csm-config\") |
       .values.cray-import-config.import_job.initContainers[] |
       select(.name == \"set-sat-version\") | .image)
       = \"artifactory.algol60.net/csm-docker/stable/docker.io/library/alpine:${ALPINE_LINUX_TAG}\"" \
    -i "${BUILDDIR}/manifests/sysmgmt.yaml"

# Replace @SAT_VERSION@ in script run during installations
sed -i "s/@SAT_VERSION@/${CRAY_SAT_VERSION}/" "${BUILDDIR}/lib/setup-nexus.sh"

# Generate Nexus blob store configuration
generate-nexus-config blobstore <"${ROOTDIR}/nexus-blobstores.yaml" >"${BUILDDIR}/nexus-blobstores.yaml"

# Generate Nexus repositories configuration
# Update repository names based on the release version
sed -e "s/-0.0.0/-${RELEASE_VERSION}/g" "${ROOTDIR}/nexus-repositories.yaml" \
    | generate-nexus-config repository >"${BUILDDIR}/nexus-repositories.yaml"

# Sync shasta-cfg
mkdir "${BUILDDIR}/shasta-cfg"
"${ROOTDIR}/vendor/github.com/Cray-HPE/shasta-cfg/package/make-dist.sh" "${BUILDDIR}/shasta-cfg"

# Save cray/nexus-setup, quay.io/skopeo/stable, and cfs-config-util images for use in install.sh
vendor-install-deps --include-cfs-config-util "$(basename "$BUILDDIR")" "${BUILDDIR}/vendor"

# Package the distribution into an archive
tar -C "${BUILDDIR}/.." --owner=0 --group=0 -cvzf "${BUILDDIR}/../$(basename "$BUILDDIR").tar.gz" "$(basename "$BUILDDIR")/" --remove-files
