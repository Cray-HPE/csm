#!/usr/bin/env bash

set -eo pipefail

ROOTDIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")/../..")
source "${ROOTDIR}/common.sh"

function extract-repos() {
    yq e -N '.spec.sources.charts[] | select(.type == "repo") | .name + " " + .location' - < "$1"
}

function extract-charts() {
    # The following will output a tab separated values (TSV) of:
    # 0. Release Name
    # 1. Helm chart source
    # 2. Helm chart name
    # 3. Helm chart version
    # 4. Helm chart value overrides in base64 encoded JSON.
    yq e -N -o json '.spec.charts' - < "$1" \
    | jq -r '.[] | (.releaseName // .name) + "\t" + (.source) + "\t" + (.name) + "\t" + (.version) + "\t" + (.values | @base64)'
}

function get-customizations() {
    yq e -o json - < "${ROOTDIR}/validate.customizations.yaml" \
    | jq -r --arg chart "$1" '.[$chart] | [paths(scalars) as $path | {"key": $path | join("."), "value": getpath($path)}] | map("\(.key)=\(.value|tostring)") | join(",")'
}

function extract-images() {
    local -a args

    if [ -n "${CSM_BASE_VERSION}" ]; then
        helm_chart_base="${ROOTDIR}/dist/csm-${CSM_BASE_VERSION}/helm/${2}-${3}.tgz"
        if [ -f "${helm_chart_base}" ]; then
            args=("${helm_chart_base}")
            echo >&2 "+ Using Helm chart ${2}-${3}.tgz from CSM base version ${CSM_BASE_VERSION}"
            # Copy chart from base release to cache directory, where it will be picked up later by release.sh
            # helm show/template commands below will use tgz fle from base, so cache won't be updated
            cp -f "${helm_chart_base}" "${HELM_CACHE_HOME}/repository/"
        else
            echo >&2 "+ Helm chart ${2}-${3}.tgz was not part of CSM base version ${CSM_BASE_VERSION}, will pull new chart from repo"
            args=("$1/$2")
            [[ $# -ge 3 ]] && args+=(--version "$3")
        fi
    else
        args=("$1/$2")
        [[ $# -ge 3 ]] && args+=(--version "$3")
    fi

    VER="${3:-NA}"

    echo >&2 "+ ${args[@]}"

    local -a flags=()

    # Destination file to contain helm chart overrides from the manifest if any are present.
    # If they are not present, then this will just be an empty file.
    valuesfile="$6"
    mkdir -p "$(dirname "$valuesfile")"

    # Convert the base64 encoded JSON into a YAML file containing the helm chart overrides.
    # Write out the values unmodified to the values file for "helm template" to use with the "-f" option.  
    echo $4 | base64 -d  | yq e -P - > "${valuesfile}"
    flags+=(-f "${valuesfile}")

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

    CHART_SHOW="$(helm show chart "${args[@]}")"
    CHART_TEMPLATE="$(helm template "${args[@]}" --generate-name --dry-run --set "global.chart.name=${2}" --set "global.chart.version=${3}" "${flags[@]}")"

    # Capture helm template output for use in Pluto scanning
    mkdir -p "${ROOTDIR}/build/images/templates/"
    printf "%s\n" "$CHART_TEMPLATE" > "${ROOTDIR}/build/images/templates/${2}-${3}.yaml"

    # echo >&2 "[$(ls -al $HELM_CACHE_HOME/repository/$2-$3.tgz 2>&1 || true)] [$(ls -al $ROOTDIR/dist/csm-${CSM_BASE_VERSION}/helm/$2-$3.tgz 2>&1 || true)]"

    set +o pipefail # Allow pipeline failure execution when attempting to extract images

    ## First: attempt to extract images from chart annotations

    printf "%s\n" "$CHART_SHOW" | yq e -N '.annotations."artifacthub.io/images" | select(.)' - | grep "image:" | awk '{print $NF;}' >> "$IMAGE_LIST_FILE"

    ## Second: attempt to extract images from fully templated manifests (avoiding CRDs)

    # cray-service chart refers to postgresql.connectionPooler image as .dockerImage
    # ClusterPolicy in kyverno-policies chart may have "image:" field which has nothing to do with image definitions
    printf "%s\n" "$CHART_TEMPLATE" | yq e -N 'select(.kind? != "CustomResourceDefinition" and .kind? != "ClusterPolicy") | .. | (.image?, .dockerImage?) | select(type == "!!str")' | tee "${cacheflags[@]}" >> "$IMAGE_LIST_FILE"

    ## Third: support "{image: {repository: aaa, tag: bbb}}" construct from cray-sysmgmt-health chart
    printf "%s\n" "$CHART_TEMPLATE" | yq e -N 'select(.kind? != "CustomResourceDefinition") | .. | select(.image?|type == "!!map") | (.image.repository + ":" + .image.tag)' | tee "${cacheflags[@]}" >> "$IMAGE_LIST_FILE"

    images="$(cat "$IMAGE_LIST_FILE" | sort -u | xargs)"

    set -o pipefail # Re-enable fail on pipeline execution

    unlink "$IMAGE_LIST_FILE"

    for image in $images; do
	    printf "%s\n" "$image" 
        echo "$(basename "$manifest" | cut -d. -f 1),$1/$2:$VER,$image" >> "${chartmap}"
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

manifest_name="$(yq e -N '.metadata.name' - < "$manifest")"
cachedir="${ROOTDIR}/build/images/charts/${manifest_name}"
valuesdir="${ROOTDIR}/build/images/values/${manifest_name}"
echo >&2 "+ ${manifest} [cache: ${cachedir}, values: ${valuesdir}]"

helm env >&2

# clean up existing repos
#helm repo list -o yaml | yq e '.[] | .name' - | xargs --verbose -n 1 helm repo remove

# Update helm repos
extract-repos "$manifest" | while read name url; do
    echo >&2 "+ helm repo add $name $url"
    helm repo add --force-update "$name" "$url" ${ARTIFACTORY_USER+--username ${ARTIFACTORY_USER}} ${ARTIFACTORY_TOKEN+--password ${ARTIFACTORY_TOKEN}} >&2
    helm repo update --fail-on-repo-update-fail "$name" >&2
done

# extract images from chart
declare -i idx=0
extract-charts "$manifest" | while read release repo chart version values; do
    cachefile="${cachedir}/$(printf '%02d' $idx)-${release}-${version}.yaml"
    valuesfile="${valuesdir}/$(printf '%02d' $idx)-${release}-${version}.yaml"
    ((idx++)) || true
    filter-releases "$chart" "$@" || continue
    extract-images "$repo" "$chart" "$version" "$values" "$cachefile" "$valuesfile"
done | sort -u
