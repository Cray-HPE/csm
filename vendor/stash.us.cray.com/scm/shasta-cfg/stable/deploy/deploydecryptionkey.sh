#!/bin/bash
# Copyright 2020, Cray Inc.

ROOT_DIR="$(dirname $0)/.."
SEALED_SECRETS_KEY=${SEALED_SECRETS_KEY:-$ROOT_DIR/certs/sealed_secrets.key}
SEALED_SECRETS_CERT=${SEALED_SECRETS_CERT:-$ROOT_DIR/certs/sealed_secrets.crt}
SEALED_SECRET_MASTER_KEY=${SEALED_SECRET_MASTER_KEY:-$ROOT_DIR/certs/masterkey.yaml}
SEALED_SECRET_NAMESPACE=${SEALED_SECRET_NAMESPACE:-kube-system}
SEALED_SECRET_NAME=${SEALED_SECRET_NAME:-sealed-secrets-key}

type kubectl >/dev/null 2>&1 || { echo >&2 "I require kubectl but it's not installed. Aborting."; exit 1; }

mkdir -p $(dirname $SEALED_SECRET_MASTER_KEY) || echo ""

KCMD="kubectl -n $SEALED_SECRET_NAMESPACE"

$KCMD delete secret $SEALED_SECRET_NAME || echo ""
echo $($KCMD create secret tls $SEALED_SECRET_NAME --key="$SEALED_SECRETS_KEY" --cert="$SEALED_SECRETS_CERT" --dry-run -o json | jq -rc '.metadata += {"labels": {"sealedsecrets.bitnami.com/sealed-secrets-key":"active"}}')  | $KCMD create -f -
echo "Restarting sealed-secrets to pick up new keys"
$KCMD delete pod -l app.kubernetes.io/name=sealed-secrets
$KCMD get secret -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml >$SEALED_SECRET_MASTER_KEY
