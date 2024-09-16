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

SOURCE_FILE=$1
SOURCE_FILE="$(pushd "$(dirname $SOURCE_FILE)" > /dev/null && pwd && popd > /dev/null)/$(basename $SOURCE_FILE)"
TARGET_DIR=${2:-"$(dirname $0)/.."}
TARGET_DIR="$(pushd "$TARGET_DIR" > /dev/null && pwd && popd > /dev/null)"
SECRETS_KEY_FILTER=${3:-"spec.kubernetes.sealed_secrets.*"}
TRACKED_SECRETS_KEY_FILTER=${4:-"spec.kubernetes.tracked_sealed_secrets.*"}
GEN_SECRETS_KEY_FILTER=${5:-"spec.kubernetes.sealed_secrets.*.generate"}
PLAIN_SECRETS_KEY_FILTER=${6:-"spec.kubernetes.sealed_secrets.(kind==Secret)"}

TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" 0

TARGET_FILE=$TARGET_DIR/$(basename $SOURCE_FILE)
TEMP_FILE=$TEMP_DIR/customizations.yaml
MIGRATIONS_DIR=$TARGET_DIR/utils/migrations

function usage(){
    cat <<EOF
Usage:
   migrate-customizations.sh SOURCE_FILE [TARGET_DIR [KEY_FILTER] ]

   migrate-customizations.sh /tmp/stable_customizations.yaml

   Will merge the source file with the target directory, which defaults to ..
   of the location of this script.

   If the target file does not exist, this is just a cp source target

   IMPORTANT: You likely want to call secrets-gen-random.sh after calling this
    to generate any required secrets.

EOF
}

function error(){
    usage
    echo >&2 "ERROR: $*"
    exit 1
}

[ -z "$SOURCE_FILE" ] && error "Please pass in a source file to migrate with."
[ -z "$TARGET_DIR" ] && error "Please pass in a target directory."
[ -z "$SECRETS_KEY_FILTER" ] && error "Please pass in a key filter."

set -e

UNAME="$(uname | awk '{print tolower($0)}')"
# Note, there are MANY projects that claim the yq binary name
# to prevent oddities between them we ship the one we need here.
YQ="${TARGET_DIR}/utils/bin/${UNAME}/yq"
$YQ --version >/dev/null 2>&1 || error "yq is required but it's not installed. Aborting."

MIGRATION_FILES=$(ls $MIGRATIONS_DIR|grep -v '.complete')

if [[ ! -f "$TARGET_FILE" ]]
then
    cp "$SOURCE_FILE" "$TARGET_DIR"
    # Create a .complete file for each migration. Migrations are only needed
    # to migrate existing files, for new initializations, we assume our source
    # repo has already had the migrations applied and we don't want to rerun
    # and inadvertently cause issues.
    for M in $MIGRATION_FILES; do
      echo "$(date) - skipped during initialization, assumed to be fixed upstream" > "$MIGRATIONS_DIR/${M}.complete"
    done
    exit 0
fi

# Run migration scripts
for M in $MIGRATION_FILES; do
  if [[ ! -f "$MIGRATIONS_DIR/${M}.complete" ]]; then
    echo "Running migration $M"
    "${MIGRATIONS_DIR}/${M}" "$TARGET_FILE" "$YQ" "$SOURCE_FILE"
    date > "$MIGRATIONS_DIR/${M}.complete"
  else
    echo "$M migration previously completed, skipping..."
  fi
done

cp $SOURCE_FILE $TEMP_DIR/customizations.yaml

GEN_SECRETS=$($YQ r --printMode p $TEMP_FILE "$GEN_SECRETS_KEY_FILTER")
PLAIN_SECRETS=$($YQ r --printMode p $TEMP_FILE "$PLAIN_SECRETS_KEY_FILTER")
TRACKED_SECRETS=$($YQ r $TEMP_FILE "$TRACKED_SECRETS_KEY_FILTER")
SECRETS=$($YQ r --printMode p $TEMP_FILE "$SECRETS_KEY_FILTER")
SECRETS_KEY_FILTER_STRIPPED=${SECRETS_KEY_FILTER/\*/}

PLAIN_SECRETS_SHORT="${PLAIN_SECRETS//"$SECRETS_KEY_FILTER_STRIPPED"/}"
GEN_SECRETS_SHORT="${GEN_SECRETS//"$SECRETS_KEY_FILTER_STRIPPED"/}"
GEN_SECRETS_SHORT="${GEN_SECRETS_SHORT//.generate/}"

PLAIN_DUPS="$(comm -3 <(echo $PLAIN_SECRETS_SHORT | sort | xargs -n 1) <(echo $PLAIN_SECRETS_SHORT | sort -u | xargs -n 1) | wc -l)"
GEN_DUPS="$(comm -3 <(echo $GEN_SECRETS_SHORT | sort | xargs -n 1) <(echo $GEN_SECRETS_SHORT | sort -u | xargs -n 1) | wc -l)"
PLAIN_GEN_INTERSECT="$(comm -12 <(echo $PLAIN_SECRETS_SHORT | sort | xargs -n 1) <(echo $GEN_SECRETS_SHORT | sort -u | xargs -n 1) | wc -l)"

# Make sure no intersection between plain and generated
# brute force without using intermediate lists/sets

if [ "$PLAIN_DUPS" -gt 0 ]
then
  error "Duplicate plain secret found, please review source and correct."
fi

if [ "$GEN_DUPS" -gt 0 ]
then
  error "Duplicate generated secret found, please review source and correct."
fi

if [ "$PLAIN_GEN_INTERSECT" -gt 0 ]
then
  error "Secret found in both plain and generated secrets, please review source and correct."
fi

# Tracked secrets will always force overwrite
# the secret in the target file.
for D in $TRACKED_SECRETS; do
  K=${SECRETS_KEY_FILTER/\*/$D}
  SECRETS=("${SECRETS[@]/$K}")
  # remove from target file so we pickup the new one
  $YQ d -i "$TARGET_FILE" "$K"
done

# If the target file already has the secret,
# and it is not tracked, remove it from the source
# so that it does not get migrated
for S in $SECRETS; do
    HAS_KEY=$($YQ r $TARGET_FILE "$S" || echo "")
    if [[ ! -z "$HAS_KEY" ]]; then
        echo "Deleting existing sealed secret from source ${S}"
        $YQ d -i $TEMP_FILE ${S}
    fi
done

# If all the secrets are up to date, delete the parent to prevent clearing
# out the target file
if [[ "$($YQ r $TEMP_FILE ${SECRETS_KEY_FILTER/.\*/} --length)" == "0" ]]; then
    $YQ d -i $TEMP_FILE ${SECRETS_KEY_FILTER/.\*/}
fi

$YQ m -i "$TARGET_FILE" "$TEMP_FILE"
