#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"

function usage() {
    echo >&2 "usage: ${0##*/} [--continue]"
    exit 2
}

if [[ $# -eq 0 ]]; then
    exec ${ROOTDIR}/install-a.sh
else
    case "$1" in
    -h|--help)
        usage
        ;;
    -c|--continue)
        echo >&2 "Continuing with installation..."
        echo >&2
        exec ${ROOTDIR}/install-b.sh
        ;;
    *)
        echo >&2 "unknown option: $1"
        usage
        ;;
    esac
fi
