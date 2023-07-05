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

FILE=${1}
OLD_KEY=${2}
NEW_CERT=${3}
SECRETS_KEY=${4:-"spec.kubernetes.sealed_secrets.(kind==SealedSecret)"}
SECRETS_PLAIN_KEY=${5:-"spec.kubernetes.sealed_secrets.(kind==Secret)"}
SECRETS_PLAIN_FIX_KEY=${6:-"spec.kubernetes.sealed_secrets.**.(.==~FIXME~)"}

function usage(){
    cat <<EOF
Usage:
   secrets-reencrypt.sh FILE_TO_REENCRYPT OLD_PRIVATE_KEY NEW_PUBLIC_CERT [KEY_TO_SECRETS]

   secrets-reencrypt.sh ./customizations.yaml ./old/certs/sealed_secrets.key ./certs/sealed_secrets.crt

   Reencrypt secrets to migrate from an old private key to a new one.

EOF
}

function error(){
    usage
    echo >&2 "ERROR: $*"
    exit 1
}

[ -z "$FILE" ] && error "Please pass in a customizations.yaml to reencrypt."
[ -z "$OLD_KEY" ] && error "Please pass in the current private key to decrypt the existing secrets"
[ -z "$NEW_CERT" ] && error "Please pass in the public cert you want to reencrypt with"
[ -z "$SECRETS_KEY" ] && error "Please pass the key to get the sealed secrets from (e.g. '.' for top level)"


TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" 0
CURR_DIR=$PWD
ROOT_DIR="$(dirname $0)/.."
ROOT_DIR="$(pushd "$ROOT_DIR" > /dev/null && pwd && popd > /dev/null)"

UNAME="$(uname | awk '{print tolower($0)}')"

# Note, there are MANY projects that claim the yq binary name
# to prevent oddities between them we ship the one we need here.
YQ="${ROOT_DIR}/utils/bin/${UNAME}/yq"
$YQ --version >/dev/null 2>&1 || error "yq is required but it's not installed. Aborting."

KUBESEAL="${ROOT_DIR}/utils/bin/${UNAME}/kubeseal"
$KUBESEAL --version >/dev/null 2>&1 || error "kubeseal is required but it's not installed. Aborting."

set -e

SECRETS=$($YQ r --printMode p $FILE $SECRETS_KEY)
for S in $SECRETS; do
    # Grab the secret from the key and store into a temp file
    $YQ r -P $FILE $S > $TEMP_DIR/old_secrets.yaml
    # Decrypt the secret with the old private key
    $KUBESEAL --recovery-unseal --recovery-private-key $OLD_KEY <$TEMP_DIR/old_secrets.yaml > $TEMP_DIR/old_secrets_d.yaml
    # Encrypt the secret with the new public cert
    $KUBESEAL --cert $NEW_CERT <$TEMP_DIR/old_secrets_d.yaml | jq -rc '.' > $TEMP_DIR/new_secret.yaml
    # Append the info to the upgrade file to be used later
    cat <<EOF | $YQ r -P - >> $TEMP_DIR/upgrade.yaml
    - command: update
      path: $S
      value:
        $(cat $TEMP_DIR/new_secret.yaml)
EOF
done

PLAIN_SECRETS=$($YQ r --printMode p $FILE $SECRETS_PLAIN_KEY)
PLAIN_SECRETS_TO_FIX_TMP=$($YQ r --printMode p $FILE $SECRETS_PLAIN_FIX_KEY)
PLAIN_SECRETS_TO_ENCRYPT="$PLAIN_SECRETS"
for I in $PLAIN_SECRETS; do
  for J in $PLAIN_SECRETS_TO_FIX_TMP; do
    if [[ "$J" == "$I"* ]]; then
      # The secret has a FIXME so remove it from the list.
      PLAIN_SECRETS_TO_ENCRYPT=("${PLAIN_SECRETS_TO_ENCRYPT[@]/$I}")
    fi
  done
done

for S in $PLAIN_SECRETS_TO_ENCRYPT;do
  $YQ r -j $FILE $S | $ROOT_DIR/utils/secrets-encrypt.sh | $YQ r -j - > $TEMP_DIR/new_secret.yaml

  cat <<EOF | $YQ r -P - >> $TEMP_DIR/upgrade.yaml
    - command: update
      path: $S
      value:
        $(cat $TEMP_DIR/new_secret.yaml)
EOF
done

# Update the file with the new secrets
if [[ -f "$TEMP_DIR/upgrade.yaml" ]]; then
  $YQ w -i -s $TEMP_DIR/upgrade.yaml $FILE
fi
