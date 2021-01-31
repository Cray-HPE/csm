#!/bin/bash

ROOT_DIR="$(dirname $0)/.."
ROOT_DIR="$(pushd "$ROOT_DIR" > /dev/null && pwd && popd > /dev/null)"

CURR_DIR=$PWD

VERSION=$1

function usage(){
    cat <<EOF
Usage:
    package.sh VERSION

    package.sh 1.0.0

    Packages shasta-cfg repo for distribution.

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

if [[ -z "$VERSION" ]]; then
    error "VERSION is required"
fi

DIST="${ROOT_DIR}/dist"

if [[ -d "${DIST}" ]]; then
    rm -rf "${DIST}"
fi

set -e

UNAME="$(uname | awk '{print tolower($0)}')"

# Note, there are MANY projects that claim the yq binary name
# to prevent oddities between them we ship the one we need here.
YQ="${ROOT_DIR}/utils/bin/${UNAME}/yq"

PACKAGE_PREFIX="shasta-cfg"
PACKAGE_NAME="${PACKAGE_PREFIX}-${VERSION}"

mkdir -p "${DIST}/${PACKAGE_PREFIX}"

# Copy shasta-cfg content ignoring anything in the ignore file.
rsync -rlE --safe-links --exclude-from="${ROOT_DIR}/package/ignore" "${ROOT_DIR}/" "${DIST}/${PACKAGE_PREFIX}"

# Write version to file as artifact in package
echo "$VERSION" > "${DIST}/${PACKAGE_PREFIX}/.version"

# Remove any static secrets that cannot be decrypted by clients"
SEC=$($YQ r --printMode p ${DIST}/${PACKAGE_PREFIX}/customizations.yaml "spec.kubernetes.sealed_secrets.(kind==SealedSecret)")
for S in $SEC;do
    $YQ d -i "${DIST}/${PACKAGE_PREFIX}/customizations.yaml" "$S"
done

$YQ m -i "${DIST}/${PACKAGE_PREFIX}/customizations.yaml" "${ROOT_DIR}/package/static_secrets.yaml"

cd "${DIST}"

tar -czvf "${PACKAGE_NAME}.tgz" "${PACKAGE_PREFIX}"

cd "${CURR_DIR}"

echo "Created package successfully!"
echo "PACKAGE_LOCATION=${DIST}/${PACKAGE_NAME}.tgz"