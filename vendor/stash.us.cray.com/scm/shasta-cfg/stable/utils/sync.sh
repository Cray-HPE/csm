#!/bin/bash
# Copyright 2020, Cray Inc.

ROOT_DIR="$(dirname $0)/.."
ROOT_DIR="$(pushd "$ROOT_DIR" > /dev/null && pwd && popd > /dev/null)"

function usage(){
    cat <<EOF
Usage:
    sync.sh BRANCH_OR_TAG [REPOSITORY_URL]

    sync.sh tags/v1.0.0

    Will sync a remote (stable) repository locally. This is to used for the
    purpose of pulling in new stable manifests, new customizations fields,
    scripts, etc.

    This only stages things locally. The intent is that the users makes any
    required modificataions and opens a PR into their own repo.

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

if [[ -f "$ROOT_DIR/.syncing" ]]; then
    source "$ROOT_DIR/.syncing"
fi

SYNC_TAG_OR_BRANCH=${SYNC_TAG_OR_BRANCH:-master}
SYNC_REPO=${SYNC_REPO:-ssh://git@stash.us.cray.com:7999/shasta-cfg/stable.git}

VERSION=${1:-"$SYNC_TAG_OR_BRANCH"} #branch name OR tags/{tag name}
STABLE_REPO=${2:-"$SYNC_REPO"}

TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" 0
CURR_DIR=$PWD

function checkout(){
    local REPO=$1
    local DIR=$2
    local TAG_OR_BRANCH=$3
    local CURR_DIR=$PWD
    git clone $REPO $DIR
    cd $DIR
    for remote in `git branch -r|grep -v HEAD`; do
        git branch --track ${remote#origin/} $remote || echo "skip"
    done
    git checkout $TAG_OR_BRANCH -b "${TAG_OR_BRANCH/tags\//}-$(uuidgen)"
    cd $CURR_DIR
}

checkout $STABLE_REPO $TEMP_DIR $VERSION

$TEMP_DIR/meta/init.sh $ROOT_DIR
