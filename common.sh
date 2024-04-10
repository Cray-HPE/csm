#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2024 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#

export SKOPEO_IMAGE=${SKOPEO_IMAGE:-artifactory.algol60.net/csm-docker/stable/quay.io/skopeo/stable:v1}
export YQ_IMAGE=${YQ_IMAGE:-artifactory.algol60.net/csm-docker/stable/docker.io/mikefarah/yq:4}
export PACKAGING_TOOLS_IMAGE=${PACKAGING_TOOLS_IMAGE:-arti.hpc.amslabs.hpecorp.net/internal-docker-stable-local/packaging-tools:0.13.0}
export RPM_TOOLS_IMAGE=${RPM_TOOLS_IMAGE:-arti.hpc.amslabs.hpecorp.net/internal-docker-stable-local/rpm-tools:1.0.0}

if [ -z "${ARTIFACTORY_USER}" ] || [ -z "${ARTIFACTORY_TOKEN}" ]; then
    echo "Missing authentication information for image download. Please set ARTIFACTORY_USER and ARTIFACTORY_TOKEN environment variables."
    exit 1
fi

REPO_CREDS_DOCKER_OPTIONS=""
REPO_CREDS_RPMSYNC_OPTIONS=""
if [ ! -z "$ARTIFACTORY_USER" ] && [ ! -z "$ARTIFACTORY_TOKEN" ]; then
    #code to store credentials in environment variable
    export REPOCREDSVARNAME="REPOCREDSVAR"
    export REPOCREDSVAR=$(jq --null-input --arg url "https://artifactory.algol60.net/artifactory/" --arg realm "Artifactory Realm" --arg user "$ARTIFACTORY_USER"   --arg password "$ARTIFACTORY_TOKEN"   '{($url): {"realm": $realm, "user": $user, "password": $password}}')
    REPO_CREDS_DOCKER_OPTIONS="-e ${REPOCREDSVARNAME}"
    REPO_CREDS_RPMSYNC_OPTIONS="-c ${REPOCREDSVARNAME}"
fi

export RPM_SYNC="docker run ${REPO_CREDS_DOCKER_OPTIONS} --rm -i ${PACKAGING_TOOLS_IMAGE} rpm-sync ${REPO_CREDS_RPMSYNC_OPTIONS}"
export YQ="docker run --rm -i $YQ_IMAGE"

# Use a newer version of cfs-config-util that hasn't rolled out to other products yet
CFS_CONFIG_UTIL_IMAGE="artifactory.algol60.net/csm-docker/stable/cfs-config-util:5.0.0"
