#!/usr/bin/python3
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

import subprocess
import base64
import json
import sys
from kubernetes import client, config

# To check the enablement of rack resiliency feature flag
def check_rr_enablement():
    # Run kubectl command and capture JSON output
    namespace = "loftsman"
    secret_name = "site-init"

    kubectl_cmd = ["kubectl", "-n", namespace, "get", "secret", secret_name, "-o", "json"]
    kubectl_output = subprocess.run(kubectl_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, check=True)

    # Parse JSON output
    secret_data = json.loads(kubectl_output.stdout)

    # Extract and decode the base64 data
    encoded_yaml = secret_data["data"]["customizations.yaml"]
    decoded_yaml = base64.b64decode(encoded_yaml).decode("utf-8")

    # Write the yaml output to a file
    output_file = "/tmp/customization.yaml"
    with open(output_file, "w") as f:
        f.write(decoded_yaml)

    # Define the key path
    output_file = "/tmp/customization.yaml"
    key_path = "spec.kubernetes.services.rack-resiliency.enabled"

    # Run yq command to extract the value
    yq_cmd = ["yq", "r", output_file, key_path]
    result = subprocess.run(yq_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, check=True)

    # Extract and clean the output
    rr_check = result.stdout.strip()

    print(f"Rack Resiliency Enabled: {rr_check}")
    return rr_check

def main():
    print("Checking Rack Resiliency enablement")
    rr_enabled = check_rr_enablement()
    if rr_enabled == "false":
      print("Not deploying the cray-rrs chart as Rack Resiliency is disabled.")
      sys.exit(1)

    print("Deploying the cray-rrs chart.")
    sys.exit(0)    

if __name__ == "__main__":
    main()
