#!/bin/bash


ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."
workdir="$(mktemp -d)"
#shellcheck disable=SC2064
trap "rm -fr '$workdir'" EXIT

"${ROOTDIR}/hack/list-images.py" > "${workdir}/images.txt"


while read p; do
  docker image rm -f  "$p"
done < "${workdir}/images.txt"
