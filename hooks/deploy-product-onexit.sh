#!/bin/bash
#
# MIT License
#
# (C) Copyright 2024 Hewlett Packard Enterprise Development LP
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

echo "INFO Running Onexit handler for deploy product"

echo "INFO Upgrading weave and multus"
/srv/cray/scripts/common/apply-networking-manifests.sh
if [[ $? -ne 0 ]]; then
    echo "ERROR Failed to upgrade weave and multus"
    exit 1
else
    echo "INFO Successfully upgraded weave and multus"
fi

echo "INFO Upgrading coredns anti-affinity"
/usr/share/doc/csm/upgrade/scripts/k8s/apply-coredns-pod-affinity.sh
if [[ $? -ne 0 ]]; then
    echo "ERROR Failed to upgrade coredns anti-affinity"
    exit 1
else
    echo "INFO Successfully upgraded coredns anti-affinity"
fi

echo "INFO Starting the kubernetes upgrade"
/usr/share/doc/csm/upgrade/scripts/k8s/upgrade_control_plane.sh
if [[ $? -ne 0 ]]; then
    echo "ERROR Failed to upgrade kubernetes control plane"
    exit 1
else
    echo "INFO Successfully upgraded kubernetes control plane"
fi

echo "INFO Onexit handler for deploy product completed"
