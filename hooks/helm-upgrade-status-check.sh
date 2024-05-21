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

# start time for charts deployment
charts_deployment_start_time=$1
# list for charts upgraded
charts_upgraded=()
# list for charts in pending state
charts_pending=()
# counter for charts in pending state
count=0

# checking the status of all helm charts present on the system and upgraded helm charts
function get_upgraded_helm_charts() {
    # Get the list of Helm releases in JSON format and process each line
    helm list -A --output json | jq -r '.[] | "\(.name) \(.namespace) \(.chart) \(.updated) \(.status)"' |
    while IFS= read -r line; do
        # Parse the Helm release information from each line
        chart_name=$(echo "$line" | awk '{print $3}')
        namespace=$(echo "$line" | awk '{print $2}') 
        last_deployed_time=$(echo "$line" | awk '{print $4}')
        status_info=$(echo "$line" | awk '{print $8}')
        last_deployed_timestamp=$(date -u -d "$last_deployed_time" +"%Y-%m-%dT%H:%M:%SZ")

        # Compare last deployed time with script start time
        if [[ $last_deployed_timestamp > $charts_deployment_start_time ]]; then
            count=$((count + 1))
            chart="$chart_name $namespace"
	    # Add chart to upgraded list
            charts_upgraded+=("$chart")
        fi
    done
}

# Checking for charts with 'pending' status and removing deployed status from pending list
function get_pending_helm_charts() {
    for ((i=0; i<${#charts_pending[@]}; i++)); do
        chart=${charts_pending[i]}
        # Split chart name and namespace
        IFS=' ' read -r chart_name namespace <<< "$chart"
        # Get status of the chart from Helm and extract status info
        status_info=$(helm status $chart_name -n $namespace --output json | jq -r .info.status)
        if [[ $status_info == "failed" || $status_info == "unknown" ]]; then
            echo "ERROR Deployment of chart: $chart_name , namespace: $namespace has failed"
            exit 1
        # If status is deployed or superseded, remove chart from pending list
        elif [[ $status_info == "deployed" || $status_info == "superseded" || $status_info == "uninstalled" ]]; then
            unset 'charts_pending[i]'
            count=$((count - 1))
        fi
    done
}


get_upgraded_helm_charts
#First time while checking pending charts use list of upgraded charts
charts_pending=("${charts_upgraded[@]}")
while [[ $count -gt 0 ]]; do
    get_pending_helm_charts
    echo "INFO Waiting for upgrade to complete for $count Helm Charts"
    sleep 30
done
