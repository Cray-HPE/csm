## CASMPET-3732 No healthy upstream for prometheus UI

#### Symptoms

1. Unable to load prometheus UI

##### Fix

1. Run the provided script on the LiveCD:
    ```bash
    kubectl -n vault delete ServiceMonitor cray-sysmgmt-health-vault-etcd-exporter
    ```
