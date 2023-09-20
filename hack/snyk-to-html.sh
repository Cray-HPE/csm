#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

command -v snyk >/dev/null 2>&1 || { echo >&2 "command not found: snyk"; exit 1; }

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."

scandir="${1:-"${ROOTDIR}/scans/docker"}"

set -o errexit
set -o pipefail

echo >&2 "Building snyk-to-html image..."
docker build -t snyk-to-html - << EOF
FROM artifactory.algol60.net/docker.io/library/node:16-alpine
RUN npm install snyk-to-html -g
CMD ["snyk-to-html"]
EOF

echo >&2 "Generating HTML reports..."
find "$scandir" -name snyk.json | while read result; do
    output="$(dirname "$result")/snyk.html"
    echo >&2 "Generating ${output} ..."
    docker run --rm -i snyk-to-html < "${result}" > "${output}"
done
