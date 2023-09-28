#!/bin/bash
#
# MIT License
#
# (C) Copyright 2021,2023 Hewlett Packard Enterprise Development LP
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

# Globally disable warning about globbing and word splitting
# shellcheck disable=SC2086

set -e

function find_latest_rpm
{
    # $1 - RPM name prefix (e.g. csm-testing, goss-servers, etc)
    local name vpattern rpm_regex1 rpm_regex2 filepath
    name="$1"
    vpattern="[0-9][0-9]*[.][0-9][0-9]*[.][0-9][0-9]*"                # The first part of the version will be three
                                                                      # .-separated numbers
                                                                      # After the name and version, there are two
                                                                      # ways our RPM may be named:
    rpm_regex1="${name}-${vpattern}-[^/]*[.]rpm"                      # It could have a -, followed by characters we
                                                                      # do not care about, ending in .rpm
    rpm_regex2="${name}-${vpattern}[.]rpm"                            # Or it could just have .rpm after the name
                                                                      # and version
    filepath=$(find "$RPMDIR" -type f -name \*.rpm |                  # List all RPM files in the rpm directory
               grep -E "/(${rpm_regex1}|${rpm_regex2})$" |            # Select only names fitting one of our patterns
               sed -e "s#^${RPMDIR}.*/\(${rpm_regex1}\)\$#\1 \0#" \
                   -e "s#^${RPMDIR}.*/\(${rpm_regex2}\)\$#\1 \0#" |   # Change each line so first it shows just the
                                                                      # RPM filename, followed by a blank space,
                                                                      # followed by the original full path and filename
               sort -k1V |                                            # Sort the first field (the RPM filename without
                                                                      # path) by version
               tail -1 |                                              # Choose the last one listed (the one with the
                                                                      # highest version)
               sed 's/^[^ ]* //')                                     # Change the line, removing the RPM filename and
                                                                      # space, leaving only the full path and filename
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

    STORAGE_NCNS=$(grep -oE "$STOKEN" /etc/dnsmasq.d/statics.conf | grep -v m001 | sort -u)
    K8S_NCNS=$(grep -oE "($MTOKEN|$WTOKEN)" /etc/dnsmasq.d/statics.conf | grep -v m001 | sort -u)
    CSM_TESTING_RPM=$(find_latest_rpm csm-testing) || exit 1
    GOSS_SERVERS_RPM=$(find_latest_rpm goss-servers) || exit 1
    PLATFORM_UTILS_RPM=$(find_latest_rpm platform-utils) || exit 1
    HPE_GOSS_RPM=$(find_latest_rpm hpe-csm-goss-package) || exit 1
    CMSTOOLS_RPM=$(find_latest_rpm cray-cmstools-crayctldeploy) || exit 1

    # cmstools RPM is not installed on storage nodes
    for ncn in $STORAGE_NCNS; do
        scp "$HPE_GOSS_RPM" "$CSM_TESTING_RPM" "$GOSS_SERVERS_RPM" "$PLATFORM_UTILS_RPM" $ncn:/tmp/
        # shellcheck disable=SC2029
        ssh $ncn "rpm -Uvh --force /tmp/$(basename $HPE_GOSS_RPM) /tmp/$(basename $CSM_TESTING_RPM) /tmp/$(basename $GOSS_SERVERS_RPM) /tmp/$(basename $PLATFORM_UTILS_RPM) && systemctl restart goss-servers"
    done

    for ncn in $K8S_NCNS; do
        scp "$HPE_GOSS_RPM" "$CMSTOOLS_RPM" "$CSM_TESTING_RPM" "$GOSS_SERVERS_RPM" "$PLATFORM_UTILS_RPM" $ncn:/tmp/
        # shellcheck disable=SC2029
        ssh $ncn "rpm -Uvh --force /tmp/$(basename $HPE_GOSS_RPM) /tmp/$(basename $CMSTOOLS_RPM) /tmp/$(basename $CSM_TESTING_RPM) /tmp/$(basename $GOSS_SERVERS_RPM) /tmp/$(basename $PLATFORM_UTILS_RPM) && systemctl restart goss-servers"
    done

    # The rpms should have been installed on the pit at the same time csi was installed. Trust, but verify:
    rpm -q hpe-csm-goss-package || zypper install -y $HPE_GOSS_RPM
    rpm -qa | grep csm-testing- || zypper install -y $CSM_TESTING_RPM
    rpm -qa | grep goss-servers- || (zypper install -y $GOSS_SERVERS_RPM && systemctl enable goss-servers && systemctl restart goss-servers)
    rpm -qa | grep platform-utils- || zypper install -y $PLATFORM_UTILS_RPM
else
    echo "ERROR: This script should only be run from the pit node prior to the handoff and reboot into ncn-m001"
    exit 1
fi
