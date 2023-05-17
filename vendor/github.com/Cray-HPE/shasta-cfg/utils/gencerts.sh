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

SEALED_SECRETS_KEY=${SEALED_SECRETS_KEY:-$ROOT_DIR/certs/sealed_secrets.key}
SEALED_SECRETS_CERT=${SEALED_SECRETS_CERT:-$ROOT_DIR/certs/sealed_secrets.crt}
SEALED_SECRETS_REGEN=${SEALED_SECRETS_REGEN:-false}

mkdir -p $(dirname $SEALED_SECRETS_KEY) || echo ""
mkdir -p $(dirname $SEALED_SECRETS_CERT) || echo ""

SCRIPT_DIR=$(dirname "$0")

if [[ (-f "$SEALED_SECRETS_KEY" && -f "$SEALED_SECRETS_CERT") && "$SEALED_SECRETS_REGEN" != "true" ]]
then
    echo "Certs already exist, use SEALED_SECRETS_REGEN=true to regenerate."
    exit 0
fi
pwd
openssl req -x509 -sha256 -subj "/" -nodes -extensions v3_ca -config $SCRIPT_DIR/openssl.cnf -days 365 -newkey rsa:4096 -keyout $SEALED_SECRETS_KEY -out $SEALED_SECRETS_CERT
