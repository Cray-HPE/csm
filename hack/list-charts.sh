#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

while [[ $# -gt 0 ]]; do
    yq r --stripComments "$1" 'spec.charts'
    shift
done | yq r -j - \
  | jq -S 'map({(.name): [(.version)]}) | add' \
  | yq r --prettyPrint -
