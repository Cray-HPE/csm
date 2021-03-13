#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

set -eo pipefail

function get-admin-client-secret() {
    echo >&2 "+ Getting admin-client-auth secret"
    kubectl get secrets admin-client-auth -o jsonpath='{.data.client-secret}' | base64 -d
}

function get-token() {
    local client_secret="$(get-admin-client-secret)"
    echo >&2 "+ Obtaining access token"
    curl -sSfk \
        -d grant_type=client_credentials \
        -d client_id=admin-client \
        -d client_secret=${client_secret} \
        'https://api-gw-service-nmn.local/keycloak/realms/shasta/protocol/openid-connect/token' \
    | jq -r '.access_token'
}

function list-ncns() {
    local token="$(get-token)"
    echo >&2 "+ Querying SLS "
    curl -sSfk \
        -H "Authorization: Bearer ${token}" \
        'https://api-gw-service-nmn.local/apis/sls/v1/search/hardware?extra_properties.Role=Management' \
    | jq -r '.[] | .ExtraProperties.Aliases[]' \
    | sort -u
}

list-ncns
