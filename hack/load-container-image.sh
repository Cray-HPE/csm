#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2021-2022, 2024 Hewlett Packard Enterprise Development LP
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

[[ $# -eq 1 ]] || {
	echo >&2 "usage: ${0##*/} IMAGE"
	exit 1
}

image="$1"

set -exo pipefail

if command -v podman >/dev/null 2>&1; then

	## Attempt to look up podman settings needed for side-load
	## of images via skopeo
	for conf in graphRoot graphDriverName runRoot
	do
		conf_lc="$(echo $conf | tr '[:upper:]' '[:lower:]')"
		conf_val="$(podman info -f json | jq -r ".store.${conf}")"

		# try in lowercase vs. camelcase ...
		if [ "$conf_val" == "null" ]; then
			conf_val="$(podman info -f json | jq -r ".store.${conf_lc}")"
			if [ "$conf_val" == "null" ]; then
				echo >&2 "error: unable to determine $conf or $conf_lc for podman"
				exit 1
			fi
		fi
		declare $conf_lc=$conf_val
	done

	graphroot="$(realpath "$graphroot")"
	runroot="$(realpath "$runroot")"
	mounts="-v ${graphroot}:/var/lib/containers/storage"
	transport="containers-storage"
	run_opts="--rm --network none --privileged --ulimit=host"

        fuse_exe=$(podman info -f json | jq -r '.store.graphOptions["overlay.mount_program"].Executable')
        if [ "$fuse_exe" == "/usr/bin/fuse-overlayfs" ]; then
          skopeo_dest="${transport}:${image}"
        else
          skopeo_dest="${transport}:[${graphdrivername}@${graphroot}+${runroot}]${image}"
        fi

elif command -v docker >/dev/null 2>&1; then

	mounts="-v /var/run/docker.sock:/var/run/docker.sock"
	transport="docker-daemon"
	run_opts="--rm --network none --privileged"
	skopeo_dest="${transport}:${image}"
	shopt -s expand_aliases
	alias podman=docker
else
	echo >&2 "error: podman or docker not available"
	exit 2
fi

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."
source "${ROOTDIR}/lib/install.sh"

SKOPEO_IMAGE="$(load-vendor-image "${ROOTDIR}/vendor/skopeo.tar")"

podman run $run_opts  \
	$mounts \
	-v "$(realpath "${ROOTDIR}/docker"):/image:ro" \
	"$SKOPEO_IMAGE" \
	copy "dir:/image/${image}" "$skopeo_dest"
