#!/bin/bash
# Globally disable warning about globbing and word splitting
# shellcheck disable=SC2086

set -e

MTOKEN='ncn-m\w+'
STOKEN='ncn-s\w+'
WTOKEN='ncn-w\w+'

if [ -f /etc/pit-release ]; then
    if [ -z "$CSM_RELEASE" ]; then
        echo "Please set \$CSM_RELEASE and try again"
        exit 1
    fi

    CSM_DIRNAME=${CSM_DIRNAME:-/var/www/ephemeral}
    RPMDIR=${RPMDIR:-${CSM_DIRNAME}/${CSM_RELEASE}/rpm/cray/csm/sle-15sp2/noarch}

    if [ ! -d ${CSM_DIRNAME}/${CSM_RELEASE} ]; then
        echo "The $CSM_RELEASE directory was not found at the expected location.  Please set \$CSM_DIRNAME to the absolute path"
        echo "containing the $CSM_RELEASE directory"
        exit 1
    fi

    NCNS=$(grep -oE "($MTOKEN|$STOKEN|$WTOKEN)" /etc/dnsmasq.d/statics.conf | grep -v m001 | sort -u)
    CMS_TESTING_RPM=$(find $RPMDIR/csm-testing-* | sort -V | tail -1)
    GOSS_SERVERS_RPM=$(find $RPMDIR/goss-servers-* | sort -V | tail -1)
    PLATFORM_UTILS_RPM=$(find $RPMDIR/platform-utils-* | sort -V | tail -1)

    for ncn in $NCNS; do
        scp $CMS_TESTING_RPM $GOSS_SERVERS_RPM $PLATFORM_UTILS_RPM $ncn:/tmp/
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
