#!/bin/bash

set -o errexit
set -o pipefail
set -o xtrace

find /data -name snyk.json | python /usr/src/app/snyk-aggregate-results.py "$@"
