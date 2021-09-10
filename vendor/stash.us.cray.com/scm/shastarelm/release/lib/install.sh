#!/usr/bin/env bash

# Copyright 2020-2021 Hewlett Packard Enterprise Development LP

# Defaults
# TODO grab these from customizations.yaml?
: "${NEXUS_URL:="https://packages.local"}"
: "${NEXUS_REGISTRY:="registry.local"}"

# Set ROOTDIR to reasonable default, assumes this script is in a subdir (e.g., lib)
: "${ROOTDIR:="$(dirname "${BASH_SOURCE[0]}")/.."}"

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

requires find podman realpath

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

vendor_images=()

function load-install-deps() {
    # Load vendor images to support installation.
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
    # Clean images used to support installation.
    for image in "${vendor_images[@]}"; do
        podman rmi -f "$image"
    done
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
function nexus-setup() {
    podman run --rm --network host --dns "$3"\
        -v "$(realpath "$2"):/config.yaml:ro" \
        -e "NEXUS_URL=${NEXUS_URL}" \
        "$CRAY_NEXUS_SETUP_IMAGE" \
        "nexus-${1}-create" /config.yaml
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
function nexus-upload() {
    local repotype="$1"
    local src="$2"
    local reponame="$3"
    local dns="$4"

    [[ -d "$src" ]] || return 0

    podman run --rm --network host --dns "$dns"\
        -v "$(realpath "$src"):/data:ro" \
        -e "NEXUS_URL=${NEXUS_URL}" \
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
#       specific to a product version.
#
function skopeo-sync() {
    local src="$1"
    local dns="$2"

    find "$src" -mindepth 1 -maxdepth 1 -type d | while read path; do
        podman run --rm --network host --dns "$dns"\
            -v "$(realpath "$path"):/image:ro" \
            "$SKOPEO_IMAGE" \
            sync --scoped --src dir --dest docker --dest-tls-verify=false /image "${NEXUS_REGISTRY}" || return
    done
}
