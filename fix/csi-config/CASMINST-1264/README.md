# CASMINST-1264 Workaround

The NMN and UAI Macvlan subnets have overlapping subnets with the same VLanID

1. Go to the directory where CSI generated its configs. This will be under `/mnt/pitdata/prep/${SYSTEM_NAME}"
    > Ensure that the environment variable `SYSTEM_NAME` is set
    ```
    cd /mnt/pitdata/prep/${SYSTEM_NAME}
    ```
2. Copy off the original SLS file
    ```
    cp sls_input_file.json sls_input_file.json.original
    ```
3. Reformat the SLS file so it is readable
    ```
    cat sls_input_file.json.original | jq . > sls_input_file.json
    ```
4. Make another copy to use for comparison latter
    ```
    cp sls_input_file.json sls_input_file.json.original.pretty
    ```
5. Edit the NMN uai_macvlan subnet to use VLan 20 instead of VLan 2 in the `sls_input_file.json`. This value can be found under `.Networks.NMN.ExtraProperties.Subnets[].VlanID`. Make sure to edit the subnet with the name `uai_macvlan`
    The following block:
    ```json
            "Name": "uai_macvlan",
            "VlanID": 2,
            "Gateway": "10.252.0.1",
            "DHCPStart": "10.252.2.10",
            "DHCPEnd": "10.252.3.254"
        }
    ]
    ```
    To
    ```json
            "Name": "uai_macvlan",
            "VlanID": 20,
            "Gateway": "10.252.0.1",
            "DHCPStart": "10.252.2.10",
            "DHCPEnd": "10.252.3.254"
        }
    ]
    ```
6. Compare the edited `sls_input_file.json` file with the readable version of the original SLS file:
    ```
    # diff sls_input_file.json.original.pretty sls_input_file.json
    1401c1401
    <             "VlanID": 2,
    ---
    >             "VlanID": 20,
    ```
7. Lastly verify that the `sls_input_file.json` is valid json:
    ```
    # cat sls_input_file.json | jq
    ```
