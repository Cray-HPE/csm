#!/bin/bash
# Copyright 2020, Cray Inc.

ROOT_DIR="$(dirname $0)/.."
ROOT_DIR="$(pushd "$ROOT_DIR" > /dev/null && pwd && popd > /dev/null)"

function usage(){
    cat <<EOF
Usage:
    migrate.sh PACKAGE_FILE

    migrate.sh package.tgz

    Will migrate an existing shasta-cfg directory to that of a new one. It's
    important to remember only missing fields are added to customizations.yaml,
    it is also prudent to do a diff of customizations.yaml to determine if you
    want/need to bring in any other changes.

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


PACKAGE_FILE=${1:-PACKAGE_FILE}

if [[ -z "$PACKAGE_FILE" ]]; then
    error "PACKAGE_FILE is required"
fi

if [[ ! -f "$PACKAGE_FILE" ]]; then
    error "PACKAGE_FILE must be a gzipped tar file"
fi

TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" 0
CURR_DIR=$PWD

cp "$PACKAGE_FILE" "$TEMP_DIR/package.tgz"

cd $TEMP_DIR

tar -xzvf package.tgz

# Call the packages initialization script to merge it into ours.
$TEMP_DIR/shasta-cfg/meta/init.sh $ROOT_DIR
