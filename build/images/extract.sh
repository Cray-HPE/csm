#!/usr/bin/env bash

set -eo pipefail

SRCDIR="$(dirname "${BASH_SOURCE[0]}")"
. "${SRCDIR}/common.sh"

ROOTDIR="${SRCDIR}/../.."

P_OPT="--nonall --retries 5 --delay 5 --halt-on-error now,fail=1 "
YQ="docker run --rm -i $YQ_IMAGE"

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

    # Try to enumerate images via annotations and full manifest rendering

    IMAGE_LIST_FILE="$(mktemp)"

    CHART_SHOW="$(parallel $P_OPT helm show chart "${args[@]}")"
    CHART_TEMPLATE="$(parallel $P_OPT helm template "${args[@]}" --generate-name --dry-run --set "global.chart.name=${2}" --set "global.chart.version=${3}" "${flags[@]}")"

    set +o pipefail # Allow pipeline failure execution when attempting to extract images

    ## First: attempt to extract images from chart annotations

    printf "%s\n" "$CHART_SHOW" | $YQ e -N '.annotations."artifacthub.io/images" | select(.)' - | grep "image:" | awk '{print $NF;}' >> "$IMAGE_LIST_FILE"

    ## Second: attempt to extract images from fully templated manifests (avoiding CRDs)

    printf "%s\n" "$CHART_TEMPLATE" | $YQ e -N 'select(.kind? != "CustomResourceDefinition") | .. | .image? | select(.)' | tee "${cacheflags[@]}" >> "$IMAGE_LIST_FILE"

    images="$(cat "$IMAGE_LIST_FILE" | sort -u | xargs)"

    set -o pipefail # Re-enable fail on pipeline execution

    unlink "$IMAGE_LIST_FILE"

    for image in $images; do
	    printf "%s\n" "$image" 
	    ./inspect.sh "$image" | cut -f 1 | sed -e "s|^|$(basename $manifest | cut -d. -f 1),$1/$2:$VER,|g" >> $chartmap
    done | tee >(cat -n 1>&2)

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
    helm repo add --force-update "$name" "$url" ${ARTIFACTORY_USER+--username ${ARTIFACTORY_USER}} ${ARTIFACTORY_TOKEN+--password ${ARTIFACTORY_TOKEN}} >&2
    helm repo update --fail-on-repo-update-fail "$name" >&2
done

parallel $P_OPT docker pull $YQ_IMAGE >&2

# extract images from chart
declare -i idx=0
extract-charts "$manifest" | while read release repo chart version values; do
    cachefile="${cachedir}/$(printf '%02d' $idx)-${release}-${version}.yaml"
    ((idx++)) || true
    filter-releases "$chart" "$@" || continue
    extract-images "$repo" "$chart" "$version" "$values" "$cachefile"
done | sort -u
