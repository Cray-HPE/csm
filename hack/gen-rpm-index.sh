#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2021-2023 Hewlett Packard Enterprise Development LP
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
set -ex

# The repo options to rpm-index are generated from the CSM/csm-rpms repo as
# follows:
#
#   $ find repos -name '*.repos' | xargs cat | sed -e 's/#.*$//' -e '/[[:space:]]/!d' | awk '{ print "-d", $1, $(NF) }' | column -t
#
# Note that the kubernetes/el7/x86_64 repo is included as it is implicitly
# added by the ncn-k8s image.

#pass the repo credentials environment variable to the container that runs rpm-index
REPO_CREDS_DOCKER_OPTIONS=""
REPO_CREDS_RPMINDEX_OPTIONS=""
if [ ! -z "$REPOCREDSVARNAME" ]; then
    REPO_CREDS_DOCKER_OPTIONS="-e ${REPOCREDSVARNAME}"
    REPO_CREDS_RPMINDEX_OPTIONS="-c ${REPOCREDSVARNAME}"
fi
docker run ${REPO_CREDS_DOCKER_OPTIONS} --rm -i arti.hpc.amslabs.hpecorp.net/internal-docker-stable-local/packaging-tools:0.12.6 rpm-index ${REPO_CREDS_RPMINDEX_OPTIONS} -v \
-d  https://artifactory.algol60.net/artifactory/csm-rpms/hpe/stable/sle-15sp4/                                        opensuse_leap/15.3 \
-d  https://download.opensuse.org/repositories/filesystems:/ceph/openSUSE_Leap_15.3/                                        opensuse_leap/15.3 \
-d  https://artifactory.algol60.net/artifactory/opensuse-mirror/filesystems:ceph/openSUSE_Leap_15.3/                       mirror/opensuse_leap/15.3 \
-d  https://arti.hpc.amslabs.hpecorp.net/artifactory/csm-rpm-stable-local/hpe/                                                         cray/csm/sle-15sp3/x86_64 \
-d  https://arti.hpc.amslabs.hpecorp.net/artifactory/csm-rpm-stable-local/release/                                                     cray/csm/sle-15sp3/x86_64 \
-d  https://arti.hpc.amslabs.hpecorp.net/artifactory/mirror-HPE-SPP/SUSE_LINUX/SLES15-SP3/x86_64/current/                  hpe/SUSE_LINUX/SLES15-SP3/x86_64/current \
-d  https://arti.hpc.amslabs.hpecorp.net/artifactory/mirror-HPE-SPP/SUSE_LINUX/SLES15-SP2/x86_64/current/                  hpe/SUSE_LINUX/SLES15-SP2/x86_64/current \
-d  https://artifactory.algol60.net/artifactory/csm-rpms/hpe/stable/sle-15sp2/                                              cray/csm/sle-15sp3 \
-d  https://artifactory.algol60.net/artifactory/csm-rpms/hpe/stable/sle-15sp3/                                              cray/csm/sle-15sp3 \
-d  https://arti.hpc.amslabs.hpecorp.net/artifactory/cos-rpm-stable-local/release/cos-2.3/sle15_sp3_ncn/                               cray/cos-2.3/sle15_sp3_ncn \
-d  https://arti.hpc.amslabs.hpecorp.net/artifactory/cos-rpm-stable-local/release/cos-2.1/sle15_sp2_ncn/                               cray/cos-2.1/sle15_sp2_ncn \
-d  https://arti.hpc.amslabs.hpecorp.net/artifactory/cos-rpm-stable-local/release/cos-2.2/sle15_sp3_ncn/                               cray/cos-2.2/sle15_sp3_ncn \
-d  https://arti.hpc.amslabs.hpecorp.net/artifactory/cos-rpm-stable-local/release/cos-2.2/sle15_sp3_cn/                                cray/cos-2.2/sle15_sp3_cn \
-d  https://arti.hpc.amslabs.hpecorp.net/artifactory/slingshot-host-software-rpm-stable-local/release/cos-2.2/sle15_sp2_ncn/           cray/cos-2.2/sle15_sp2_ncn \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Basesystem/15-SP2/x86_64/product/                  suse/SLE-Module-Basesystem/15-SP2/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Basesystem/15-SP2/x86_64/product_debug/            suse/SLE-Module-Basesystem/15-SP2/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Basesystem/15-SP2/x86_64/update/                    suse/SLE-Module-Basesystem/15-SP2/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Basesystem/15-SP2/x86_64/update_debug/              suse/SLE-Module-Basesystem/15-SP2/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Containers/15-SP2/x86_64/product/                  suse/SLE-Module-Containers/15-SP2/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Containers/15-SP2/x86_64/product_debug/            suse/SLE-Module-Containers/15-SP2/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Containers/15-SP2/x86_64/update/                    suse/SLE-Module-Containers/15-SP2/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Containers/15-SP2/x86_64/update_debug/              suse/SLE-Module-Containers/15-SP2/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Desktop-Applications/15-SP2/x86_64/product/        suse/SLE-Module-Desktop-Applications/15-SP2/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Desktop-Applications/15-SP2/x86_64/product_debug/  suse/SLE-Module-Desktop-Applications/15-SP2/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Desktop-Applications/15-SP2/x86_64/update/          suse/SLE-Module-Desktop-Applications/15-SP2/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Desktop-Applications/15-SP2/x86_64/update_debug/    suse/SLE-Module-Desktop-Applications/15-SP2/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Development-Tools/15-SP2/x86_64/product/           suse/SLE-Module-Development-Tools/15-SP2/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Development-Tools/15-SP2/x86_64/product_debug/     suse/SLE-Module-Development-Tools/15-SP2/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Development-Tools/15-SP2/x86_64/update/             suse/SLE-Module-Development-Tools/15-SP2/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Development-Tools/15-SP2/x86_64/update_debug/       suse/SLE-Module-Development-Tools/15-SP2/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-HPC/15-SP2/x86_64/product/                         suse/SLE-Module-HPC/15-SP2/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-HPC/15-SP2/x86_64/product_debug/                   suse/SLE-Module-HPC/15-SP2/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-HPC/15-SP2/x86_64/update/                           suse/SLE-Module-HPC/15-SP2/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-HPC/15-SP2/x86_64/update_debug/                     suse/SLE-Module-HPC/15-SP2/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Legacy/15-SP2/x86_64/product/                      suse/SLE-Module-Legacy/15-SP2/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Legacy/15-SP2/x86_64/product_debug/                suse/SLE-Module-Legacy/15-SP2/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Legacy/15-SP2/x86_64/update/                        suse/SLE-Module-Legacy/15-SP2/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Legacy/15-SP2/x86_64/update_debug/                  suse/SLE-Module-Legacy/15-SP2/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Public-Cloud/15-SP2/x86_64/product/                suse/SLE-Module-Public-Cloud/15-SP2/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Public-Cloud/15-SP2/x86_64/product_debug/          suse/SLE-Module-Public-Cloud/15-SP2/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Public-Cloud/15-SP2/x86_64/update/                  suse/SLE-Module-Public-Cloud/15-SP2/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Public-Cloud/15-SP2/x86_64/update_debug/            suse/SLE-Module-Public-Cloud/15-SP2/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Python2/15-SP2/x86_64/product/                     suse/SLE-Module-Python2/15-SP2/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Python2/15-SP2/x86_64/product_debug/               suse/SLE-Module-Python2/15-SP2/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Python2/15-SP2/x86_64/update/                       suse/SLE-Module-Python2/15-SP2/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Python2/15-SP2/x86_64/update_debug/                 suse/SLE-Module-Python2/15-SP2/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Server-Applications/15-SP2/x86_64/product/         suse/SLE-Module-Server-Applications/15-SP2/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Server-Applications/15-SP2/x86_64/product_debug/   suse/SLE-Module-Server-Applications/15-SP2/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Server-Applications/15-SP2/x86_64/update/           suse/SLE-Module-Server-Applications/15-SP2/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Server-Applications/15-SP2/x86_64/update_debug/     suse/SLE-Module-Server-Applications/15-SP2/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Web-Scripting/15-SP2/x86_64/product/               suse/SLE-Module-Web-Scripting/15-SP2/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Web-Scripting/15-SP2/x86_64/product_debug/         suse/SLE-Module-Web-Scripting/15-SP2/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Web-Scripting/15-SP2/x86_64/update/                 suse/SLE-Module-Web-Scripting/15-SP2/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Web-Scripting/15-SP2/x86_64/update_debug/           suse/SLE-Module-Web-Scripting/15-SP2/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Product-HPC/15-SP2/x86_64/product/                        suse/SLE-Product-HPC/15-SP2/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Product-HPC/15-SP2/x86_64/product_debug/                  suse/SLE-Product-HPC/15-SP2/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Product-HPC/15-SP2/x86_64/update/                          suse/SLE-Product-HPC/15-SP2/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Product-HPC/15-SP2/x86_64/update_debug/                    suse/SLE-Product-HPC/15-SP2/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Product-SLES/15-SP2/x86_64/product/                       suse/SLE-Product-SLES/15-SP2/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Product-SLES/15-SP2/x86_64/product_debug/                 suse/SLE-Product-SLES/15-SP2/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Product-SLES/15-SP2/x86_64/update/                         suse/SLE-Product-SLES/15-SP2/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Product-SLES/15-SP2/x86_64/update_debug/                   suse/SLE-Product-SLES/15-SP2/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Product-WE/15-SP2/x86_64/product/                         suse/SLE-Product-WE/15-SP2/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Product-WE/15-SP2/x86_64/product_debug/                   suse/SLE-Product-WE/15-SP2/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Product-WE/15-SP2/x86_64/update/                           suse/SLE-Product-WE/15-SP2/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Product-WE/15-SP2/x86_64/update_debug/                     suse/SLE-Product-WE/15-SP2/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Backports/SLE-15-SP2_x86_64/standard/                                  suse/Backports-SLE/15-SP2/x86_64/standard \
    -d  http://slemaster.us.cray.com/SUSE/Backports/SLE-15-SP2_x86_64/standard_debug/                            suse/Backports-SLE/15-SP2/x86_64/standard_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Basesystem/15-SP3/x86_64/product/                  suse/SLE-Module-Basesystem/15-SP3/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Basesystem/15-SP3/x86_64/product_debug/            suse/SLE-Module-Basesystem/15-SP3/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Containers/15-SP3/x86_64/product/                  suse/SLE-Module-Containers/15-SP3/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Containers/15-SP3/x86_64/product_debug/            suse/SLE-Module-Containers/15-SP3/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Basesystem/15-SP3/x86_64/update/                    suse/SLE-Module-Basesystem/15-SP3/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Containers/15-SP3/x86_64/update/                    suse/SLE-Module-Containers/15-SP3/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Containers/15-SP3/x86_64/update_debug/              suse/SLE-Module-Containers/15-SP3/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Desktop-Applications/15-SP3/x86_64/product/        suse/SLE-Module-Desktop-Applications/15-SP3/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Desktop-Applications/15-SP3/x86_64/product_debug/  suse/SLE-Module-Desktop-Applications/15-SP3/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Desktop-Applications/15-SP3/x86_64/update/          suse/SLE-Module-Desktop-Applications/15-SP3/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Desktop-Applications/15-SP3/x86_64/update_debug/    suse/SLE-Module-Desktop-Applications/15-SP3/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Development-Tools/15-SP3/x86_64/product/           suse/SLE-Module-Development-Tools/15-SP3/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Development-Tools/15-SP3/x86_64/product_debug/     suse/SLE-Module-Development-Tools/15-SP3/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Development-Tools/15-SP3/x86_64/update/             suse/SLE-Module-Development-Tools/15-SP3/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Development-Tools/15-SP3/x86_64/update_debug/       suse/SLE-Module-Development-Tools/15-SP3/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-HPC/15-SP3/x86_64/product/                         suse/SLE-Module-HPC/15-SP3/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-HPC/15-SP3/x86_64/product_debug/                   suse/SLE-Module-HPC/15-SP3/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-HPC/15-SP3/x86_64/update/                           suse/SLE-Module-HPC/15-SP3/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-HPC/15-SP3/x86_64/update_debug/                     suse/SLE-Module-HPC/15-SP3/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Legacy/15-SP3/x86_64/product/                      suse/SLE-Module-Legacy/15-SP3/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Legacy/15-SP3/x86_64/product_debug/                suse/SLE-Module-Legacy/15-SP3/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Legacy/15-SP3/x86_64/update/                        suse/SLE-Module-Legacy/15-SP3/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Legacy/15-SP3/x86_64/update_debug/                  suse/SLE-Module-Legacy/15-SP3/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Public-Cloud/15-SP3/x86_64/product/                suse/SLE-Module-Public-Cloud/15-SP3/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Public-Cloud/15-SP3/x86_64/product_debug/          suse/SLE-Module-Public-Cloud/15-SP3/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Public-Cloud/15-SP3/x86_64/update/                  suse/SLE-Module-Public-Cloud/15-SP3/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Public-Cloud/15-SP3/x86_64/update_debug/            suse/SLE-Module-Public-Cloud/15-SP3/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Python2/15-SP3/x86_64/product/                     suse/SLE-Module-Python2/15-SP3/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Python2/15-SP3/x86_64/product_debug/               suse/SLE-Module-Python2/15-SP3/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Python2/15-SP3/x86_64/update/                       suse/SLE-Module-Python2/15-SP3/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Python2/15-SP3/x86_64/update_debug/                 suse/SLE-Module-Python2/15-SP3/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Server-Applications/15-SP3/x86_64/product/         suse/SLE-Module-Server-Applications/15-SP3/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Server-Applications/15-SP3/x86_64/product_debug/   suse/SLE-Module-Server-Applications/15-SP3/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Server-Applications/15-SP3/x86_64/update/           suse/SLE-Module-Server-Applications/15-SP3/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Server-Applications/15-SP3/x86_64/update_debug/     suse/SLE-Module-Server-Applications/15-SP3/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Web-Scripting/15-SP3/x86_64/product/               suse/SLE-Module-Web-Scripting/15-SP3/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Web-Scripting/15-SP3/x86_64/product_debug/         suse/SLE-Module-Web-Scripting/15-SP3/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Web-Scripting/15-SP3/x86_64/update/                 suse/SLE-Module-Web-Scripting/15-SP3/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Web-Scripting/15-SP3/x86_64/update_debug/           suse/SLE-Module-Web-Scripting/15-SP3/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Product-HPC/15-SP3/x86_64/product/                        suse/SLE-Product-HPC/15-SP3/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Product-HPC/15-SP3/x86_64/product_debug/                  suse/SLE-Product-HPC/15-SP3/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Product-HPC/15-SP3/x86_64/update/                          suse/SLE-Product-HPC/15-SP3/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Product-HPC/15-SP3/x86_64/update_debug/                    suse/SLE-Product-HPC/15-SP3/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Product-SLES/15-SP3/x86_64/product/                       suse/SLE-Product-SLES/15-SP3/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Product-SLES/15-SP3/x86_64/product_debug/                 suse/SLE-Product-SLES/15-SP3/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Product-SLES/15-SP3/x86_64/update/                         suse/SLE-Product-SLES/15-SP3/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Product-SLES/15-SP3/x86_64/update_debug/                   suse/SLE-Product-SLES/15-SP3/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Product-WE/15-SP3/x86_64/product/                         suse/SLE-Product-WE/15-SP3/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Product-WE/15-SP3/x86_64/product_debug/                   suse/SLE-Product-WE/15-SP3/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Product-WE/15-SP3/x86_64/update/                           suse/SLE-Product-WE/15-SP3/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Product-WE/15-SP3/x86_64/update_debug/                     suse/SLE-Product-WE/15-SP3/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/Storage/7/x86_64/product/                                     suse/Storage/7/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/Storage/7/x86_64/product_debug/                               suse/Storage/7/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/Storage/7/x86_64/update/                                       suse/Storage/7/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/Storage/7/x86_64/update_debug/                                 suse/Storage/7/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/Storage/6/x86_64/product/                                     suse/Storage/6/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/Storage/6/x86_64/product_debug/                               suse/Storage/6/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/Storage/6/x86_64/update/                                       suse/Storage/6/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/Storage/6/x86_64/update_debug/                                 suse/Storage/6/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Backports/SLE-15-SP3_x86_64/standard/                                  suse/Backports-SLE/15-SP3/x86_64/standard \
    -d  http://slemaster.us.cray.com/SUSE/Backports/SLE-15-SP3_x86_64/standard_debug/                            suse/Backports-SLE/15-SP3/x86_64/standard_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Basesystem/15-SP4/x86_64/product/                  suse/SLE-Module-Basesystem/15-SP4/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Basesystem/15-SP4/x86_64/product_debug/            suse/SLE-Module-Basesystem/15-SP4/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Containers/15-SP4/x86_64/product/                  suse/SLE-Module-Containers/15-SP4/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Containers/15-SP4/x86_64/product_debug/            suse/SLE-Module-Containers/15-SP4/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Basesystem/15-SP4/x86_64/update/                    suse/SLE-Module-Basesystem/15-SP4/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Containers/15-SP4/x86_64/update/                    suse/SLE-Module-Containers/15-SP4/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Containers/15-SP4/x86_64/update_debug/              suse/SLE-Module-Containers/15-SP4/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Desktop-Applications/15-SP4/x86_64/product/        suse/SLE-Module-Desktop-Applications/15-SP4/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Desktop-Applications/15-SP4/x86_64/product_debug/  suse/SLE-Module-Desktop-Applications/15-SP4/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Desktop-Applications/15-SP4/x86_64/update/          suse/SLE-Module-Desktop-Applications/15-SP4/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Desktop-Applications/15-SP4/x86_64/update_debug/    suse/SLE-Module-Desktop-Applications/15-SP4/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Development-Tools/15-SP4/x86_64/product/           suse/SLE-Module-Development-Tools/15-SP4/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Development-Tools/15-SP4/x86_64/product_debug/     suse/SLE-Module-Development-Tools/15-SP4/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Development-Tools/15-SP4/x86_64/update/             suse/SLE-Module-Development-Tools/15-SP4/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Development-Tools/15-SP4/x86_64/update_debug/       suse/SLE-Module-Development-Tools/15-SP4/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-HPC/15-SP4/x86_64/product/                         suse/SLE-Module-HPC/15-SP4/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-HPC/15-SP4/x86_64/product_debug/                   suse/SLE-Module-HPC/15-SP4/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-HPC/15-SP4/x86_64/update/                           suse/SLE-Module-HPC/15-SP4/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-HPC/15-SP4/x86_64/update_debug/                     suse/SLE-Module-HPC/15-SP4/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Legacy/15-SP4/x86_64/product/                      suse/SLE-Module-Legacy/15-SP4/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Legacy/15-SP4/x86_64/product_debug/                suse/SLE-Module-Legacy/15-SP4/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Legacy/15-SP4/x86_64/update/                        suse/SLE-Module-Legacy/15-SP4/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Legacy/15-SP4/x86_64/update_debug/                  suse/SLE-Module-Legacy/15-SP4/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Public-Cloud/15-SP4/x86_64/product/                suse/SLE-Module-Public-Cloud/15-SP4/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Public-Cloud/15-SP4/x86_64/product_debug/          suse/SLE-Module-Public-Cloud/15-SP4/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Public-Cloud/15-SP4/x86_64/update/                  suse/SLE-Module-Public-Cloud/15-SP4/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Public-Cloud/15-SP4/x86_64/update_debug/            suse/SLE-Module-Public-Cloud/15-SP4/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Server-Applications/15-SP4/x86_64/product/         suse/SLE-Module-Server-Applications/15-SP4/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Server-Applications/15-SP4/x86_64/product_debug/   suse/SLE-Module-Server-Applications/15-SP4/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Server-Applications/15-SP4/x86_64/update/           suse/SLE-Module-Server-Applications/15-SP4/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Server-Applications/15-SP4/x86_64/update_debug/     suse/SLE-Module-Server-Applications/15-SP4/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Web-Scripting/15-SP4/x86_64/product/               suse/SLE-Module-Web-Scripting/15-SP4/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Web-Scripting/15-SP4/x86_64/product_debug/         suse/SLE-Module-Web-Scripting/15-SP4/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Web-Scripting/15-SP4/x86_64/update/                 suse/SLE-Module-Web-Scripting/15-SP4/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Web-Scripting/15-SP4/x86_64/update_debug/           suse/SLE-Module-Web-Scripting/15-SP4/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Product-HPC/15-SP4/x86_64/product/                        suse/SLE-Product-HPC/15-SP4/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Product-HPC/15-SP4/x86_64/product_debug/                  suse/SLE-Product-HPC/15-SP4/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Product-HPC/15-SP4/x86_64/update/                          suse/SLE-Product-HPC/15-SP4/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Product-HPC/15-SP4/x86_64/update_debug/                    suse/SLE-Product-HPC/15-SP4/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Product-SLES/15-SP4/x86_64/product/                       suse/SLE-Product-SLES/15-SP4/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Product-SLES/15-SP4/x86_64/product_debug/                 suse/SLE-Product-SLES/15-SP4/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Product-SLES/15-SP4/x86_64/update/                         suse/SLE-Product-SLES/15-SP4/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Product-SLES/15-SP4/x86_64/update_debug/                   suse/SLE-Product-SLES/15-SP4/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Product-WE/15-SP4/x86_64/product/                         suse/SLE-Product-WE/15-SP4/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Product-WE/15-SP4/x86_64/product_debug/                   suse/SLE-Product-WE/15-SP4/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Product-WE/15-SP4/x86_64/update/                           suse/SLE-Product-WE/15-SP4/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Product-WE/15-SP4/x86_64/update_debug/                     suse/SLE-Product-WE/15-SP4/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/Storage/7/x86_64/product/                                     suse/Storage/7/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/Storage/7/x86_64/product_debug/                               suse/Storage/7/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/Storage/7/x86_64/update/                                       suse/Storage/7/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/Storage/7/x86_64/update_debug/                                 suse/Storage/7/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/Storage/6/x86_64/product/                                     suse/Storage/6/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/Storage/6/x86_64/product_debug/                               suse/Storage/6/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/Storage/6/x86_64/update/                                       suse/Storage/6/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/Storage/6/x86_64/update_debug/                                 suse/Storage/6/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Backports/SLE-15-SP4_x86_64/standard/                                  suse/Backports-SLE/15-SP4/x86_64/standard \
    -d  http://slemaster.us.cray.com/SUSE/Backports/SLE-15-SP4_x86_64/standard_debug/                            suse/Backports-SLE/15-SP4/x86_64/standard_debug \
    -d  https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64                                        kubernetes/el7/x86_64 \
    -d  https://artifactory.algol60.net/artifactory/hpe-mirror-mlnx_ofed_cx4plus/SLES15-SP3/x86_64/5.4-1.0.3.0/      hpe/mlnx_ofed_cx4plus/5.4 \
    -d  https://artifactory.algol60.net/artifactory/hpe-mirror-mlnx_ofed_cx4plus/SLES15-SP3/x86_64/5.6-1.0.3.3/      hpe/mlnx_ofed_cx4plus/5.6 \
    -d  https://artifactory.algol60.net/artifactory/sles-mirror/Updates/SLE-Product-SLES/15-SP2-LTSS/x86_64/update  cray/csm/sle-15sp2 \
    -d  https://artifactory.algol60.net/artifactory/sles-mirror/Updates/SLE-Product-SLES/15-SP2-LTSS/x86_64/update_debug  cray/csm/sle-15sp2 \
    -d  https://artifactory.algol60.net/artifactory/sles-mirror/Updates/SLE-Module-Server-Applications/15-SP3/x86_64/update/  cray/csm/sle-15sp2 \
    -d  https://artifactory.algol60.net/artifactory/sles-mirror/Updates/SLE-Module-Server-Applications/15-SP2/x86_64/update/  cray/csm/sle-15sp2 \
    -d  https://artifactory.algol60.net/artifactory/sles-mirror/Updates/SLE-Module-Basesystem/15-SP3/x86_64/update/ cray/csm/sle-15sp3 \
    -d  https://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Basesystem/15-SP3/x86_64/update/ cray/csm/sle-15sp3 \
    -
