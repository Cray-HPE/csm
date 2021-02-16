# WORKAROUND: NCN BMCs receiving duplicate IP address from DHCP

At the conclusion of the CSM install, there is an issue where the management NCN BMCs have both a static IP and a DHCP assigned IP address.  This affects our ability to power cycle management NCNs via CAPMC and apply firmware changes via FAS.  The following temporary procedure corrects this until a permanent fix is in place.

This manifests as the NCN BMC is no longer reached by its xname such as `x3000c0s4b0`, and the NCN BMC alias has multiple IP addresses:
```
ncn-w003:~ # nslookup ncn-w001-mgmt
Server:		10.92.100.225
Address:	10.92.100.225#53

Name:	ncn-w001-mgmt
Address: 10.254.1.56
Name:	ncn-w001-mgmt
Address: 10.254.1.13
```

> The following commands expect the cray cli to already be initialized by the `cray init` command

1. SSH to each ncn (except m001) and run `ipmitool mc reset cold`
2. Query HSM Ethernet interfaces table with the xname of the ncn BMCs (except m001)
    > Replace `x3000c0s4b0` with the xname of the NCN BMC that has an duplicate address

    ```json
    ncn-w003:~ # cray hsm inventory ethernetInterfaces list --component-id x3000c0s4b0 --format json | jq '.[] | {ID: .ID, Type: .Type, IPAddresses: .IPAddresses}' -c
    {"ID":"9440c9376760","Type":"NodeBMC","IPAddresses":[{"IPAddress":"10.254.1.56"}]}
    {"ID":"9440c9376761","Type":"NodeBMC","IPAddresses":[]}
    ```
3. Delete each NCN BMC MAC address that contains an IP address. (except for m001)
    > Replace `9440c9376760` with the normalized MAC address found in the command above
    ```
    ncn-w003:~ # cray hsm inventory ethernetInterfaces delete 9440c9376760
    code = 0
    message = "deleted 1 entry"
    ```
4. Wait a few minutes for DNS to settle and only 1 IP address should be present for both the xname hostname and bmc alias:
    The NCN BMC xname hostname should only have 1 address:
    ```
    ncn-w003:~ # nslookup x3000c0s4b0
    Server:		10.92.100.225
    Address:	10.92.100.225#53

    Name:	x3000c0s4b0.hmn
    Address: 10.254.1.13
    ```

    The NCN BMC alias should only have 1 address:
    ```
    ncn-w003:~ # nslookup ncn-w001-mgmt
    Server:		10.92.100.225
    Address:	10.92.100.225#53

    Name:	ncn-w001-mgmt
    Address: 10.254.1.13
    ```

5. The BMC should also now be pingable by its xname hostname and NCN BMC alias:
    ```
    ncn-w003:~ # ping x3000c0s4b0
    PING x3000c0s4b0.hmn (10.254.1.13) 56(84) bytes of data.
    64 bytes from ncn-w001-mgmt (10.254.1.13): icmp_seq=1 ttl=255 time=0.201 ms
    64 bytes from ncn-w001-mgmt (10.254.1.13): icmp_seq=2 ttl=255 time=0.221 ms
    ^C
    --- x3000c0s4b0.hmn ping statistics ---
    2 packets transmitted, 2 received, 0% packet loss, time 1000ms
    rtt min/avg/max/mdev = 0.201/0.211/0.221/0.010 ms
    ```

    ```
    ncn-w003:~ # ping ncn-w001-mgmt
    PING ncn-w001-mgmt (10.254.1.13) 56(84) bytes of data.
    64 bytes from ncn-w001-mgmt (10.254.1.13): icmp_seq=1 ttl=255 time=0.265 ms
    64 bytes from ncn-w001-mgmt (10.254.1.13): icmp_seq=2 ttl=255 time=0.206 ms
    ^C
    --- ncn-w001-mgmt ping statistics ---
    2 packets transmitted, 2 received, 0% packet loss, time 1000ms
    rtt min/avg/max/mdev = 0.206/0.235/0.265/0.033 ms
    ```