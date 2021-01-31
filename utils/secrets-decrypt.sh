#!/bin/bash
# Copyright 2014-2021 Hewlett Packard Enterprise Development LP

ROOT_DIR="$(dirname $0)/.."
ROOT_DIR="$(pushd "$ROOT_DIR" > /dev/null && pwd && popd > /dev/null)"

SECRET_NAME=${1}
PRIVATE_KEY=${2:-"$ROOT_DIR/certs/sealed_secrets.key"}
CUSTOMIZATION_FILE=${3:-"$ROOT_DIR/customizations.yaml"}


function usage(){
    cat <<EOF
Usage:
   secrets-decrypt.sh SECRET_NAME [PRIVATE_KEY [CUSTOMIZATION_FILE]]

   secrets-decrypt.sh example ./certs/sealed_secrets.key ./customizations.yaml

   Decrypts secret so you can alter the values before reencrypting.

EOF
}

function error(){
    usage
    echo >&2 "ERROR: $*"
    exit 1
}

[ -z "$SECRET_NAME" ] && error "Please pass in a secret name."
[ -z "$PRIVATE_KEY" ] && error "Please pass in the current private key to decrypt the existing secrets"
[ -z "$CUSTOMIZATION_FILE" ] && error "Please pass in the path to the customizations.yaml"

SECRET_KEY="spec.kubernetes.sealed_secrets.${SECRET_NAME}"
TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" 0

UNAME="$(uname | awk '{print tolower($0)}')"

# Note, there are MANY projects that claim the yq binary name
# to prevent oddities between them we ship the one we need here.
YQ="${ROOT_DIR}/utils/bin/${UNAME}/yq"
$YQ --version >/dev/null 2>&1 || error "yq is required but it's not installed. Aborting."

KUBESEAL="${ROOT_DIR}/utils/bin/${UNAME}/kubeseal"
$KUBESEAL --version >/dev/null 2>&1 || error "kubeseal is required but it's not installed. Aborting."

set -e

$YQ r $CUSTOMIZATION_FILE $SECRET_KEY > "${TEMP_DIR}/secret.yaml"

$KUBESEAL --recovery-unseal --recovery-private-key $PRIVATE_KEY <"${TEMP_DIR}/secret.yaml"
