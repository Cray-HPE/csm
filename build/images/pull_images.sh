#!/usr/bin/env bash

set -e -o pipefail

SRCDIR="$(dirname "${BASH_SOURCE[0]}")"
. "${SRCDIR}/common.sh"

docker pull "${YQ_IMAGE}"
docker pull "${SKOPEO_IMAGE}"