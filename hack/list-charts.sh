#!/usr/bin/env bash

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."

find "${ROOTDIR}/manifests" -name '*.yaml' -exec yq r --stripComments '{}' 'spec.charts' \; \
  | yq r -j - \
  | jq -S 'map({(.name): [(.version)]}) | add' \
  | yq r --prettyPrint -
