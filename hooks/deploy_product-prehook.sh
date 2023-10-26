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
echo "Upgrading weave and multus."

/srv/cray/scripts/common/apply-networking-manifests.sh

echo "Upgrading coredns anti-affinity."

/usr/share/doc/csm/upgrade/scripts/k8s/apply-coredns-pod-affinity.sh

echo "Complete the Kubernetes upgrade."

/usr/share/doc/csm/upgrade/scripts/k8s/upgrade_control_plane.sh

echo "Waiting for 15 minutes before CSM Health check"

sleep 900

#we need admin password

VAULT_PASSWD=$(kubectl -n vault get secrets cray-vault-unseal-keys -o json | jq -r '.data["vault-root"]' |  base64 -d)
alias vault='kubectl -n vault exec -i cray-vault-0 -c vault -- env VAULT_TOKEN="$VAULT_PASSWD" VAULT_ADDR=http://127.0.0.1:8200 VAULT_FORMAT=json vault'
SW_ADMIN_PASSWORD=$(vault kv get secret/net-creds/switch_admin | jq '.data.admin')

/opt/cray/tests/install/ncn/automated/ncn-k8s-combined-healthcheck

TARFILE="csm_upgrade.$(date +%Y%m%d_%H%M%S).logs.tgz"
tar -czvf "/root/${TARFILE}" /root/csm_upgrade.*.txt /root/output.log

cray artifacts create config-data "${TARFILE}" "/root/${TARFILE}"