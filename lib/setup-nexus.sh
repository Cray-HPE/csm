#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

set -exo pipefail

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")/.."
source "${ROOTDIR}/lib/version.sh"
source "${ROOTDIR}/lib/install.sh"

# Check for required resources for Nexus setup
nexus_resources_ready=0
counter=1
counter_max=10
sleep_time=30
url=packages.local

while [[ $nexus_resources_ready -eq 0 ]] && [[ "$counter" -le "$counter_max" ]]; do
    nexus_check_configmap=$(kubectl -n services get cm cray-dns-unbound -o json 2>&1 | jq '.binaryData."records.json.gz"' -r 2>&1 | base64 -d 2>&1| gunzip - 2>&1|jq 2>&1|grep $url|wc -l)
    nexus_check_dns=$(dig $url +short |wc -l)
    nexus_check_pod=$(kubectl get pods -n nexus|grep nexus|awk {' print $3 '})

    if [[ "$nexus_check_dns" -eq "1" ]] && [[ "$nexus_check_pod" == "Running" ]]; then
        echo "$url is in dns."
        echo "Nexus pod $nexus_check_pod."
        echo "Moving forward with Nexus setup."
        nexus_resources_ready=1
    fi
    if [[ "$nexus_check_pod" != "Running" ]]; then
        echo "Nexus pod not ready yet."
        echo "Nexus pod status is: $nexus_check_pod."
    fi

    if [[ "$nexus_check_dns" -eq "0" ]]; then
        echo "$url is not in DNS yet."
        if [ "$nexus_check_configmap" -lt "1" ]; then
            echo "$url is not loaded into unbound configmap yet."
            echo "Waiting for DNS and nexus pod to be ready. Retry in $sleep_time seconds. Try $counter out of $counter_max."
        fi
    fi
    if [[ "$counter" -eq "$counter_max" ]]; then
        echo "Max number of checks reached, exiting."
        echo "Please check the status of nexus, cray-dns-unbound and cray-sls."
        exit 1
    fi
    ((counter++))
done

# get unbound ip for dns in podman
unbound_ip="$(kubectl get -n services service cray-dns-unbound-udp-nmn -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"

load-install-deps

# Setup Nexus
nexus-setup blobstores   "${ROOTDIR}/nexus-blobstores.yaml" "$unbound_ip"
nexus-setup repositories "${ROOTDIR}/nexus-repositories.yaml" "$unbound_ip"

# Upload assets to existing repositories
for source_dir in $(ls ${ROOTDIR}/docker/)
do
  echo "Uploading docker images from ${ROOTDIR}/docker/${source_dir}"
  skopeo-sync "${ROOTDIR}/docker/${source_dir}" "$unbound_ip"
done

nexus-upload helm "${ROOTDIR}/helm" "${CHARTS_REPO:-"charts"}" "$unbound_ip"

# Upload repository contents
nexus-upload raw "${ROOTDIR}/rpm/cray/csm/sle-15sp2"         "csm-${RELEASE_VERSION}-sle-15sp2"         "$unbound_ip"
nexus-upload raw "${ROOTDIR}/rpm/cray/csm/sle-15sp2-compute" "csm-${RELEASE_VERSION}-sle-15sp2-compute" "$unbound_ip"
nexus-upload raw "${ROOTDIR}/rpm/shasta-firmware"            "shasta-firmware-${RELEASE_VERSION}"       "$unbound_ip"

clean-install-deps

set +x
cat >&2 <<EOF
+ Nexus setup complete
setup-nexus.sh: OK
EOF
