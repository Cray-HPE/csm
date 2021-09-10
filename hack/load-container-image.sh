#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

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
	skopeo_dest="${transport}:[${graphdrivername}@${graphroot}+${runroot}]${image}"

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
