#!/bin/bash
#
# MIT License
#
# (C) Copyright 2023 Hewlett Packard Enterprise Development LP
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
