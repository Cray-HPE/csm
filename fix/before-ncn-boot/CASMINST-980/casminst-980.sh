#!/bin/bash

set -e

data_file="${1:-/var/www/ephemeral/configs/data.json}"
token=dns-server
unbound_ip="${2:-10.92.100.225}"

if ! grep -q $unbound_ip $data_file ; then
    echo applying $0 to $data_file
    echo current $token value:
    cat $data_file | jq '.[]["meta-data"]["dns-server"] | select(.!=null)'
    sed -i -E 's/'$token'": "(.*)"/'$token'": "'"${unbound_ip}"' \1"/' $data_file
    echo new $token value:
    cat $data_file | jq '.[]["meta-data"]["dns-server"] | select(.!=null)'
    echo restarting basecamp
    systemctl restart basecamp
    echo $0 applied to basecamp
else
    if ! grep NETCONFIG_DNS_STATIC_SERVERS /etc/sysconfig/network/config | grep -q $unbound_ip ; then
        grep nameserver /etc/resolv.conf
        sed -i -E 's/NETCONFIG_DNS_STATIC_SERVERS="(.*)"/NETCONFIG_DNS_STATIC_SERVERS="'"${unbound_ip}"' \1"/' /etc/sysconfig/network/config
        netconfig update -f
        grep nameserver /etc/resolv.conf
        echo $0 applied to resolv.conf
    else
        echo $0 already applied
    fi
fi

