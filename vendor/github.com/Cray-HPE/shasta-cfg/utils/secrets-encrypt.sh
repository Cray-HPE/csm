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
