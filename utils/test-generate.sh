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
./utils/gencerts.sh
./utils/secrets-seed-customizations.sh "test-${CUSTOMIZATIONS}"

### Manifests no longer live in shasta-cfg, but are
### broken down into their own product stream installers

#for I in $(ls $MANIFESTS|grep .yaml);do
#    echo "Generating: $DEST/$I"
#    manifestgen -i $MANIFESTS/$I -c "test-${CUSTOMIZATIONS}" -o $DEST/$I
#done

