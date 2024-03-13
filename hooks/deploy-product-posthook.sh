#!/bin/bash
#
# MIT License
#
# (C) Copyright 2022-2023 Hewlett Packard Enterprise Development LP
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

echo "INFO Running prehook for deploy product"

echo "INFO Upgrading weave and multus"
/srv/cray/scripts/common/apply-networking-manifests.sh
if [[ "$?" -ne 0 ]]; then
    echo "ERROR Upgrading weave and multus is unsuccessful"
    exit 1
else
    echo "INFO Successfully upgraded weave and multus"
fi

echo "INFO Upgrading coredns anti-affinity"
/usr/share/doc/csm/upgrade/scripts/k8s/apply-coredns-pod-affinity.sh
if [[ "$?" -ne 0 ]]; then
    echo "ERROR Upgrading coredns anti-affinity is unsuccessful"
    exit 1
else
    echo "INFO Successfully upgraded coredns anti-affinity"
fi

echo "INFO Starting the Kubernetes upgrade"
/usr/share/doc/csm/upgrade/scripts/k8s/upgrade_control_plane.sh
if [[ "$?" -ne 0 ]]; then
    echo "ERROR Kubernetes control plane upgrade failed "
    exit 1
else
    echo "INFO Kubernetes control plane upgrade successful"
fi

echo "INFO prehook for deploy product completed"