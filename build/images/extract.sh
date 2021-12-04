#!/usr/bin/env bash


: "${YQ_IMAGE:="artifactory.algol60.net/docker.io/mikefarah/yq:4"}"

set -o errexit
set -o pipefail

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."

function extract-repos() {
    docker run --rm -i "$YQ_IMAGE" e -N '.spec.sources.charts[] | select(.type == "repo") | .name + " " + .location' - < "$1"
}

function extract-charts() {
    docker run --rm -i "$YQ_IMAGE" e -N -o json '.spec.charts' - < "$1" \
    | jq -r '.[] | (.source) + "\t" + (.name) + "\t" + (.version) + "\t" + (.values | [paths(scalars) as $path | {"key": $path | join("."), "value": getpath($path)}] | map("\(.key)=\(.value|tostring)") | join(","))'
}

function get-customizations() {
    docker run --rm -i "$YQ_IMAGE" e -o json - < "${ROOTDIR}/validate.customizations.yaml" \
    | jq -r --arg chart "$1" '.[$chart] | [paths(scalars) as $path | {"key": $path | join("."), "value": getpath($path)}] | map("\(.key)=\(.value|tostring)") | join(",")'
}

function extract-images() {
    local -a args=("$1/$2")
    [[ $# -ge 3 ]] && args+=(--version "$3")

    echo >&2 "+ ${args[@]}"

    local -a flags=()
    [[ -n "$4" ]] && flags+=(--set "$4")

    customizations="$(get-customizations "$2")"
    [[ -n "$customizations" ]] && flags+=(--set "$customizations")

    {   helm show chart "${args[@]}" | docker run --rm -i "$YQ_IMAGE" e -N '.annotations."artifacthub.io/images"' -
        echo '---'
        helm template "${args[@]}" --generate-name --dry-run "${flags[@]}"
    } | docker run --rm -i "$YQ_IMAGE" e -N '.. | .image? | select(.)' - | sort -u | sed -e '/^image: null$/d' -e '/^type: string$/d' | tee >(cat -n 1>&2)
}

[[ $# -eq 0 ]] && set -- "${ROOTDIR}/manifests"/*.yaml

while [[ $# -gt 0 ]]; do
    manifest="$1"
    shift

    echo >&2 "+ $manifest"

    # clean up existing repos
    #helm repo list -o yaml | docker run --rm -i "$YQ_IMAGE" e '.[] | .name' - | xargs --verbose -n 1 helm repo remove

    # Update helm repos
    extract-repos "$manifest" | while read name url; do
        echo >&2 "+ helm repo add $name $url"
        helm repo add --force-update "$name" "$url" >&2
        helm repo update --fail-on-repo-update-fail "$name" >&2
    done

    # extract images from chart
    extract-charts "$manifest" | while read repo chart version values; do
        extract-images "$repo" "$chart" "$version" "$values"
    done
done | sort -u
