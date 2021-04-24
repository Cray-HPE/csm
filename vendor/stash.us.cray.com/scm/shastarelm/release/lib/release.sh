#!/usr/bin/env bash

# Copyright 2020 Hewlett Packard Enterprise Development LP

: "${PACKAGING_TOOLS_IMAGE:=arti.dev.cray.com/internal-docker-stable-local/packaging-tools:0.7.0}"
: "${RPM_TOOLS_IMAGE:=arti.dev.cray.com/internal-docker-stable-local/rpm-tools:1.0.0}"
: "${SKOPEO_IMAGE:=quay.io/skopeo/stable:latest}"
: "${CRAY_NEXUS_SETUP_IMAGE:=arti.dev.cray.com/csm-docker-stable-local/cray-nexus-setup:0.5.2}"

# Prefer to use docker, but for environments with podman
if [[ "${USE_PODMAN_NOT_DOCKER:-"no"}" == "yes" ]]; then
    echo >&2 "warning: using podman, not docker"
    shopt -s expand_aliases
    alias docker=podman
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

requires docker realpath

# usage: generate-nexus-config (blobstore|repository) FILE
#
# Generates complete Nexus configuration for blobstores and repositories given
# an existing "template".
function generate-nexus-config() {
    docker run --rm -i "$PACKAGING_TOOLS_IMAGE" generate-nexus-config "$@"
}

# usage: helm-sync INDEX DIRECTORY
#
# Syncs the helm charts listed in the specified INDEX to the given DIRECTORY.
function helm-sync() {
    local index="$1"
    local destdir="$2"

    [[ -d "$destdir" ]] || mkdir -p "$destdir"

    docker run --rm -u "$(id -u):$(id -g)" \
        ${DOCKER_NETWORK:+"--network=${DOCKER_NETWORK}"} \
        -v "$(realpath "$index"):/index.yaml:ro" \
        -v "$(realpath "$destdir"):/data" \
        "$PACKAGING_TOOLS_IMAGE" \
        helm-sync -n "${HELM_SYNC_NUM_CONCURRENT_DOWNLOADS:-1}" /index.yaml /data
}

# usage: rpm-sync INDEX DIRECTORY
#
# Syncs RPMs listed in the specified INDEX to the given DIRECTORY.
function rpm-sync() {
    local index="$1"
    local destdir="$2"

    [[ -d "$destdir" ]] || mkdir -p "$destdir"

    docker run --rm -u "$(id -u):$(id -g)" \
        ${DOCKER_NETWORK:+"--network=${DOCKER_NETWORK}"} \
        -v "$(realpath "$index"):/index.yaml:ro" \
        -v "$(realpath "$destdir"):/data" \
        "$PACKAGING_TOOLS_IMAGE" \
        rpm-sync -n "${RPM_SYNC_NUM_CONCURRENT_DOWNLOADS:-1}" -v -d /data /index.yaml
}

# usage: skopeo-sync INDEX DIRECTORY
#
# Syncs the container images listed in the specified INDEX to the given
# DIRECTORY.
function skopeo-sync() {
    local index="$1"
    local destdir="$2"

    [[ -d "$destdir" ]] || mkdir -p "$destdir"

    docker run --rm -u "$(id -u):$(id -g)" \
        ${DOCKER_NETWORK:+"--network=${DOCKER_NETWORK}"} \
        -v "$(realpath "$index"):/index.yaml:ro" \
        -v "$(realpath "$destdir"):/data" \
        "$SKOPEO_IMAGE" \
        sync --src yaml --dest dir --scoped /index.yaml /data
}

# usage: reposync URL DIRECTORY
#
# Syncs the RPM repository at URL to the specified DIRECTORY.
function reposync() {
    local url="$1"
    local name="$(basename "$2")"
    local destdir="$(dirname "$2")"

    [[ -d "$destdir" ]] || mkdir -p "$destdir"

    docker run --rm -u "$(id -u):$(id -g)" \
        ${DOCKER_NETWORK:+"--network=${DOCKER_NETWORK}"} \
        -v "$(realpath "$destdir"):/data" \
        "$RPM_TOOLS_IMAGE" \
        /usr/local/bin/reposync "$name" "$url"
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

    docker run --rm -u "$(id -u):$(id -g)" \
        ${DOCKER_NETWORK:+"--network=${DOCKER_NETWORK}"} \
        -v "$(realpath "$repodir"):/data" \
        "$RPM_TOOLS_IMAGE" \
        createrepo --verbose /data
}

# usage: vendor-install-deps [--no-cray-nexus-setup] [--no-skopeo] RELEASE DIRECTORY
#
# Vendors installation tools for a specified RELEASE to the given DIRECTORY.
#
# Even though compatible tools may be available on the target system, vendoring
# them ensures sufficient versions are shipped.
function vendor-install-deps() {
    while [[ $# -gt 2 ]]; do
        opt="$1"
        shift
        case "$opt" in
        --no-cray-nexus-setup) include_nexus="no" ;;
        --no-skopeo) include_skopeo="no" ;;
        --) break ;;
        --*) echo >&2 "error: unsupported option: $opt"; exit 2 ;;
        *)  break ;;
        esac
    done

    local release="$1"
    local destdir="$2"

    [[ -d "$destdir" ]] || mkdir -p "$destdir"

    if [[ "${include_nexus:-"yes"}" == "yes" ]]; then
        docker run --rm -u "$(id -u):$(id -g)" \
            ${DOCKER_NETWORK:+"--network=${DOCKER_NETWORK}"} \
            -v "$(realpath "$destdir"):/data" \
            "$SKOPEO_IMAGE" \
            copy "docker://${CRAY_NEXUS_SETUP_IMAGE}" "docker-archive:/data/cray-nexus-setup.tar:cray-nexus-setup:${release}" || return
    fi

    if [[ "${include_skopeo:-"yes"}" == "yes" ]]; then
        docker run --rm -u "$(id -u):$(id -g)" \
            ${DOCKER_NETWORK:+"--network=${DOCKER_NETWORK}"} \
            -v "$(realpath "$destdir"):/data" \
            "$SKOPEO_IMAGE" \
            copy "docker://${SKOPEO_IMAGE}" "docker-archive:/data/skopeo.tar:skopeo:${release}"
    fi
}

# usage: gen-version-sh RELEASE_NAME RELEASE_VERSION
#
# Generates version.sh script that outputs the specified RELEASE_NAME and/or
# RELEASE_VERSION.
function gen-version-sh() {
    cat <<EOF
#!/usr/bin/env bash

# Copyright 2020 Hewlett Packard Enterprise Development LP

: "\${RELEASE:="\${RELEASE_NAME:="${1}"}-\${RELEASE_VERSION:="${2}"}"}"

# return if sourced
return 0 2>/dev/null

# otherwise print release information
if [[ \$# -eq 0 ]]; then
    echo "\$RELEASE"
else
    case "\$1" in
    -n|--name) echo "\$RELEASE_NAME" ;;
    -v|--version) echo "\$RELEASE_VERSION" ;;
    *)
        echo >&2 "error: unsupported argumented: \$1"
        echo >&2 "usage: \${0##*/} [--name|--version]"
        ;;
    esac
fi
EOF
}
