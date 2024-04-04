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

SOURCE_DIR="$(dirname $0)/.."
SOURCE_DIR="$(pushd "$SOURCE_DIR" > /dev/null && pwd && popd > /dev/null)"

function usage(){
    cat <<EOF
Usage:
    init.sh TARGET_DIR

    Will create or update a clone of shasta-cfg at TARGET_DIR

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

set -e

TARGET_DIR=${1:-.}
TARGET_DIR="$(pushd "$TARGET_DIR" > /dev/null && pwd && popd > /dev/null)"

if [ -z "$TARGET_DIR" ]
then
      error "TARGET_DIR is required."
fi

if [[ -d "${TARGET_DIR}/meta" ]]
then
    error "This is the meta distribution, skipping bootstrapping."
fi

if [[ ! -d "${SOURCE_DIR}/meta" ]]
then
    error "SOURCE_DIR ($SOURCE_DIR) doesn't look like a meta distribution, skipping bootstrapping."
fi

# Create target directory if it doesn't exist.

mkdir -p "$TARGET_DIR"

# As noted in earlier rev, rsync would probably be a
# better tool to keep TARGET in sync with SOURCE: TODO.

echo "Source Directory is: $SOURCE_DIR"
echo "Target Directory is: $TARGET_DIR"

echo "Copying docs..."
cp -r "$SOURCE_DIR/docs" "$TARGET_DIR"

if [[ -f "$SOURCE_DIR/README.md" ]]; then
    cp "$SOURCE_DIR/README.md" "$TARGET_DIR"
fi

echo "Copying scripts/utils..."
cp -r "$SOURCE_DIR/deploy" "$TARGET_DIR"
cp -r "$SOURCE_DIR/utils" "$TARGET_DIR"

if [[ -f "$SOURCE_DIR/Jenkinsfile.prod" ]]; then
    echo "Copying Jenkinsfile... "
    cp "$SOURCE_DIR/Jenkinsfile.prod" "$TARGET_DIR/Jenkinsfile"
fi

echo "Migrating customizations..."
$TARGET_DIR/utils/migrate-customizations.sh "$SOURCE_DIR/customizations.yaml"

echo "Creating sealed secret key-pair if needed..."
$TARGET_DIR/utils/gencerts.sh

echo "Creating git repo at target (if not already a repo)"
if [[ ! -d "$TARGET_DIR/.git" ]]
then
    echo "Initializing git repository in $TARGET_DIR"
    [ -f "$SOURCE_DIR/.gitignore" ]  && cp "$SOURCE_DIR/.gitignore" "$TARGET_DIR"
    (cd $TARGET_DIR && git init)
fi

echo
echo "**** IMPORTANT: Review and update ${TARGET_DIR}/customizations.yaml and introduce custom edits (if applicable). ****"
