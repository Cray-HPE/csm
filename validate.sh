#!/usr/bin/env bash

declare -A HELM_REPOS
HELM_REPOS[csm]="https://arti.dev.cray.com/artifactory/csm-helm-stable-local/"
HELM_REPOS[csm-algol60]="https://artifactory.algol60.net/artifactory/csm-helm-charts/"
DEFAULT_HELM_REPO="csm"

HELM_FILE="./helm/index.yaml"
CONTAINER_FILE="./docker/index.yaml"

RPM_INDEX_FILES="rpm/cray/csm/sle-15sp2/index.yaml rpm/cray/csm/sle-15sp2-compute/index.yaml"

HELM_REPOS_INFO="dist/validate/helm-repos.yaml"
LOFTSMAN_MANIFESTS="manifests/*"

SKOPEO_SYNC_DRY_RUN_DIR="dist/docker_dry_run"
DOCKER_TRANSFORM_SCRIPT="./docker/transform.sh"

# List of found images in helm charts that aren't expected to be in docker/index.yaml
EXPECTED_MISSING_HELM_IMAGES=( )

export PATH="${PWD}/dist/validate/bin:$PATH"

function error(){
    echo >&2 "ERROR: $1"
    exit 1
}

set -e

function install_tools(){
    local UNAME="$(uname | awk '{print tolower($0)}')"

    rm -rf dist/validate/bin
    mkdir -p dist/validate/bin

    echo "Install yq"
    wget https://github.com/mikefarah/yq/releases/download/3.3.2/yq_${UNAME}_amd64
    mv yq_${UNAME}_amd64 dist/validate/bin/yq

    echo "Install jq"
    case "$UNAME" in
    darwin)
        wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-osx-amd64
        ;;
    *)
        wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-${UNAME}64
        ;;
    esac
    mv jq-* dist/validate/bin/jq

    chmod +x dist/validate/bin/*
}

function gen_helm_images(){
    echo "Generating helm index"
    echo "##################################################"
    ./hack/gen-helm-index.sh
}

function validate_helm(){
    echo "Validating charts in $HELM_FILE"
    echo "##################################################"
    ./hack/verify-helm-index.sh ${HELM_FILE}
    echo "##################################################"
}

function validate_rpm_index(){
    echo "Validating rpm indexes in $RPM_INDEX_FILES"
    echo "##################################################"
    ./hack/verify-rpm-index.sh ${RPM_INDEX_FILES}
    echo "##################################################"
}

function validate_containers(){
    # There are usually only one repo and one tag per image, so this
    # triple nested loop seems worse than it is. Regardless, refactor if it starts
    # to get out of hand.
    for REPO in $(yq r -p p $CONTAINER_FILE '*'); do
        # These urls are wrapped in quotes from yq because they aren't a simple string
        REPO_STP=$(echo "$REPO" | sed -e 's/^"//' -e 's/"$//')
        IMAGES=$(yq r -p p $CONTAINER_FILE ${REPO}.images.*)
        echo "Validating images in $REPO"
        echo echo "##################################################"
        for IMAGE in $IMAGES; do
            NAME=${IMAGE/${REPO}.images./}
            NAME=$(echo "$NAME" | sed -e 's/^"//' -e 's/"$//')
            VERSIONS=$(yq r $CONTAINER_FILE ${IMAGE}.*)
            for VERSION in $VERSIONS; do
                echo "Validating $NAME: $VERSION"
                FOUND_IMAGE=$(docker run --rm quay.io/skopeo/stable inspect docker://${REPO_STP}/${NAME}:${VERSION} | jq -rc '.RepoTags[] | select (.=="'${VERSION}'")')
                if [[ -z $FOUND_IMAGE ]]; then
                    error "Cannot find tag '$VERSION' for image '$NAME' in $REPO"
                fi
            done
        done
        echo echo "##################################################"
    done
}

# Creates a directory structure similar to what skopeo sync would
# without actually downloading images. Helpful to verify the images
# and versions
function skopeo_sync_dry_run() {
    echo >&2 "+ Running Skopeo sync dry run to generate docker/index.yaml skopeo layout"
    [[ -d "$SKOPEO_SYNC_DRY_RUN_DIR" ]] && rm -rf "$SKOPEO_SYNC_DRY_RUN_DIR"

    mkdir -p "$SKOPEO_SYNC_DRY_RUN_DIR"

    for REPO in $(yq r -p p $CONTAINER_FILE '*'); do
        # These urls are wrapped in quotes from yq because they aren't a simple string
        REPO_STP=$(echo "$REPO" | sed -e 's/^"//' -e 's/"$//')
        mkdir -p $SKOPEO_SYNC_DRY_RUN_DIR/$REPO_STP
        IMAGES=$(yq r -p p $CONTAINER_FILE ${REPO}.images.*)
        for IMAGE in $IMAGES; do
            NAME=${IMAGE/${REPO}.images./}
            NAME=$(echo "$NAME" | sed -e 's/^"//' -e 's/"$//')
            VERSIONS=$(yq r $CONTAINER_FILE ${IMAGE}.*)
            for VERSION in $VERSIONS; do
                mkdir -p $SKOPEO_SYNC_DRY_RUN_DIR/$REPO_STP/$NAME:$VERSION
            done
        done
    done

    echo >&2 "+ Running Docker Transform Script ${DOCKER_TRANSFORM_SCRIPT}"
    echo "====== DEBUG ======="
    ls ${SKOPEO_SYNC_DRY_RUN_DIR}/artifactory.algol60.net/csm-docker/stable
    echo "====== DEBUG ======="
    ${DOCKER_TRANSFORM_SCRIPT} "${SKOPEO_SYNC_DRY_RUN_DIR}"
    
}

function update_helmrepo(){
    for i in "${!HELM_REPOS[@]}"; do
        local REPO_NAME=$i
        local REPO_URL=${HELM_REPOS[$i]}
        echo >&2 "+ Check Helm repo: $REPO_NAME $REPO_URL"
        if [[ -z "$(helm repo list -o json | jq ".[] | select(.url==\"$REPO_URL\") | .name")" ]]; then
            echo >&2 "+ Adding Helm repo: $REPO_NAME $REPO_URL"
            helm repo add "$REPO_NAME" "$REPO_URL" >&2
        fi
    done

    echo >&2 "+ Updating Helm repos"
    helm repo update >&2
}

function list_charts(){
    while [[ $# -gt 0 ]]; do
        yq r --stripComments "$1" 'spec.charts'
        shift
    done | yq r -j - \
         | jq --arg DEFAULT_HELM_REPO "$DEFAULT_HELM_REPO" -r '.[] | (.source // $DEFAULT_HELM_REPO ) + "\t" + (.name) + "\t" + (.version) + "\t" + (.values | [paths(scalars) as $path | {"key": $path | join("."), "value": getpath($path)}] | map("\(.key)=\(.value|tostring)") | join(","))' \
         | sort -u
}

function get_chart_customizations(){
    echo >&2 "Getting chart ${1} customizations"
    local CUSTOMIZATIONS=$(yq r -j validate.customizations.yaml \
    | jq -r --arg CHART "$1" '.[$CHART] | [paths(scalars) as $path | {"key": $path | join("."), "value": getpath($path)}] | map("\(.key)=\(.value|tostring)") | join(",")')

    echo "${CUSTOMIZATIONS}"
}

function render_chart() {
    set -e
    echo >&2 "+ Rendering chart: ${1} ${2} ${3} ${4}"

    local CUSTOMIZATIONS=$(get_chart_customizations $2)

    if [[ ! -z "${CUSTOMIZATIONS}" && ! -z "${4}" ]]; then
        CUSTOMIZATIONS="${4},${CUSTOMIZATIONS}"
    elif [[ ! -z "${4}" ]]; then
        CUSTOMIZATIONS="${4}"
    fi

    if [[ ! -z "${CUSTOMIZATIONS}" ]]; then
        TEMPLATE=$(helm template "$2" "${1}/${2}" --version "$3" --set ${CUSTOMIZATIONS})
    else
        TEMPLATE=$(helm template "$2" "${1}/${2}" --version "$3")
    fi

    IMAGES=$(echo "$TEMPLATE" | get_images)
    echo >&2 "+ Chart: ${2} v${3} Images: (${IMAGES//$'\n'/ })"
    echo >&2 ""
    echo $IMAGES
}

function get_images() {
    yaml=$(</dev/stdin)

    # Images defined in any spec
    IMAGES=( $(echo "$yaml" | yq r -d '*' - 'spec.**.image') )

    # # Images found in configmap data attributes
    IMAGES+=( $(echo "$yaml" | yq r -d '*' - 'data(.==dtr.dev.cray.com/*)') )
    IMAGES+=( $(echo "$yaml" | yq r -d '*' - 'data(.==arti.dev.cray.com/*)') )
    IMAGES+=( $(echo "$yaml" | yq r -d '*' - 'data(.==artifactory.algol60.net/*') )
    IMAGES+=( $(echo "$yaml" | yq r -d '*' - 'data.images_to_cache' | grep dtr.dev.cray.com) )

    echo ${IMAGES[@]} | sort -u
}

function find_images(){
    export HELM_REPO
    export -f render_chart get_images get_chart_customizations
    list_charts "$@" | parallel -j1 --group -C '\t' render_chart '{1}' '{2}' '{3}' '{4}'
}

function validate_manifest_versions(){
    # Validates that found images in helm manifests are also located in docker/index.yaml
    echo "Validating Helm Charts in $LOFTSMAN_MANIFESTS exist in ${HELM_FILE}"
    echo "##################################################"
    json=$(yq r --stripComments -j ${HELM_FILE})
    list_charts ${LOFTSMAN_MANIFESTS} | while read chart; do
        chart_parts=($chart)
        REPO="${chart_parts[0]}"
        NAME="${chart_parts[1]}"
        VERSION="${chart_parts[2]}"
        REPO_URL=${HELM_REPOS["${REPO}"]}
        echo "Checking for helm version $REPO/$NAME:$VERSION"
        if ! echo $json | jq -e --arg REPO_URL "$REPO_URL" --arg NAME "$NAME" --arg VERSION "$VERSION" '.[$REPO_URL].charts[$NAME] | index($VERSION)' &> /dev/null ; then
          error "Missing Helm Chart Version $REPO/$NAME:$VERSION from repo $REPO_URL"
        fi

    done
}

function validate_helm_images(){
    # Validates that found images in helm manifests are also located in docker/index.yaml
    echo "Validating Helm Images in $LOFTSMAN_MANIFESTS exist in ${CONTAINER_FILE}"
    echo "##################################################"
    skopeo_sync_dry_run
    MISSING_IMAGE=0
    IMAGES=$(find_images ${LOFTSMAN_MANIFESTS})
    for IMAGE in $IMAGES; do
      FULL_IMAGE=$(basename $IMAGE)
      IMAGE_PARTS=(${FULL_IMAGE//:/ })
      IMAGE_NAME=${IMAGE_PARTS[0]}
      IMAGE_TAG=${IMAGE_PARTS[1]:=latest}
      IMAGE_PATH=$(dirname $IMAGE)
      ORG=$(basename $IMAGE_PATH)
      echo "Checking for Image: $ORG:${IMAGE_NAME}:${IMAGE_TAG}"
      if [[ ! -z "$IMAGE_NAME" && ! -z "$ORG" && "$ORG" != "." ]]; then
        if [[ ! -d $SKOPEO_SYNC_DRY_RUN_DIR/dtr.dev.cray.com/$ORG/${IMAGE_NAME}:${IMAGE_TAG}  ]]; then
            if [[ "${EXPECTED_MISSING_HELM_IMAGES[@]} " =~ "$ORG:$IMAGE_NAME" ]]; then
                echo "WARNING!! Missing Expected Helm Image: $ORG:${IMAGE_NAME}:${IMAGE_TAG}"
            else
                echo "ERROR!! MISSING Helm Image: $ORG:${IMAGE_NAME}:${IMAGE_TAG}"
                MISSING_IMAGE=1
            fi
        fi
      fi
    done

    if [[ $MISSING_IMAGE -eq 1 ]]; then
        error "Missing helm image(s) found"
    fi
}

# If we pass in an argument just run that
if [[ ! -z "$1" ]]; then
    $1
else
    # Note: Do helm charts first as it is the lesser expensive validation.

    # The build servers have a different version of yq installed
    # so we have to install our own
    install_tools

    ##############
    # Helm Charts
    ##############
    gen_helm_images
    validate_helm

    ##############
    # Rpms
    ##############
    validate_rpm_index

    #############
    # Containers
    #############
    validate_containers

    #############
    # Loftsmans Helm Versions
    #############
    update_helmrepo

    #############
    # Loftsmans Helm Versions
    #############
    validate_manifest_versions

    #############
    # Helm Docker Images
    #############
    validate_helm_images
fi
