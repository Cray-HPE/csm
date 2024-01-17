#!/bin/bash

script_start_time=$1
echo "script start time is $script_start_time"
charts_pending=()

function get_helm_release_info_initial() {
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

        #echo "Chart Name: $chart_name"
        #echo "Namespace: $namespace"
        #echo "Last Deployed Time: $last_deployed_time"
        #echo "Release Status: $status_info"

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

function get_helm_release_info() {
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

get_helm_release_info_initial
if [[ $? -ne 0 ]]; then
	exit 1
fi

if [ $count -eq 0 ]; then
    echo "INFO upgrading CSM applications and services Completed"
    exit 0
elif [ $count -gt 0 ]; then
    echo "DEBUG Waiting before CSM Health check as $count Helm Charts are in pending state"
    sleep 30
fi
	
	
while true; do
    get_helm_release_info
    if [[ $? -ne 0 ]]; then
        exit 1
    fi

    if [ $count -eq 0 ]; then
        echo "INFO upgrading CSM applications and services Completed"
        exit 0
    elif [ $count -gt 0 ]; then
        echo "DEBUG Waiting before CSM Health check as $count Helm Charts are in pending state"
        sleep 30
    fi
done