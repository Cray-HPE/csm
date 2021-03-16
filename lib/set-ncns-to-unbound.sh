#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

set -exo pipefail

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."

unbound_ip="$(kubectl get -n services service cray-dns-unbound-udp-nmn -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"

"${ROOTDIR}/lib/list-ncns.sh" | while read ncn; do
    echo >&2 "+ Updating ${ncn}"
    ssh -n -o "StrictHostKeyChecking=no" "root@${ncn}" \
        "sed -e 's/^\(NETCONFIG_DNS_STATIC_SERVERS\)=.*$/\1=\"${unbound_ip}\"/' -i /etc/sysconfig/network/config; netconfig update -f; grep nameserver /etc/resolv.conf | sed -e 's/^/${ncn}: /'"
done
