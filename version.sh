#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

set -eo pipefail

git describe --tags --match 'v*' | sed -e 's/^v//'
