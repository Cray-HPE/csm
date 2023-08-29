#!/usr/bin/env bash

: "${SKOPEO_IMAGE:=artifactory.algol60.net/csm-docker/stable/quay.io/skopeo/stable:v1.4.1}"
: "${YQ_IMAGE:=artifactory.algol60.net/docker.io/mikefarah/yq:4}"

if [ -z "${ARTIFACTORY_USER}" ] || [ -z "${ARTIFACTORY_TOKEN}" ]; then
    echo "Missing authentication information for image download. Please set ARTIFACTORY_USER and ARTIFACTORY_TOKEN environment variables."
    exit 1
fi
