#!/usr/bin/env bash

set -eo pipefail

SRCDIR="$(dirname "${BASH_SOURCE[0]}")"
. "${SRCDIR}/common.sh"

ROOTDIR="${SRCDIR}/../.."

function extract-repos() {
    docker run --rm -i "$YQ_IMAGE" e -N '.spec.sources.charts[] | select(.type == "repo") | .name + " " + .location' - < "$1"
}

function extract-charts() {
    docker run --rm -i "$YQ_IMAGE" e -N -o json '.spec.charts' - < "$1" \
    | jq -r '.[] | (.releaseName // .name) + "\t" + (.source) + "\t" + (.name) + "\t" + (.version) + "\t" + (.values | [paths(scalars) as $path | {"key": $path | join("."), "value": getpath($path)}] | map("\(.key)=\(.value|tostring)") | join(","))'
}

function get-customizations() {
    docker run --rm -i "$YQ_IMAGE" e -o json - < "${ROOTDIR}/validate.customizations.yaml" \
    | jq -r --arg chart "$1" '.[$chart] | [paths(scalars) as $path | {"key": $path | join("."), "value": getpath($path)}] | map("\(.key)=\(.value|tostring)") | join(",")'
}

function extract-images() {
    local -a args=("$1/$2")
    [[ $# -ge 3 ]] && args+=(--version "$3")

    VER="${3:-NA}"

    echo >&2 "+ ${args[@]}"

    local -a flags=()
    [[ -n "$4" ]] && flags+=(--set "$4")

    local -a cacheflags=()
    if [[ -n "$5" ]]; then
        cachefile="$5"
        mkdir -p "$(dirname "$5")"
        cacheflags+=("$5")
        chartmap="$(dirname "$5")/chartmap.csv"
    fi

    customizations="$(get-customizations "$2")"
    [[ -n "$customizations" ]] && flags+=(--set "$customizations")

    {   parallel --nonall --retries 5 --delay 5 helm show chart "${args[@]}" | docker run --rm -i "$YQ_IMAGE" e -N '.annotations."artifacthub.io/images"' -
        echo '---'
        parallel --nonall --retries 5 --delay 5 helm template "${args[@]}" --generate-name --dry-run --set "global.chart.name=${2}" --set "global.chart.version=${3}" "${flags[@]}" | tee "${cacheflags[@]}"
    } | docker run --rm -i "$YQ_IMAGE" e -N '.. | .image? | select(.)' - \
      | sort -u | sed -e '/^image: null$/d' -e '/^type: string$/d' \
      | tee >(cat -n 1>&2) >(cat 2>&1 | xargs -n 1 ./inspect.sh 2> /dev/null | cut -f 1 | sed -e "s|^|$(basename $manifest | cut -d. -f 1),$1/$2:$VER,|g" >> $chartmap)
    
}


function usage() {
    echo >&2 "usage: ${0##*/} MANIFEST [CHART ...]"
    exit 1
}

[[ $# -gt 0 ]] || usage

manifest="$1"
shift

if [[ $# -gt 0 ]]; then
    function filter-releases() {
        local e match="$1"
        shift
        for e; do [[ "$e" == "$match" ]] && return 0; done
        return 1
    }
else
    function filter-releases() {
        return 0
    }
fi

manifest_name="$(docker run --rm -i "$YQ_IMAGE" e -N '.metadata.name' - < "$manifest")"
cachedir="${ROOTDIR}/build/images/charts/${manifest_name}"
echo >&2 "+ ${manifest} [cache: ${cachedir}]"

helm env >&2

# clean up existing repos
#helm repo list -o yaml | docker run --rm -i "$YQ_IMAGE" e '.[] | .name' - | xargs --verbose -n 1 helm repo remove

# Update helm repos
extract-repos "$manifest" | while read name url; do
    echo >&2 "+ helm repo add $name $url"
    helm repo add --force-update "$name" "$url" >&2
    helm repo update --fail-on-repo-update-fail "$name" >&2
done

# extract images from chart
declare -i idx=0
extract-charts "$manifest" | while read release repo chart version values; do
    cachefile="${cachedir}/$(printf '%02d' $idx)-${release}-${version}.yaml"
    ((idx++)) || true
    filter-releases "$chart" "$@" || continue
    extract-images "$repo" "$chart" "$version" "$values" "$cachefile"
done | sort -u
cat "${cachedir}/chartmap.csv" >> "chartmap.csv"
