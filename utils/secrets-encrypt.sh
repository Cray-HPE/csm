#!/bin/bash
# Copyright 2014-2021 Hewlett Packard Enterprise Development LP

function usage(){
    cat <<EOF
Usage:
   echo -n baz | kubectl create secret generic mysecret --dry-run --from-file=bar=/dev/stdin -o json | ./secrets-encrypt.sh >mysealedsecret.yaml

   Will encrypt a kubernetes secret passed in via stdin

EOF
}

function error(){
    usage
    echo >&2 "ERROR: $*"
    exit 1
}

#Will encrypt stdin, expects a kubernetes secret
#Usage:

ROOT_DIR="$(dirname $0)/.."
ROOT_DIR="$(pushd "$ROOT_DIR" > /dev/null && pwd && popd > /dev/null)"
SEALED_SECRETS_CERT=${SEALED_SECRETS_CERT:-$ROOT_DIR/certs/sealed_secrets.crt}

UNAME="$(uname | awk '{print tolower($0)}')"
KUBESEAL="${ROOT_DIR}/utils/bin/${UNAME}/kubeseal"
$KUBESEAL --version >/dev/null 2>&1 || error "kubeseal is required but it's not installed. Aborting."

# --scope cluster-wide should probably not be used,
# but we don't know the namespace at this point
$KUBESEAL --scope cluster-wide -oyaml --cert $SEALED_SECRETS_CERT
