#!/bin/bash
#
# MIT License
#
# (C) Copyright 2025 Hewlett Packard Enterprise Development LP
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

. /etc/cray/upgrade/csm/myenv

DONE_DIR="/etc/cray/upgrade/csm/${CSM_REL_NAME}"

JOB_NAMESPACE="argo"
JOB_PREFIX="upgrade-k8s-job-"
EXPECTED_VERSION="v1.32.5"

echo "INFO Starting post-upgrade checks..."

### 1. Check Kubernetes upgrade job status
echo "INFO Checking status of Kubernetes upgrade job..."

job_name=$(kubectl get jobs -n "$JOB_NAMESPACE" \
  --sort-by=.metadata.creationTimestamp \
  -o jsonpath="{.items[*].metadata.name}" | tr ' ' '\n' | grep "^$JOB_PREFIX" | tail -n1)
if [[ -z "$job_name" ]]; then
  echo "ERROR No job found for kubernetes upgrade in namespace $JOB_NAMESPACE"
  echo "ERROR Kubernetes upgrade job did not run successfully"
  exit 1
fi

echo "INFO Found job: $job_name"

job_status=$(kubectl get job "$job_name" -n "$JOB_NAMESPACE" -o jsonpath='{.status.succeeded}')
if [[ "$job_status" != "1" ]]; then
  echo "ERROR Kubernetes upgrade job $job_name did not complete successfully"
  exit 1
else
  echo "INFO Kubernetes upgrade job $job_name completed successfully"
fi

### 2. Check for any .done files
echo "INFO Checking for .done files in $DONE_DIR..."

done_files_found=$(find "$DONE_DIR" -name "*.done")
if [[ -n "$done_files_found" ]]; then
  echo "ERROR Found .done files:"
  echo "$done_files_found"
  echo "ERROR Kubernetes upgrade job did not complete successfully"
  exit 1
else
  echo "INFO No .done files found"
fi

### 3. Check Kubernetes client and server versions
echo "INFO Verifying Kubernetes client and server versions..."

client_version=$(kubectl version -o json | jq -r '.clientVersion.gitVersion')
server_version=$(kubectl version -o json | jq -r '.serverVersion.gitVersion')
if [[ "$client_version" == "$EXPECTED_VERSION" && "$server_version" == "$EXPECTED_VERSION" ]]; then
  echo "INFO Kubernetes client and server versions are both $EXPECTED_VERSION"
else
  echo "ERROR Kubernetes version is not as expected. Client: $client_version, Server: $server_version, Expected: $EXPECTED_VERSION"
  exit 1
fi

echo "INFO All post-upgrade checks passed successfully."
