#!/bin/sh
# Copyright 2021 Hewlett Packard Enterprise Development LP

ROOT_DIR="$(dirname $0)/.."
ROOT_DIR="$(pushd "$ROOT_DIR" > /dev/null && pwd && popd > /dev/null)"

source $ROOT_DIR/utils/build-env.sh "$ROOT_DIR/build/venv"

# Run whatever in the build env context
$@


