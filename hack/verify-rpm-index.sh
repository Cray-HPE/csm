#!/usr/bin/env bash

set -o errexit
set -o pipefail

while [[ $# -gt 0 ]]; do
    cat "$1" | docker run --rm -i arti.dev.cray.com/internal-docker-stable-local/packaging-tools:0.8.0 rpm-sync --dry-run -v -n 32 - >/dev/null
    shift
done
