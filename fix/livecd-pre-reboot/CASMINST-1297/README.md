# CASMINST-1297 Workaround

Before the PIT is rebooted to become m001 up to three steps need to be taken.

1. **Before** running `csi handoff bss-metadata` as instructed in 007-CSM-INSTALL-REBOOT:
    * Take a copy of `data.json`:
        ```bash
        pit# cp /var/www/ephemeral/configs/data.json ./data-bss.json 
        ```
   * Edit that file and make 2 changes:
        1. Find the entry corresponding to ncn-m001 (you can search for `hostname`). Remove this line from the `runcmd` array:
          ```
          "/srv/cray/scripts/metal/set-dhcp-to-static.sh",
          ```
        2. In the "Global" section update:
          ```
          "dns-server": "10.92.100.225 10.252.1.12",
          ```

          To (the only the IP of Unbound):
          ```
          "dns-server": "10.92.100.225",
          ```
   * Ensure when you do the handoff step you give the path to this patched file and not the one in the configs directory.
2. Before the PIT is rebooted into m001, the KEA pod in the services namespace needs restarted (**note** these commands be ran on the PIT or m002):
    > This is to help prevent issues with m001 PXE booting

    Determine the KEA pod name:
    ```
    ncn-w001:~ # kubectl -n services get pods | grep kea
    cray-dhcp-kea-6fc795c9f9-pdrq8                                 3/3     Running     0          15h
    ```

    Delete the currently running pod:
    ```
    ncn-w001:~ # kubectl -n services delete pod cray-dhcp-kea-6fc795c9f9-pdrq8
    pod "cray-dhcp-kea-6fc795c9f9-pdrq8" deleted
    ```

    Before rebooting wait for the KEA pod to become healthy:
    ```
    ncn-m001:~ # kubectl -n services get pods | grep kea
    cray-dhcp-kea-6fc795c9f9-6pd86                                 3/3     Running       0          78s
    ```
