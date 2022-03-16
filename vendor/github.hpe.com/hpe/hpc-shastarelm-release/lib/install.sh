#!/usr/bin/env bash

# Copyright 2020,2022 Hewlett Packard Enterprise Development LP

# Defaults
: "${NEXUS_URL:="https://packages.local"}"
: "${NEXUS_REGISTRY:="registry.local"}"

export NEXUS_URL

# Set ROOTDIR to reasonable default, assumes this script is in a subdir (e.g., lib)
: "${ROOTDIR:="$(dirname "${BASH_SOURCE[0]}")/.."}"

declare -a podman_run_flags=(--network host)

# Prefer to use podman, but for environments with docker
if [[ "${USE_DOCKER_NOT_PODMAN:-"no"}" == "yes" ]]; then
    echo >&2 "warning: using docker, not podman"
    shopt -s expand_aliases
    alias podman=docker
fi

function requires() {
    while [[ $# -gt 0 ]]; do
        command -v "$1" >/dev/null 2>&1 || {
            echo >&2 "command not found: ${1}"
            exit 1
        }
        shift
    done
}

requires curl find podman realpath

# usage: load-vendor-image TARFILE
#
# Loads a vendored container image TARFILE saved using "docker save" into
# podman's runtime to facilitate installation.
function load-vendor-image() {
    (
        set -o pipefail
        podman load -q -i "$1" 2>/dev/null | sed -e 's/^.*: //'
    )
}

declare -a vendor_images=()

function load-install-deps() {
    # Load vendor images to support installation
    if [[ -f "${ROOTDIR}/vendor/cray-nexus-setup.tar" ]]; then
        [[ -v CRAY_NEXUS_SETUP_IMAGE ]] || CRAY_NEXUS_SETUP_IMAGE="$(load-vendor-image "${ROOTDIR}/vendor/cray-nexus-setup.tar")" || return
        vendor_images+=("$CRAY_NEXUS_SETUP_IMAGE")
    fi

    if [[ -f "${ROOTDIR}/vendor/skopeo.tar" ]]; then
        [[ -v SKOPEO_IMAGE ]] || SKOPEO_IMAGE="$(load-vendor-image "${ROOTDIR}/vendor/skopeo.tar")" || return
        vendor_images+=("$SKOPEO_IMAGE")
    fi
}

function clean-install-deps() {
    # Clean images used to support installation
    for image in "${vendor_images[@]}"; do
        podman rmi -f "$image"
    done
}

# usage: nexus-get-credential [[-n NAMESPACE] SECRET]
#
# Gets Nexus username and password from SECRET in NAMESPACE and sets
# NEXUS_USERNAME and NEXUS_PASSWORD as appropriate. By default NAMESPACE is
# "nexus" and SECRET is "nexus-admin-credential".
function nexus-get-credential() {
    requires base64 kubectl

    [[ $# -gt 0 ]] || set -- -n nexus nexus-admin-credential

    kubectl get secret "${@}" >/dev/null || return $?

    export NEXUS_USERNAME="$(kubectl get secret "${@}" -o jsonpath='{.data.username}' | base64 -d)"
    export NEXUS_PASSWORD="$(kubectl get secret "${@}" -o jsonpath='{.data.password}' | base64 -d)"
}

# usage: nexus-setdefault-credential
#
# Ensures NEXUS_USERNAME and NEXUS_PASSWORD are set, at least to default
# credential.
function nexus-setdefault-credential() {
    [[ -v NEXUS_PASSWORD && -n "$NEXUS_PASSWORD" ]] && return 0
    if ! nexus-get-credential; then
        echo >&2 "warning: Nexus admin credential not detected, falling back to defaults"
        export NEXUS_USERNAME="admin"
        export NEXUS_PASSWORD="admin123"
    fi
    return 0
}

# usage: nexus-setup (blobstores|repositories) CONFIG
#
# Sets up Nexus blob stores or repositories given CONFIG, a valid configuration
# YAML file where each document is valid HTTP POST data to the respective Nexus
# REST API:
#
# - Blob stores: /service/rest/beta/blobstores/<type>[/<name>]
# - Repositories: /service/rest/beta/repositories/<format>/<type>[/<name>]
#
# Requires the following environment variables to be set:
#
#   NEXUS_URL - Base Nexus URL; defaults to https://packages.local
#   CRAY_NEXUS_SETUP_IMAGE - Image containing Cray's Nexus setup tools;
#       recommended to vendor with tag specific to a product version
#
# If the NEXUS_PASSWORD environment variable is not set, attempts to set
# NEXUS_USERNAME and NEXUS_PASSWORD based on the nexus-admin-credential
# Kubernetes secret. Otherwise, the default Nexus admin credentials are used.
function nexus-setup() {
    nexus-setdefault-credential
    podman run --rm "${podman_run_flags[@]}" \
        -v "$(realpath "$2"):/config.yaml:ro" \
        -e NEXUS_URL \
        -e NEXUS_USERNAME \
        -e NEXUS_PASSWORD \
        "$CRAY_NEXUS_SETUP_IMAGE" \
        "nexus-${1}-create" /config.yaml
}

# usage: nexus-wait-for-rpm-repomd REPOSITORY [INTERVAL=5]
#
# Waits for RPM repository metadata to exist for given REPOSITORY.
#
# Nexus automatically computes RPM repository metadata for yum repositories.
# Immediately trying to upload RPMs to a yum repository may fail until Nexus
# generates the initial repository metadata. This function checks for
# repodata/repomd.xml to exist from the repository's root path before
# returning. It sleeps INTERVAL seconds (default: 5) in between checks.
#
# Requires the following environment variables to be set:
#
#   NEXUS_URL - Base Nexus URL; defaults to https://packages.local
#
# If the NEXUS_PASSWORD environment variable is not set, attempts to set
# NEXUS_USERNAME and NEXUS_PASSWORD based on the nexus-admin-credential
# Kubernetes secret. Otherwise, the default Nexus admin credentials are used.
function nexus-wait-for-rpm-repomd() {
    nexus-setdefault-credential
    podman run --rm "${podman_run_flags[@]}" \
        -e NEXUS_URL \
        -e NEXUS_USERNAME \
        -e NEXUS_PASSWORD \
        "$CRAY_NEXUS_SETUP_IMAGE" \
        "nexus-wait-for-rpm-repomd" "${@}"
}

# usage: nexus-upload (helm|raw|yum) DIRECTORY REPOSITORY
#
# Uploads a DIRECTORY of assets to the specified Nexus REPOSITORY.
#
# The REPOSITORY must be of the specified format (i.e., helm, raw, yum) else
# the upload may not succeed or select the proper files under the given
# DIRECTORY.
#
# Requires the following environment variables to be set:
#
#   NEXUS_URL - Base Nexus URL; defaults to https://packages.local
#   CRAY_NEXUS_SETUP_IMAGE - Image containing Cray's Nexus setup tools;
#       recommended to vendor with tag specific to a product version
#
# If the NEXUS_PASSWORD environment variable is not set, attempts to set
# NEXUS_USERNAME and NEXUS_PASSWORD based on the nexus-admin-credential
# Kubernetes secret. Otherwise, the default Nexus admin credentials are used.
function nexus-upload() {
    local repotype="$1"
    local src="$2"
    local reponame="$3"

    [[ -d "$src" ]] || return 0

    nexus-setdefault-credential
    podman run --rm "${podman_run_flags[@]}" \
        -v "$(realpath "$src"):/data:ro" \
        -e NEXUS_URL \
        -e NEXUS_USERNAME \
        -e NEXUS_PASSWORD \
        "$CRAY_NEXUS_SETUP_IMAGE" \
        "nexus-upload-repo-${repotype}" "/data/" "$reponame"
}

# usage: skopeo-sync DIRECTORY
#
# Uploads a DIRECTORY of container images to the Nexus registry.
#
# Requires the following environment variables to be set:
#
#   NEXUS_REGISTRY - Hostname of Nexus registry; defaults to registry.local
#   SKOPEO_IMAGE - Image containing Skopeo tool; recommended to vendor with tag
#       specific to a product version
#
# If the NEXUS_PASSWORD environment variable is not set, attempts to set
# NEXUS_USERNAME and NEXUS_PASSWORD based on the nexus-admin-credential
# Kubernetes secret. Otherwise, the default Nexus admin credentials are used.
function skopeo-sync() {
    local src="$1"

    [[ -d "$src" ]] || return 0

    nexus-setdefault-credential
    # Note: Have to default NEXUS_USERNAME below since
    # nexus-setdefault-credential returns immediately if NEXUS_PASSWORD is set.
    podman run --rm "${podman_run_flags[@]}" \
        -v "$(realpath "$src"):/image:ro" \
        "$SKOPEO_IMAGE" \
        sync --scoped --src dir --dest docker \
        --dest-creds "${NEXUS_USERNAME:-admin}:${NEXUS_PASSWORD}" \
        --dest-tls-verify=false \
        /image "$NEXUS_REGISTRY"
}
