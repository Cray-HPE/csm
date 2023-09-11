#!/usr/bin/env bash

set -e -o pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 images.yaml"
    exit 1
fi

ROOTDIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")/../..")
source "${ROOTDIR}/common.sh"

cat "${1}" | ${YQ} e '.*.images.*.[] | ((path | (.[0] + "/" + .[2])) + ":" + .)'
