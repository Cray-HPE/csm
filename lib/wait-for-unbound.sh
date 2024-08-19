#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2022, 2024 Hewlett Packard Enterprise Development LP
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

set -exo pipefail

function clean_up_unbound_manager_jobs() {

    # Get the list of all unfinished or failed jobs in the services namespace
    unfinished_jobs=$(kubectl -n services get jobs -o go-template --template '{{ range .items }}{{ if or .status.active .status.failed }}{{ .metadata.name }}{{ "\n" }}{{ end }}{{ end }}' || true)

    for job in ${unfinished_jobs};do
        # Only delete the job if it is a cray-dns-unbound-manager job
        if [[ $job =~ "cray-dns-unbound-manager" ]]; then
            echo "deleting stale job"
            kubectl delete jobs -n services $job
            echo "kubectl delete jobs -n services $job"
        fi
    done
}

# Clean-up unbound-manager jobs that didn't finish before validating unbound
clean_up_unbound_manager_jobs

# Wait for SLS init load job to complete
kubectl wait -n services job cray-sls-init-load --for=condition=complete --timeout=20m

# Wait for unbound to be available
kubectl wait -n services deployment cray-dns-unbound --for=condition=available --timeout=20m

# Wait for coredns job to complete
kubectl wait -n services job cray-dns-unbound-coredns --for=condition=complete --timeout=20m

# Wait for at least cone cray-dns-unbound-manager job to complete
function poll-saw-completed-job() {
    while [[ $(kubectl get event -n services --field-selector "involvedObject.kind=CronJob,involvedObject.name=cray-dns-unbound-manager,reason=SawCompletedJob" -o json | jq '.items | length') -eq 0 ]]; do
        echo >&2 "waiting for cronjob.batch/cray-dns-unbound-manager to run a job"
        sleep 10s
    done
}
export -f poll-saw-completed-job
timeout 20m bash -c 'set -exo pipefail; poll-saw-completed-job'
# Since one manager job has already completed, should only need to wait a
# minute for the next to run
kubectl wait -n services job -l cronjob-name=cray-dns-unbound-manager --for=condition=complete --timeout=5m

# Reads "IP HOSTNAME[ ...]" lines from stdin and verifies that Unbound resolves
# each HOSTNAME to the expected IP.
function verify() {
    local unbound_nmn_ip="$(kubectl get -n services service cray-dns-unbound-udp-nmn -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
    local failures=0

    while read ipaddr hostnames; do
        read -a names <<< "$hostnames"
        for ((attempt=1 ; attempt <= 10 ; attempt++)); do
            failures=0
            for h in "${names[@]}"; do
                if [[ "$ipaddr" == "$(dig "@${unbound_nmn_ip}" +short "$h")" ]]; then
                    echo >&2 "ok: unbound resolves: ${h} -> ${ipaddr}"
                else 
                    echo >&2 "error: Unbound resolution failure: ${h} does not resolve to ${ipaddr}"
                    ((failures++)) || true
                fi
            done

            if [[ $failures -eq 0 ]]; then
                echo >&2 "ok: all expected hostnames resolved!"
                break
            fi

            if [[ $attempt -ge 10 ]]; then
                echo >&2 "error: exceeded the number of allow attempts waiting for hostnames to resolve"
                break
            fi

            sleep 10
        done
    done
    return $failures
}

ingress_ip="$(kubectl get -n istio-system service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"

# Verify Unbound is can resolve the expected addresses
verify <<EOF
${ingress_ip} packages.local registry.local
EOF

