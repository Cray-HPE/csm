#!/usr/bin/env bash

set -euo pipefail

SRCDIR="$(dirname "${BASH_SOURCE[0]}")"
. "${SRCDIR}/common.sh"

function usage() {
    echo >&2 "usage: ${0##*/} IMAGE DIR"
    exit 255
}

[[ $# -eq 2 ]] || usage

image="${1#docker://}"
destdir="${2#dir:}"

echo >&2 "+ skopeo copy docker://$image dir:$destdir"

# Sync to temporary working directory in case of error
workdir="$(mktemp -d .skopeo-copy-XXXXXXX)"
trap "rm -fr '$workdir'" EXIT

docker run --rm \
    -u "$(id -u):$(id -g)" \
    --mount "type=bind,source=$(realpath "$workdir"),destination=/data" \
    "$SKOPEO_IMAGE" \
    --command-timeout 60s \
    --override-os linux \
    --override-arch amd64 \
    copy \
    --retry-times 5 \
    "docker://$image" \
    dir:/data \
    >&2 || exit 255

# Ensure intermediate directories exist
mkdir -p "$(dirname "$destdir")"

# Ensure destination directory is fresh, which is particularly important
# if there was a previous run
[[ -e "$destdir" ]] && rm -fr "$destdir"

# Move image to destination directory
mv "$workdir" "$destdir"
