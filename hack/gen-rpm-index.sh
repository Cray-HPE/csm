#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

set -ex

# The repo options to rpm-index are generated from the CSM/csm-rpms repo as
# follows:
#
#   $ cat repos/suse.repos repos/hpe-spp.repos repos/cray-metal.repos repos/cray.repos | sed -e 's/#.*$//' -e '/[[:space:]]/!d' | awk '{ print "-d", $1, $3 }' | column -t
#
# Note that the kubernetes/el7/x86_64 repo is included as it is implicitly
# added by the ncn-k8s image.

docker run --rm -i arti.dev.cray.com/internal-docker-stable-local/packaging-tools:0.11.0 rpm-index -v \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Basesystem/15-SP2/x86_64/product/                  suse/SLE-Module-Basesystem/15-SP2/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/SLE-Module-Basesystem/15-SP2/x86_64/product_debug/            suse/SLE-Module-Basesystem/15-SP2/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Basesystem/15-SP2/x86_64/update/                    suse/SLE-Module-Basesystem/15-SP2/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/SLE-Module-Basesystem/15-SP2/x86_64/update_debug/              suse/SLE-Module-Basesystem/15-SP2/x86_64/update_debug \
    -d  http://car.dev.cray.com/artifactory/mirror-sles15sp2/Updates/SLE-Module-Basesystem-PTF/                  suse/SLE-Module-Basesystem/15-SP2/x86_64/ptf \
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
    -d  http://slemaster.us.cray.com/SUSE/Products/Storage/7/x86_64/product/                                     suse/Storage/7/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/Storage/7/x86_64/product_debug/                               suse/Storage/7/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/Storage/7/x86_64/update/                                       suse/Storage/7/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/Storage/7/x86_64/update_debug/                                 suse/Storage/7/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Products/Storage/6/x86_64/product/                                     suse/Storage/6/x86_64/product \
    -d  http://slemaster.us.cray.com/SUSE/Products/Storage/6/x86_64/product_debug/                               suse/Storage/6/x86_64/product_debug \
    -d  http://slemaster.us.cray.com/SUSE/Updates/Storage/6/x86_64/update/                                       suse/Storage/6/x86_64/update \
    -d  http://slemaster.us.cray.com/SUSE/Updates/Storage/6/x86_64/update_debug/                                 suse/Storage/6/x86_64/update_debug \
    -d  http://slemaster.us.cray.com/SUSE/Backports/SLE-15-SP2_x86_64/standard/                                  suse/Backports-SLE/15-SP2/x86_64/standard \
    -d  http://slemaster.us.cray.com/SUSE/Backports/SLE-15-SP2_x86_64/standard_debug/                            suse/Backports-SLE/15-SP2/x86_64/standard_debug \
    -d  http://car.dev.cray.com/artifactory/cos/SHASTA-3RD/sle15_sp2_ncn/x86_64/release/cos-2.1/                 cray/cos/sle-15sp2/x86_64 \
    -d  http://car.dev.cray.com/artifactory/cos/SHASTA-OS/sle15_sp2_ncn/noarch/release/cos-2.1/                  cray/cos/sle-15sp2/noarch \
    -d  http://car.dev.cray.com/artifactory/cos/SHASTA-OS/sle15_sp2_ncn/x86_64/release/cos-2.1/                  cray/cos/sle-15sp2/x86_64 \
    -d  http://car.dev.cray.com/artifactory/csm/CLOUD/sle15_sp2_ncn/x86_64/release/csm-1.0/                      cray/csm/sle-15sp2/x86_64 \
    -d  http://car.dev.cray.com/artifactory/csm/CSM/sle15_sp2_ncn/noarch/release/1.0/                            cray/csm/sle-15sp2/noarch \
    -d  http://car.dev.cray.com/artifactory/csm/CSM/sle15_sp2_ncn/noarch/release/csm-1.0/                        cray/csm/sle-15sp2/noarch \
    -d  http://car.dev.cray.com/artifactory/csm/CSM/sle15_sp2_ncn/x86_64/release/csm-1.0/                        cray/csm/sle-15sp2/x86_64 \
    -d  http://car.dev.cray.com/artifactory/csm/SCMS/sle15_sp2_ncn/x86_64/release/csm-1.0/                       cray/csm/sle-15sp2/x86_64 \
    -d  http://car.dev.cray.com/artifactory/csm/SPET/sle15_sp2_ncn/noarch/release/csm-1.0/                       cray/csm/sle-15sp2/noarch \
    -d  http://car.dev.cray.com/artifactory/csm/SPET/sle15_sp2_ncn/x86_64/release/csm-1.0/                       cray/csm/sle-15sp2/x86_64 \
    -d  http://car.dev.cray.com/artifactory/csm/UAS/sle15_sp2_ncn/x86_64/release/csm-1.0/                        cray/csm/sle-15sp2/x86_64 \
    -d  http://car.dev.cray.com/artifactory/ct-tests/HMS/sle15_sp2_ncn/x86_64/release/csm-1.0/                   cray/csm/sle-15sp2/x86_64 \
    -d  http://car.dev.cray.com/artifactory/slingshot-host-software/OFI-CRAY/sle15_sp2_ncn/noarch/dev/master/    cray/slingshot/sle-15sp2/noarch \
    -d  http://car.dev.cray.com/artifactory/slingshot-host-software/OFI-CRAY/sle15_sp2_ncn/x86_64/dev/master/    cray/slingshot/sle-15sp2/x86_64 \
    -d  http://car.dev.cray.com/artifactory/slingshot/SSHOT/sle15_sp2_ncn/x86_64/release/shasta-1.4/             cray/slingshot/sle-15sp2/x86_64 \
    -d  http://car.dev.cray.com/artifactory/sdu/SSA/sle15_sp2_ncn/noarch/release/sdu-1.1/                        cray/sdu/sle-15sp2/noarch \
    -d  http://car.dev.cray.com/artifactory/sdu/SSA/sle15_sp2_ncn/x86_64/release/sdu-1.1/                        cray/sdu/sle-15sp2/x86_64 \
    -d  https://arti.dev.cray.com/artifactory/csm-rpm-stable-local/hpe/                                          cray/csm/sle-15sp2/x86_64 \
    -d  http://car.dev.cray.com/artifactory/csm/CRAY-HPE/sle15_sp2_ncn/noarch/release/csm-1.0/                   cray/csm/sle-15sp2/noarch \
    -d  http://car.dev.cray.com/artifactory/csm/MTL/sle15_sp2_ncn/noarch/release/csm-1.0/                        cray/csm/sle-15sp2/noarch \
    -d  http://car.dev.cray.com/artifactory/csm/MTL/sle15_sp2_ncn/x86_64/release/csm-1.0/                        cray/csm/sle-15sp2/x86_64 \
    -d  https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64                                        kubernetes/el7/x86_64 \
-d  http://car.dev.cray.com/artifactory/csm/CLOUD/sle15_sp2_ncn/x86_64/release/csm-1.2/              cray/csm/sle-15sp2/x86_64 \
-d  http://car.dev.cray.com/artifactory/csm/SCMS/sle15_sp2_ncn/x86_64/release/csm-1.2/               cray/csm/sle-15sp2/x86_64 \
-d  http://car.dev.cray.com/artifactory/csm/MTL/sle15_sp2_ncn/noarch/dev/master/                     cray/csm/sle-15sp2/noarch \
-d  http://car.dev.cray.com/artifactory/csm/MTL/sle15_sp2_ncn/x86_64/dev/master/                     cray/csm/sle-15sp2/x86_64 \
-d  http://car.dev.cray.com/artifactory/csm/CSM/sle15_sp2_ncn/noarch/dev/master/                     cray/csm/sle-15sp2/noarch \
-d  http://car.dev.cray.com/artifactory/csm/CSM/sle15_sp2_ncn/x86_64/dev/master/                     cray/csm/sle-15sp2/x86_64 \
-d  http://car.dev.cray.com/artifactory/csm/SPET/sle15_sp2_ncn/noarch/dev/master                     cray/csm/sle-15sp2/noarch \
-d  https://arti.dev.cray.com/artifactory/csm-rpm-stable-local/sle-15sp2/                            cray/csm/sle-15sp2 \
-d  https://artifactory.algol60.net/artifactory/csm-rpms/hpe/unstable/                              cray/csm/sle-15sp2 \
-d  https://artifactory.algol60.net/artifactory/csm-rpms/hpe/unstable/sle-15sp2                              cray/csm/sle-15sp2 \
-d  https://artifactory.algol60.net/artifactory/csm-rpms/hpe/stable/sle-15sp2/                               cray/csm/sle-15sp2 \
-d  https://downloads.linux.hpe.com/SDR/repo/spp/SUSE_LINUX/                                                 hpe/spp \
-d  https://downloads.linux.hpe.com/SDR/repo/mlnx_ofed_cx4plus/SUSE_LINUX/                                   hpe/mlnx_ofed_cx4plus \
    -
