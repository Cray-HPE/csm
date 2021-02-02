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
    echo $0 applied
else
    echo $0 already applied
fi

