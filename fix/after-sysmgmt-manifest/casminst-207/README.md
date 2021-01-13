This workaround changes the ExternalTrafficPolicy to Cluster for the cray-tftp and cray-tftp-hmn services.

Execute the following commands on the LiveCD (m001) node.

    kubectl -n services patch service cray-tftp --patch "$(cat patch-tftp-traffic-policy.yaml)"
    kubectl -n services patch service cray-tftp-hmn --patch "$(cat patch-tftp-traffic-policy.yaml)"
