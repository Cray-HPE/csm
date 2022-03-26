#!/bin/bash
#
# MIT License
#
# (C) Copyright 2014-2022 Hewlett Packard Enterprise Development LP
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

set -eo pipefail
test -n "$DEBUG" && set -x


# Globals
CHANGE_PASSWORD="no"
TMPDIR=$(mktemp -p /tmp -d ncn-ssh-keygen.XXXXXXXXXX)
KEYGEN="no"
KEY_SOURCE=$TMPDIR # can override with -d
KEYTYPE=""
SQUASH_PATHS=()
SSH_KEYGEN_ARGS=()
SSH_KEY_DIR=""
START_DIR=$PWD
SUPPLIED_HASH="${SQUASHFS_ROOT_PW_HASH:-""}"
TIMEZONE=""


function cleanup() {
    if [ -d "$TMPDIR" ]; then
        # don't use -v else -h output includes this detail
        rm -rf "$TMPDIR"
    fi
    cd "$START_DIR"
}


function err_report() {
    echo "Error on line $1 - depending on the failure location, you may need to remove squashfs-root"
    cleanup
}


# it's a trap!
trap 'err_report $LINENO' ERR TERM HUP INT
trap 'cleanup' EXIT


function usage() {
    echo -e "Usage: $(basename "$0") [-p] [-d dir] [ -z timezone] [-k kubernetes-squashfs-file] [-s storage-squashfs-file] [ssh-keygen arguments]\n"
    echo    "       This script semi-automates the process of changing the timezone, root"
    echo    "       password, and adding new ssh keys for the root user to the NCN squashfs"
    echo -e "       image(s).\n"
    echo    "       The script will immediately prompt for a new passphrase for ssh-keygen."
    echo    "       The script will then proceed to unsquash the supplied squash files and"
    echo    "       then prompt for a password. Once the password of the last squash has been"
    echo -e "       provided, the script will continue to completion without interruption.\n"
    echo    "       The process can be fully automated by using the SQUASHFS_ROOT_PW_HASH"
    echo -e "       environment variable (see below) along with either -d or -N\n"
    echo    "       -d dir         If provided, the contents will be copied into /root/.ssh/ in the"
    echo    "                      squashfs image. Do not supply ssh-keygen arguments when using -d."
    echo    "                      Assumes public keys have a .pub extension."
    echo    "       -p             Change or set the password in the squashfs. By default, the user is"
    echo    "                      prompted to enter the password after each squashfs file is unsquashed."
    echo    "                      Use the SQUASHFS_ROOT_PW_HASH environment variable (see below) to change"
    echo    "                      or set the password without being prompted."
    echo -e "       -z timezone    By default the timezone on NCNs is UTC. Use this option to override\n"
    echo -e "ENVIRONMENT VARIABLES\n"
    echo    "       SQUASHFS_ROOT_PW_HASH    If set to the encrypted hash for a root password,"
    echo    "                                this hash will be injected into /etc/shadow in the"
    echo    "                                squashfs image and there will be no interactive prompt"
    echo    "                                to set it. When setting this variable, be sure to use"
    echo    "                                single quotes (') to ensure any '$' characters are not"
    echo -e "                                interpreted.\n"
    echo    "       DEBUG                    If set, the script will be run with 'set -x'"

}


function preflight_sanity() {
    if [ "$(whoami)" != "root" ]; then
        echo "ERROR: the script must be run by the root user"
        exit 1
    fi

    if ! command -v ssh-keygen >& /dev/null; then
        echo "ERROR: ssh-keygen was not found on the system"
        exit 1
    fi

    if ! command -v mksquashfs >& /dev/null; then
        echo "ERROR: mksquashfs was not found on the system"
        exit 1
    fi
}


function process_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h)
                usage
                exit 0
                ;;
            -b)
                if [ -n "$SSH_KEY_DIR" ]; then
                    echo "-d cannot be specified with -b"
                    usage
                    exit 1
                fi
                KEYGEN="yes"
                SSH_KEYGEN_ARGS+=("-b $2")
                shift # past argument
                shift # past value
                ;;
            -C)
                if [ -n "$SSH_KEY_DIR" ]; then
                    echo "-d cannot be specified with -C"
                    usage
                    exit 1
                fi
                KEYGEN="yes"
                # ensure the comment is quoted in case it contains spaces
                SSH_KEYGEN_ARGS+=("-C \"$2\"")
                shift # past argument
                shift # past value
                ;;
            -d)
                if [ "$KEYGEN" = "no" ]; then
                    echo "-d cannot be specified with -t"
                    usage
                    exit 1
                fi
                # ensure the comment is quoted in case it contains spaces
                SSH_KEY_DIR=$2
                # no longer using TMPDIR
                KEY_SOURCE=$2
                shift # past argument
                shift # past value
                ;;
            -N)
                if [ -n "$SSH_KEY_DIR" ]; then
                    echo "-d cannot be specified with -N"
                    usage
                    exit 1
                fi
                KEYGEN="yes"
                # escape quotes in case passphrase is empty
                SSH_KEYGEN_ARGS+=("-N \"$2\"")
                shift # past argument
                shift # past value
                ;;
            -k|-s)
                SQUASH_PATHS+=("$2")
                shift # past argument
                shift # past value
                ;;
            -p)
                CHANGE_PASSWORD="yes"
                shift # past argument
                ;;
            -t)
                if [ -n "$SSH_KEY_DIR" ]; then
                    echo "-d cannot be specified with -t"
                    usage
                    exit 1
                fi
                KEYGEN="yes"
                KEYTYPE=$2
                SSH_KEYGEN_ARGS+=("-t $2")
                shift # past argument
                shift # past value
                ;;
            -z)
                TIMEZONE="$2"
                shift # past argument
                shift # past value
                ;;
            *)
                echo "Unknown or unsupported option $1"
                exit 1
                ;;
      esac
    done

    if [ -n "$TIMEZONE" ]; then
        if ! [ -f /usr/share/zoneinfo/"$TIMEZONE" ]; then
            echo "ERROR: can't find $TIMEZONE in /usr/share/zoneinfo"
            exit 1
        fi
    fi

    if [ -n "$SSH_KEY_DIR" ] && [ "$KEYGEN" = "no" ]; then
        echo "ERROR: refusing to create new images without ssh keys. Please use the -d option"
        echo "       or supply ssh-keygen arguments on the command line."
        usage
        exit 1
    fi

    if [ -n "$KEYTYPE" ]; then
        SSH_KEYGEN_ARGS+=("-f $TMPDIR/id_$KEYTYPE")
    fi
}


function verify_and_unsquash() {
    local squash
    local type

    for squash in ${SQUASH_PATHS[*]}; do
        if ! test -f "$squash"; then
            echo -e "\nERROR: $squash not found"
            exit 1
        fi

        type=$(file "$squash")
        if ! [[ $type =~ Squashfs ]]; then
            echo -e "\nERROR: $squash does not appear to be a squashfs filesystem"
            exit 1
        fi
        echo -e "\nvalidated squashfs path, unsquashing: $squash"
        unsquashfs -d "$(dirname "$squash")"/squashfs-root "$squash"
    done
}


function update_etc_shadow() {
    local squashfs_root=$1
    local seconds_per_day=$(( 60*60*24 ))
    local days_since_1970=$(( $(date +%s) / seconds_per_day ))

    sed -i "/^root:/c\root:$SUPPLIED_HASH:$days_since_1970::::::" "$squashfs_root"/etc/shadow
}


function set_timezone() {
    local squashfs_root

    if [ -n "$TIMEZONE" ]; then
        for squash in ${SQUASH_PATHS[*]}; do
            squashfs_root="$(dirname "$squash")"/squashfs-root
            echo "TZ=$TIMEZONE" > "$squashfs_root"/etc/environment
            sed -i "s#^timedatectl set-timezone UTC#timedatectl set-timezone $NEWTZ#" "$squashfs_root"//srv/cray/scripts/metal/ntp-upgrade-config.sh
        done
    fi
}

function setup_ssh() {
    local name
    local squash
    local squashfs_root

    # generate an ssh key if we were told to do so
    if [ "$KEYGEN" = "yes" ]; then
        echo -e "\ninvoking ssh-keygen ${SSH_KEYGEN_ARGS[*]}"
        eval ssh-keygen -q "${SSH_KEYGEN_ARGS[*]}"
    fi

    # set the password and set up passwordless ssh if appropriate
    for squash in ${SQUASH_PATHS[*]}; do
        squashfs_root="$(dirname "$squash")"/squashfs-root
        name=$(basename "$squash")

        echo -e "\nSet the password for $name:"
        # change password in the squash
        if [ "$CHANGE_PASSWORD" = "yes" ]; then
            if [ -n "$SUPPLIED_HASH" ]; then
                update_etc_shadow "$squashfs_root"
            else
                passwd --root "$squashfs_root"
            fi
        fi

        if [ "$KEYGEN" = "yes" ]; then
            # copy ssh key to the squashfs
            mkdir -pv "$squashfs_root"/root/.ssh
            chmod 700 "$squashfs_root"/root/.ssh
            cp -av "$KEY_SOURCE"/* "$squashfs_root"/root/.ssh/

            # set up passwordless ssh between NCNs
            cat "$KEY_SOURCE"/*.pub >> "$squashfs_root"/root/.ssh/authorized_keys
            chmod 600 "$squashfs_root"/root/.ssh/authorized_keys
        fi
    done
}


function create_new_squashfs() {
    local initrd_name
    local kernel_name
    local name
    local new_name
    local squash

    for squash in ${SQUASH_PATHS[*]}; do
        pushd "$(dirname "$squash")"
        name=$(basename "$squash")
        # prefix squashfs names with "secure-" so it's clear they have root keys
        # and credentials.  but don't keep prepending "secure-" in the case where
        # we're modifying a previously-modified squashfs.
        if [[ $name =~ secure- ]]; then
            new_name=$name
        else
            # first time modifying this image
            new_name=secure-"$name"
        fi

        echo -e "\nCreating new boot artifacts..."
        chroot squashfs-root /srv/cray/scripts/common/create-kis-artifacts.sh
        umount -v squashfs-root/mnt/squashfs

        mkdir -v old
        # get the names of the existing kernel/initrd
        kernel_name=$(ls ./*kernel*)
        initrd_name=$(ls ./*initrd*)

        # save original artifacts
        mv -v ./*initrd* ./"$kernel_name" "$name" old/

        # put new artifacts in place
        mv -v squashfs-root/squashfs/* .

        # rename the kernel/initrd to what they were originally (includes version info)
        mv -v ./*kernel* "$kernel_name"
        mv -v initrd.img.xz "$initrd_name"

        # rename from generic
        mv -v filesystem.squashfs "$new_name"

        # set perms so apache can serve the initrd
        chmod -v 644 "$initrd_name"
        echo -e "\nRemoving squashfs-root/"
        rm -rf squashfs-root
        popd
    done
}


preflight_sanity
process_args "$@"
verify_and_unsquash
setup_ssh
set_timezone
create_new_squashfs
cleanup

echo -e "\nScript executed successfully"
