#!/bin/bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

# Globally disable warning about globbing and word splitting
# shellcheck disable=SC2086

set -e

function find_latest_rpm
{
    # $1 - RPM name prefix (e.g. csm-testing, goss-servers, etc)
    local name vpattern rpm_file_pattern filepath
    name="$1"
    vpattern="[0-9][0-9]*[.][0-9][0-9]*[.][0-9][0-9]*"              # The first part of the version will be three .-separated numbers
    rpm_file_pattern="${name}-${vpattern}[-_.a-zA-Z0-9]*[.]rpm"     # After that, we expect only a certain set of characters before
                                                                    # ending in .rpm
    filepath=$(find "$RPMDIR" -type f -name \*.rpm |                # List all RPM files in the rpm directory
               grep "/${rpm_file_pattern}$" |                       # Select only those whose names fit our pattern
               sed "s#^\(.*/\)\(${rpm_file_pattern}\)\$#\2 \1\2#" | # Change each line so first it shows just the RPM filename,
                                                                    # followed by a blank space, followed by the original full
                                                                    # path and filename
               sort -k1V |                                          # Sort the first field (the RPM filename without path) by version
               tail -1 |                                            # Choose the last one listed (the one with the highest version)
               sed 's/^[^ ]* //')                                   # Change the line, removing the RPM filename and space, leaving
                                                                    # only the full path and filename
    if [ -z "${filepath}" ]; then
        echo "The ${name} RPM was not found at the expected location. Ensure this RPM exists under the '$RPMDIR' directory" 1>&2
        return 1
    fi
    echo "${filepath}"
    return 0
}

MTOKEN='ncn-m\w+'
STOKEN='ncn-s\w+'
WTOKEN='ncn-w\w+'

if [ -f /etc/pit-release ]; then
    if [ -z "$CSM_RELEASE" ]; then
        echo "Please set \$CSM_RELEASE and try again"
        exit 1
    fi

    CSM_DIRNAME=${CSM_DIRNAME:-/var/www/ephemeral}
    RPMDIR=${RPMDIR:-${CSM_DIRNAME}/${CSM_RELEASE}/rpm}

    if [ ! -d "${CSM_DIRNAME}/${CSM_RELEASE}" ]; then
        echo "The $CSM_RELEASE directory was not found at the expected location.  Please set \$CSM_DIRNAME to the absolute path"
        echo "containing the $CSM_RELEASE directory"
        exit 1
    fi

    NCNS=$(grep -oE "($MTOKEN|$STOKEN|$WTOKEN)" /etc/dnsmasq.d/statics.conf | grep -v m001 | sort -u)
    CMS_TESTING_RPM=$(find_latest_rpm csm-testing) || exit 1
    GOSS_SERVERS_RPM=$(find_latest_rpm goss-servers) || exit 1
    PLATFORM_UTILS_RPM=$(find_latest_rpm platform-utils) || exit 1

    for ncn in $NCNS; do
        scp "$CMS_TESTING_RPM" "$GOSS_SERVERS_RPM" "$PLATFORM_UTILS_RPM" $ncn:/tmp/
        # shellcheck disable=SC2029
        ssh $ncn "rpm -Uvh --force /tmp/$(basename $CMS_TESTING_RPM) /tmp/$(basename $GOSS_SERVERS_RPM) /tmp/$(basename $PLATFORM_UTILS_RPM) && systemctl restart goss-servers"
    done

    # The rpms should have been installed on the pit at the same time csi was installed. Trust, but verify:
    rpm -qa | grep goss-servers- || (zypper install $GOSS_SERVERS_RPM && systemctl enable goss-servers && systemctl restart goss-servers)
    rpm -qa | grep csm-testing- || zypper install $CMS_TESTING_RPM
    rpm -qa | grep platform-utils- || zypper install $PLATFORM_UTILS_RPM
else
    echo "ERROR: This script should only be run from the pit node prior to the handoff and reboot into ncn-m001"
    exit 1
fi
