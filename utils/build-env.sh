#!/bin/sh

BUILD_DIR=${1:-./build/venv}

CURR_DIRR=${PWD}


function error(){
    echo >&2 "ERROR: $1"
    exit 1
}


PIP="pip-3"

if type pip-3 >/dev/null 2>&1; then
    PIP="pip"
fi

type virtualenv >/dev/null 2>&1 || $PIP install virtualenv

PYTHONS="python3.8 python3.7 python3.6 python3.5 python3"
PYTHON=""

for P in $PYTHONS; do
    if type $P >/dev/null 2>&1; then
        PYTHON=$P
        break
    fi
done

if [[ -z "$PYTHON" ]];  then
    error "Unable to find python 3.5+ binary, aborting"
fi

mkdir -p $BUILD_DIR

cd $BUILD_DIR

virtualenv -p $PYTHON .

source bin/activate

git clone --single-branch --branch master ssh://git@stash.us.cray.com:7999/cloud/manifestgen.git

pip install ./manifestgen

cd $CURR_DIRR
