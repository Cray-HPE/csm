#!/usr/bin/env bash

# Copyright 2020 Hewlett Packard Enterprise Development LP

# Add cray-internal repo if not already configured
REPO="$(helm repo list -o yaml | yq r - '(url==http://helmrepo.dev.cray.com:8080*).name')"
if [[ -z "$REPO" ]]; then
    REPO="cray-internal"
    echo >&2 "+ Adding Helm repo: $REPO"
    helm repo add "$REPO" "http://helmrepo.dev.cray.com:8080" >&2
else
    echo >&2 "+ Updating Helm repos"
    helm repo update >&2
fi

function list-charts() {
    while [[ $# -gt 0 ]]; do
        yq r --stripComments "$1" 'spec.charts'
        shift
    done | yq r -j - \
         | jq -r '.[] | (.name) + "\t" + (.version) + "\t" + (.values | [paths(scalars) as $path | {"key": $path | join("."), "value": getpath($path)}] | map("\(.key)=\(.value|tostring)") | join(","))' \
         | sort -u
}

function render-chart() {
    echo >&2 "+ Rendering chart: ${1} ${2}"
    if [[ ! -z "$3" ]]; then
        helm template "$1" "${REPO}/${1}" --version "$2" --set ${3}
    else
        helm template "$1" "${REPO}/${1}" --version "$2"
    fi
}

function get-images() {
    yaml=$(</dev/stdin)
    # Images defined in any spec
    echo "$yaml" | yq r -d '*' - 'spec.**.image' | sort -u | grep .

    # Images found in configmap data attributes
    echo "$yaml" | yq r -d '*' - 'data(.==dtr.dev.cray.com/*)' | sort -u | grep .
}

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."

export REPO
export -f render-chart get-images
list-charts "$@"| parallel --group -C '\t' render-chart '{1}' '{2}' '{3}' | get-images
