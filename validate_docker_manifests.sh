#!/bin/bash

HELM_FILE="./helm/index.yaml"
CONTAINER_FILE="./docker/index.yaml"

HELM_REPOS_INFO="dist/validate/helm-repos.yaml"
HELM_MANIFESTS="manifests/*"

SKOPEO_SYNC_DRY_RUN_DIR="dist/docker_dry_run"
DOCKER_TRANSFORM_SCRIPT="./docker/transform.sh"

# List of found images in helm charts that aren't expected to be in docker/index.yaml
EXPECTED_MISSING_HELM_IMAGES=(
    unguiculus:docker-python3-phantomjs-selenium
    bats:bats
    cray:munge-munge
    cray:cray-aee
)

function error(){
    echo >&2 "ERROR: $1"
    exit 1
}

rm -rf dist/validate
mkdir -p build/validate

set -e

function install_yq(){
    local UNAME="$(uname | awk '{print tolower($0)}')"
    echo "Install yq"
    mkdir -p dist/validate/bin
    wget https://github.com/mikefarah/yq/releases/download/3.3.2/yq_${UNAME}_amd64
    mv yq_${UNAME}_amd64 dist/validate/bin/yq
    chmod +x dist/validate/bin/*
    export PATH="${PWD}/dist/validate/bin:$PATH"
}

function validate_helm(){
    # There are usually only one repo and one version per chart, so this
    # triple nested loop seems worse than it is. Regardless, refactor if it starts
    # to get out of hand.
    for REPO in $(yq r -p p $HELM_FILE '*'); do
        # These urls are wrapped in quotes from yq because they aren't a simple string
        REPO_STP=$(echo "$REPO" | sed -e 's/^"//' -e 's/"$//')
        wget "${REPO_STP}index.yaml" -O "${HELM_REPOS_INFO}"

        echo "Validating charts in $REPO"
        echo "##################################################"
        CHARTS=$(yq r -p p $HELM_FILE ${REPO}.charts.*)
        # Validate that all chart versions exist upstream.
        for CHART in $CHARTS; do
            NAME=${CHART/${REPO}.charts./}
            NAME=$(echo "$NAME" | sed -e 's/^"//' -e 's/"$//')
            VERSIONS=$(yq r $HELM_FILE ${CHART}.*)
            # This is usually just an array of one so being the THIRD nested loop
            # is probably ok.
            for VERSION in $VERSIONS; do
                echo "Validating $NAME: $VERSION"
                FOUND_CHART=$(yq r ${HELM_REPOS_INFO} "entries.${NAME}.(version==${VERSION}).version")
                if [[ -z $FOUND_CHART ]]; then
                    error "Cannot find version '$VERSION' for chart '$NAME' in $REPO"
                fi
            done
        done
        echo "##################################################"
    done
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

    ${DOCKER_TRANSFORM_SCRIPT} "${SKOPEO_SYNC_DRY_RUN_DIR}"
}

function validate_helm_images(){
    # Validates that found images in helm manifests are also located in docker/index.yaml
    echo "Validating Helm Images in $HELM_MANIFESTS exist in ${CONTAINER_FILE}"
    echo "##################################################"
    MISSING_IMAGE=0
    IMAGES=$(./hack/find-images.sh ${HELM_MANIFESTS})
    for IMAGE in $IMAGES; do
      FULL_IMAGE=$(basename $IMAGE)
      IMAGE_PARTS=(${FULL_IMAGE//:/ })
      IMAGE_NAME=${IMAGE_PARTS[0]}
      IMAGE_TAG=${IMAGE_PARTS[1]}
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




# Note: Do helm charts first as it is the lesser expensive validation.

# The build servers have a different version of yq installed
# so we have to install our own
install_yq

##############
# Helm Charts
##############
validate_helm

#############
# Containers
#############
validate_containers

#############
# Helm Images Containers
#############
skopeo_sync_dry_run
validate_helm_images
