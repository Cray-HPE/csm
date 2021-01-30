#!/bin/bash
NEW_DIR=${1:-.}
ROOT_SCRIPT_DIR="$(dirname $0)/.."
ROOT_SCRIPT_DIR="$(pushd "$ROOT_SCRIPT_DIR" > /dev/null && pwd && popd > /dev/null)"

set -e

if [ -z "$NEW_DIR" ]
then
      echo "\$NEW_DIR is required."
      exit 1
fi

if [[ -d "$NEW_DIR/meta" ]]
then
    echo "This is the meta repo, skipping bootstrapping"
    exit 1
fi

mkdir -p $NEW_DIR
# RJB: Consider using rsync (or similar) here with delete options to remove
# deprecated items. Not sure what affect this would have.

echo "Copying docs to $NEW_DIR"
cp -r "$ROOT_SCRIPT_DIR/docs" "$NEW_DIR"

if [[ -f "$ROOT_SCRIPT_DIR/README.md" ]]; then
    cp "$ROOT_SCRIPT_DIR/README.md" "$NEW_DIR"
fi

echo "Copying deploy scripts to $NEW_DIR"
cp -r "$ROOT_SCRIPT_DIR/deploy" "$NEW_DIR"

if [[ -f "$ROOT_SCRIPT_DIR/Jenkinsfile.prod" ]]; then
    echo "Copying Jenkinsfile $NEW_DIR"
    cp "$ROOT_SCRIPT_DIR/Jenkinsfile.prod" "$NEW_DIR/Jenkinsfile"
fi

echo "Copying utility scripts to $NEW_DIR"
cp -r "$ROOT_SCRIPT_DIR/utils" "$NEW_DIR"
rm "$NEW_DIR/utils/migrations/.gitignore" || echo ""

echo "Migrating customizations to $NEW_DIR"
$NEW_DIR/utils/migrate-customizations.sh "$ROOT_SCRIPT_DIR/customizations.yaml"

if [[ -f "$NEW_DIR/utils/gencerts.sh" ]]; then
    echo "Migrating sealed secret certs if needed"
    $NEW_DIR/utils/gencerts.sh
fi

echo "Reencrypting secrets to use new private key"
# pass in both the stable private key and the new private key so this wont fail
# when rerunning (sync.sh)
KEY="$NEW_DIR/certs/sealed_secrets.key"

if [[ -f $ROOT_SCRIPT_DIR/certs/sealed_secrets.key ]]; then
    KEY="$ROOT_SCRIPT_DIR/certs/sealed_secrets.key,$NEW_DIR/certs/sealed_secrets.key"
fi

$NEW_DIR/utils/secrets-reencrypt.sh "$NEW_DIR/customizations.yaml" "$KEY" "$NEW_DIR/certs/sealed_secrets.crt"

echo "Generating any required random sealed secrets"
$NEW_DIR/utils/secrets-seed-customizations.sh "$NEW_DIR/customizations.yaml"

if [[ ! -d "$NEW_DIR/.git" && -f "$ROOT_SCRIPT_DIR/.gitignore" ]]
then
    echo "Initializing git"
    cp "$ROOT_SCRIPT_DIR/.gitignore" "$NEW_DIR"
    CURR=$PWD
    cd $NEW_DIR
    git init
    cd $CURR
fi



