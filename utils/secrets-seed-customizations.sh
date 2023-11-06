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

FILE=${1}
SECRETS_KEY_FILTER=${2:-"spec.kubernetes.sealed_secrets.*.generate"}
SECRETS_GENERATORS_DIR=${SECRETS_GENERATORS_DIR:-"$ROOT_DIR/utils/generators"}

function usage(){
    cat <<EOF
Usage:
    secrets-seed-customizations.sh ./customizations.yaml

    Will find blocks of yaml named 'generate' within the passed in key.
    It will then generate random sealed secrets for those found and replace
    them within the existing file.

    Running this twice consecutively SHOULD be a noop.

    The yaml block must look like the following:

        generate:
          name: "foo"
          data:
            - type: randstr
              args:
                name: bar
                length: 16
            - type: randstr
              args:
                name: baz
                length: 12
            - type: static
              args:
                name: username
                value: admin #static value that isn't sensitive but is required in the secret

    Will create a sealed secret in which would ultimately look like the following
    kuberentes secret:

        apiVersion: v1
        kind: Secret
        metadata:
          creationTimestamp: null
          name: foo
        data:
          bar: M2FiNGJjZjA3YWIwMGIzYzIyMGM2M2Q2YWM0NWU2ZjMK
          baz: NDZmNjM5YmY1MTllZmQzY2NkZmQ1ZjA3Cg==
          username: YWRtaW4K
EOF
}

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    usage
    exit 0
fi

function error(){
    usage
    echo >&2 "ERROR: $*"
    exit 1
}

[ -z "$FILE" ] && error "Please pass in a customizations.yaml to reencrypt."
[ ! -f "$FILE" ] && error "'$FILE' is not a file"
[ -z "$SECRETS_KEY_FILTER" ] && error "Filter to use for finding which secrets need to be generated (e.g. spec.kubernetes.sealed_secrets.*.generate)"


TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" 0
CURR_DIR=$PWD
UNAME="$(uname | awk '{print tolower($0)}')"

# Note, there are MANY projects that claim the yq binary name
# to prevent oddities between them we ship the one we need here.
YQ="${ROOT_DIR}/utils/bin/${UNAME}/yq"
$YQ --version >/dev/null 2>&1 || error "yq is required but it's not installed. Aborting."

set -e

SECRETS=$($YQ r --printMode p $FILE $SECRETS_KEY_FILTER)
for S in $SECRETS; do
    NAME=$($YQ r $FILE "$S.name")
    TYPE=$($YQ r $FILE "$S.type")

    echo "Creating Sealed Secret $NAME"

    SECRET_FILE="${TEMP_DIR}/${NAME}_secret.yaml"

    # K8s secret template
    cat <<EOF > $SECRET_FILE
apiVersion: v1
kind: Secret
metadata:
  name: $NAME
type: $TYPE
EOF

    VALS=$($YQ r --printMode p $FILE "$S.data.*")
    TEMP_FILE="${TEMP_DIR}/${NAME}_vals.yaml"
    touch "$TEMP_FILE"

    # Generate random values for each data field
    # Merge the fields into one yaml file
    for V in $VALS; do
      GEN_TYPE=$($YQ r $FILE "$V.type")
      GENERATOR="${SECRETS_GENERATORS_DIR}/${GEN_TYPE}"
      SBOX=${TEMP_DIR}/$(uuidgen)
      mkdir -p $SBOX
      RAND_FILE="$SBOX/$(uuidgen).yaml"
      touch $RAND_FILE
      # Each generator should return value yaml in k/v pairs to add to a secret
      # The values should be in plaintext (not b64 encoded)
      echo "  Generating type $GEN_TYPE..."
      $GENERATOR "$($YQ r -j $FILE "$V.args")" $YQ $SBOX $RAND_FILE
      # Merge into the rest of the secrets data
      $YQ m -i $TEMP_FILE $RAND_FILE
    done

    # Create a k8s secret with all our data key/value pairs
    $YQ m -i $SECRET_FILE $TEMP_FILE

    # Generate a sealed secert from our k8s secret
    SS_FILE="${TEMP_DIR}/${NAME}_ss.yaml"
    # Note: do this here so that an error in the creation of the secret
    # isn't lost in a $()
    cat $SECRET_FILE | $ROOT_DIR/utils/secrets-encrypt.sh > $SS_FILE

    SS="$(cat $SS_FILE | $YQ r -j -)"

    if [[ ! -z "$SS" ]]; then
      cat <<EOF | $YQ r -P - >> $TEMP_DIR/upgrade.yaml
      - command: update
        path: ${S/.generate/}
        value:
          $SS
EOF
    fi
done

[ -f "$TEMP_DIR/upgrade.yaml" ] && $YQ w -i $FILE -s $TEMP_DIR/upgrade.yaml
