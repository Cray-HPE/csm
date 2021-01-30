#!/bin/bash
# Copyright 2020, Cray Inc.

CUSTOMIZATIONS=${1:-customizations.yaml}
# MANIFESTS=${2:-manifests}
DEST=${3:-test-build}

# type manifestgen >/dev/null 2>&1 || { echo >&2 "manifestgen is required but it's not installed. Aborting."; exit 1; }

rm -r $DEST 2>&1 || echo ""
mkdir -p $DEST

# Generate a temporary copy of the input customizations file
rm -f "test-${CUSTOMIZATIONS}"
cp "${CUSTOMIZATIONS}" "test-${CUSTOMIZATIONS}"
SED_ARGS=
case "${OSTYPE}" in
  darwin*)
    # sed on OS X requires an extension when using -i
    SED_ARGS=".bak"
    ;;
esac
sed -i ${SED_ARGS} s/~FIXME~//g "test-${CUSTOMIZATIONS}"
sed -i ${SED_ARGS} s/\ e\.g\.\ //g "test-${CUSTOMIZATIONS}"
case "${OSTYPE}" in
  darwin*)
    rm -f "test-${CUSTOMIZATIONS}.bak"
    ;;
esac

set -e

./utils/secrets-seed-customizations.sh "test-${CUSTOMIZATIONS}"

### Manifests no longer live in shasta-cfg, but are
### broken down into their own product stream installers

#for I in $(ls $MANIFESTS|grep .yaml);do
#    echo "Generating: $DEST/$I"
#    manifestgen -i $MANIFESTS/$I -c "test-${CUSTOMIZATIONS}" -o $DEST/$I
#done

