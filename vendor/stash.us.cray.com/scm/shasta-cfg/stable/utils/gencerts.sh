#!/bin/bash
# Copyright 2020, Cray Inc.

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
    echo "You SHOULD to take a backup to reencrypt any secrets that from the 'old' key!"
    exit 0
fi

openssl req -x509 -sha256 -subj "/" -nodes -extensions v3_ca -config $SCRIPT_DIR/openssl.cnf -days 365 -newkey rsa:4096 -keyout $SEALED_SECRETS_KEY -out $SEALED_SECRETS_CERT
