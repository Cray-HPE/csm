#!/usr/bin/env bash

set -e -o pipefail

ROOTDIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")/../..")
source "${ROOTDIR}/common.sh"

docker pull "${YQ_IMAGE}"
docker pull "${SKOPEO_IMAGE}"