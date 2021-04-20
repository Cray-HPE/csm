#!/usr/bin/env bash

while [[ $# -gt 0 ]]; do
    yq r --stripComments "$1" 'spec.charts'
    shift
done | yq r -j - \
  | jq -S 'map({(.name): [(.version)]}) | add' \
  | yq r --prettyPrint -
