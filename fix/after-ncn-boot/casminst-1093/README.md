## CASMINST-1093 cloud-init failure/race-condition

> Related: CASMINST-778 CASMTRIAGE-645

#### Symptoms

1. NCN boots with a hostname of `ncn`
2. This command returns meta-data:
    ```bash
    ncn:~ # curl http://pit.mtl:8888/meta-data
    ```
3. No cloud-init jobs ran, or it returned `SUCCESS` in `/var/log/cloud-init-output.log` despite no hostname being set.
4. `mgmt0` is not in the bond, and has an MTU of 1500. `mgmt1` is in the bond, and has jumboframes (9000 MTU) enabled
   ```bash
   4: mgmt0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP mode DEFAULT group default qlen 1000
    link/ether b8:59:9f:34:89:4a brd ff:ff:ff:ff:ff:ff
   5: mgmt1: <BROADCAST,MULTICAST,SLAVE,UP,LOWER_UP> mtu 9000 qdisc mq master bond0 state UP mode DEFAULT group default qlen 1000
    link/ether b8:59:9f:34:89:4a brd ff:ff:ff:ff:ff:ff
   ```

##### Fix

1. Note the routing on the node prior to running anything:
   ```bash
   ncn:~ # ip r
   default via 10.252.0.1 dev vlan002
   10.103.8.0/24 dev vlan007 proto kernel scope link src 10.103.8.16
   10.252.0.0/17 dev vlan002 proto kernel scope link src 10.252.1.9
   10.254.0.0/17 dev vlan004 proto kernel scope link src 10.254.1.29
   ```

2. Note if ping works, it shouldn't. If it does, there may be something else at play.
   If these do not ping, please continue onto step 3. If they do, inspect the pit Basecamp logs for other failures. (`podman log -f basecamp`)
   ```bash
   ncn:~ # ping 10.252.0.1
   ncn:~ # ping pit.mtl
   ncn:~ # ping pit.nmn
   # Check if meta-data can be fetched.. it should fail or have no payload.
   ncn:~ # curl http://pit.mtl:8888/meta-data
   ```

3. If this problem is on the LiveCD's node, after it has rebooted. Do this step, otherwise if this is regarding any NCN being deployed by the LiveCD **skip this step** and go to step 4.

   We need the route and cfg file from the USB stick in order to successfully fix this.
   ```bash
   ncn:~ # mount -L cow /mnt
   ncn:~ # cp /mnt/cow/rw/etc/sysconfig/network/ifroute-vlan002 /etc/sysconfig/network/ifroute-vlan002
   ncn:~ # cp /mnt/cow/rw/etc/sysconfig/network/ifroute-lan0 /etc/sysconfig/network/ifroute-lan0
   ncn:~ # cp /mnt/cow/rw/etc/sysconfig/network/ifcfg-lan0 /etc/sysconfig/network/ifcfg-lan0
   ```

4. On the same NCN, run this to create the additional configuration files for the NCN's interfaces. This attaches daemons to the interfaces, and retries setting up the bond.
   This will restore connectivity, if it does not please inspect the network switch configuration or cabeling.
   ```bash
   # Optionally start a screen
   ncn:~ # screen -mS casminst-10
   ncn:~ # /srv/cray/scripts/metal/set-dhcp-to-static.sh
   ```
   Now you can detach with `^A D` (ctrl+`a` then `d`).

5. Take note of the routing and ping again:
   ```bash
   ncn:~ # ip r
   default via 10.103.8.20 dev vlan007
   10.32.0.0/12 dev weave proto kernel scope link src 10.39.0.0
   10.92.100.0/24 via 10.252.0.1 dev vlan002
   10.103.8.0/24 dev vlan007 proto kernel scope link src 10.103.8.16
   10.252.0.0/17 dev vlan002 proto kernel scope link src 10.252.1.9
   10.254.0.0/17 dev vlan004 proto kernel scope link src 10.254.1.29
   ```

6. Finally, re-run cloud-init to finalize the deployment:
    ```bash
    ncn:~ # cloud-init clean
    ncn:~ # cloud-init init
    ncn:~ # cloud-init modules -m init
    ncn:~ # cloud-init modules -m config
    ncn:~ # cloud-init modules -m final
    ```

7. After the prompt returns, run `hostname` to print off the nodes hostname, if it still prints `ncn` then this failed. Please reinspect the deployment stack.
