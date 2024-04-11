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

# usage: load-install-deps
#
# Loads vendored images into podman's image storage to facilitate installation.
# Product install scripts should call this function before using any functions
# which use CRAY_NEXUS_SETUP_IMAGE or SKOPEO_IMAGE to interact with Nexus.
#
# Product install scripts should call `clean-install-deps` when finished to
# remove images loaded into podman.
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

    if [[ -f "${ROOTDIR}/vendor/rpm-tools.tar" ]]; then
        [[ -v RPM_TOOLS_IMAGE ]] || RPM_TOOLS_IMAGE="$(load-vendor-image "${ROOTDIR}/vendor/rpm-tools.tar")" || return
        vendor_images+=("$RPM_TOOLS_IMAGE")
    fi
}

# usage: load-cfs-config-util
#
# Loads the vendored cfs-config-util container image TARFILE into podman's
# image storage to facilitate updating CFS configurations.
#
# A script that uses the `cfs-config-util` functions in this file should call
# this function first and should call `clean-install-deps` at the end to remove
# images loaded into podman.
function load-cfs-config-util() {
    if [[ -f "${ROOTDIR}/vendor/cfs-config-util.tar" ]]; then
        [[ -v CFS_CONFIG_UTIL_IMAGE ]] || CFS_CONFIG_UTIL_IMAGE="$(load-vendor-image "${ROOTDIR}/vendor/cfs-config-util.tar")" || return
        vendor_images+=("$CFS_CONFIG_UTIL_IMAGE")
    fi
}

# usage: clean-install-deps
#
# Removes images from podman's image storage which have been loaded by the
# `load-install-deps` or `load-cfs-config-util` functions.
#
# Should be called at the end of product install scripts.
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
# Ensures NEXUS_USERNAME and NEXUS_PASSWORD are set, throws error if not.
#
function nexus-setdefault-credential() {
    [[ -v NEXUS_PASSWORD && -n "$NEXUS_PASSWORD" ]] && return 0
    if ! nexus-get-credential; then
        echo >&2 "warning: Nexus admin credential not detected"
	    return 1
    fi
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
        sync --scoped --retry-times 10 --all \
        --src dir --dest docker \
        --dest-creds "${NEXUS_USERNAME:-admin}:${NEXUS_PASSWORD}" \
        --dest-tls-verify=false \
        /image "$NEXUS_REGISTRY"
}

# usage: skopeo-copy SOURCE DESTINATION
#
# Uses skopeo copy to copy an image within the registry.
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
function skopeo-copy() {
    local src="$1"
    local dest="$2"

    if [[ -z "$src" || -z "$dest" ]]; then
        echo >&2 "usage: skopeo-copy SOURCE DESTINATION"
        return 1
    fi

    nexus-setdefault-credential
    # Note: Have to default NEXUS_USERNAME below since
    # nexus-setdefault-credential returns immediately if NEXUS_PASSWORD is set.
    podman run --rm "${podman_run_flags[@]}" \
        "$SKOPEO_IMAGE" \
        copy \
        --all \
        --src-tls-verify=false \
        --dest-tls-verify=false \
        --src-creds "${NEXUS_USERNAME:-admin}:${NEXUS_PASSWORD}" \
        --dest-creds "${NEXUS_USERNAME:-admin}:${NEXUS_PASSWORD}" \
        "docker://${NEXUS_REGISTRY}/${src}" \
        "docker://${NEXUS_REGISTRY}/${dest}"
}

# usage: cfs-config-util-options-help
#
# Outputs information about the passthrough options accepted by the
# cfs-config-util container image. These are options which can be specified by
# the admin calling the installation script in the product which are then
# passed through directly to the cfs-config-util container entrypoint.
#
function cfs-config-util-options-help() {
    podman run --rm --name cfs-config-util-options-help --entrypoint=passthrough-options-help \
        "${CFS_CONFIG_UTIL_IMAGE}"
}

# usage: cfs-config-util-process-opts [options]
#
# Pre-processes the options being passed to cfs-config-util. This finds any
# options which require local file access and determines the appropriate mount
# options needed when calling `podman`. It also then modifies any file paths in
# the cfs-config-util options to point at the locations where those files will
# be mounted inside the container.
#
# Outputs a JSON object with the following keys:
#
#   mount_options:      A string containing the mount options that should be
#                       passed to `podman`.
#   translated_args:    The cfs-config-util options with any file paths
#                       translated appropriately.
#
function cfs-config-util-process-opts() {
    podman run --rm --name cfs-config-util-process-opts --entrypoint=process-file-options \
        "${CFS_CONFIG_UTIL_IMAGE}" "$@"
}

# usage: cfs-config-util [options]
#
# Run the cfs-config-util container under podman. Run this function with `-h`
# to see the full usage information for the options understood by this utility.
#
# All arguments passed to this function are passed through to the underlying
# cfs-config-util container's main entry point.
#
# Returns:
#   0 if successful
#   1 if the call to cfs-config-util to update the CFS configurations failed
#   2 if the options passed to cfs-config-util could not be parsed
#
function cfs-config-util() {
    local err_temp_file="$(mktemp /tmp/cfs-config-util-process-opts-err-XXXXX)"
    local out_temp_file="$(mktemp /tmp/cfs-config-util-process-opts-out-XXXXX)"
    cfs-config-util-process-opts "$@" 1>"${out_temp_file}" 2>"${err_temp_file}"
    local rc=$?

    if [[ $rc -ne 0 ]]; then
        # The name of the script calling this function is $0
        local script_name="$(basename "$0")"
        # Substitute the name of the script in the usage info error message
        sed -e "s/process-file-options/${script_name}/" < $err_temp_file
        rm $err_temp_file $out_temp_file
        return 2
    fi

    local podman_cli_args="--mount type=bind,src=/etc/kubernetes/admin.conf,target=$HOME/.kube/config,ro=true"
    podman_cli_args+=" --mount type=bind,src=/etc/pki/trust/anchors,target=/usr/local/share/ca-certificates,ro=true"
    podman_cli_args+=" $(jq -r '.mount_opts' < "$out_temp_file")"

    local translated_args="$(jq -r '.translated_args' < "$out_temp_file")"
    rm $err_temp_file $out_temp_file

    if ! podman run --rm --name cfs-config-util $podman_cli_args "${CFS_CONFIG_UTIL_IMAGE}" ${translated_args}; then
        return 1
    fi
}

# usage: createrepo DIRECTORY
#
# Creates an RPM repository from RPMs under the specified DIRECTORY.
#
# Useful when using rpm-sync to copy RPMs from various upstream repositories
# to a single directory.
function createrepo() {
    local repodir="$1"

    if [[ ! -d "$repodir" ]]; then
        echo >&2 "error: no such directory: ${repodir}"
        return 1
    fi

    podman run --rm "${podman_run_flags[@]}" \
        ${DOCKER_NETWORK:+"--network=${DOCKER_NETWORK}"} \
        -v "$(realpath "$repodir"):/data" \
        "$RPM_TOOLS_IMAGE" \
        createrepo --verbose /data
}
