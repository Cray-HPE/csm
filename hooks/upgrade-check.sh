#!/bin/bash

script_start_time=$1
charts_pending=()

# checking the status of all helm charts present on the system
function get_helm_status() {
    count=0
    # Get the list of Helm releases
    helm list -A --output json | jq -r '.[] | "\(.name) \(.namespace) \(.chart) \(.updated) \(.status)"' |
    while IFS= read -r line; do
        # Parse the Helm release information
        chart_name=$(echo "$line" | awk '{print $3}')
        namespace=$(echo "$line" | awk '{print $2}')
        last_deployed_time=$(echo "$line" | awk '{print $4}')
        status_info=$(echo "$line" | awk '{print $8}')

        # Convert last deployed time to timestamp
        last_deployed_timestamp=$(date -u -d "$last_deployed_time" +"%Y-%m-%dT%H:%M:%SZ")


        # Compare last deployed time with script start time
        if [[ "$last_deployed_timestamp" > "$script_start_time" ]]; then
            if [ "$status_info" == "failed" ]; then
                echo "ERROR Chart Name: $chart_name , Namespace: $namespace has failed"
                exit 1
            elif [ ! "$status_info" == "deployed" ] && [ ! "$status_info" == "superseded" ]; then
                count=$count+1
				chart="$chart_name $namespace"
				charts_pending+=("$chart")
            fi
        fi
    done
}

#checking for charts with 'pending' status
function get_helm_status_update() {
	count=0
	temp=()
	for chart in "${charts_pending[@]}"; do
		IFS=' ' read -r chart_name namespace <<< "$chart"
		status_info=$(helm status $chart_name -n $namespace --output json | jq -r .info.status)
		if [ "$status_info" == "failed" ]; then
            echo "ERROR Chart Name: $chart_name , Namespace: $namespace has failed"
            exit 1
        elif [ ! "$status_info" == "deployed" ] && [ ! "$status_info" == "superseded" ]; then
            count=$count+1
			temp+=("$chart")
        fi
	done
	charts_pending=("${temp[@]}")
}

get_helm_status

if [ $count -gt 0 ]; then
    echo "DEBUG Waiting before CSM Health check as $count Helm Charts are in pending state"
    sleep 30
    while true; do
        get_helm_status_update

        if [ $count -eq 0 ]; then
            break
        else
            echo "DEBUG Waiting before CSM Health check as $count Helm Charts are in pending state"
            sleep 30
        fi
    done
fi