#!/usr/bin/env bash

# Copyright 2021,2024 Hewlett Packard Enterprise Development LP

set -eo pipefail

# On integration/* branches, always return X.Y.Z-nightly.1
if [[ "$(git rev-parse --abbrev-ref HEAD)" == integration/* ]]; then
    git describe --tags --match 'v*' | sed -e 's/^v//' | awk -F'[\.-]' '{ print $1 "." $2 "." $3 "-nightly.1"}'
else
    git describe --tags --match 'v*' | sed -e 's/^v//'
fi
