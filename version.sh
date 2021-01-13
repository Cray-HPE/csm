#!/usr/bin/env bash

set -eo pipefail

git describe --tags --match 'v*' | sed -e 's/^v//'
