# CASMINST-1403

Depending on the number of Compute Node NMN subnets required on your Shasta system, it is possible that CSI will leave stray uninitialized routes in the `spec.wlm.macvlansetup.routes` array near the beginning of `customizations.yaml`.  CSI also leaves a stray local route in that array, which should be harmless, but is good to remove since you are going to be looking anyway.

If there are stray uninitialized routes, you may find you have something like this:

```
spec:
  ...
  wlm:
    ...
    macvlansetup:
      nmn_subnet: 10.252.2.0/23
      nmn_supernet: 10.252.0.0/17
      nmn_supernet_gateway: 10.252.0.1
      nmn_vlan: vlan002
      # NOTE: the term DHCP here is misleading, this is merely
      #       a range of reserved IPs for UAIs that should not
      #       be handed out to others becase the network
      #       attachment will hand them out to UAIs.
      nmn_dhcp_start: 10.252.2.10
      nmn_dhcp_end: 10.252.3.254
      routes:
      - dst: 10.92.100.0/24
        gw: 10.252.0.1
      - dst: 10.106.0.0/17
        gw: 10.252.0.1
      - dst: 10.252.0.0/17
        gw: 10.252.0.1
      - dst: ~FIXME~ e.g., 10.104.0.0/17
        gw: ~FIXME~ e.g., 10.252.0.1
    ...
 ```

With respect to the stray local route, notice the route that looks like this in the above example:

```
      - dst: 10.252.0.0/17
        gw: 10.252.0.1
```

this route forwards to the network where its gateway resides, the local NMN supernet for the macvlan network attachment:

```
      nmn_supernet: 10.252.0.0/17
```

These two issues should be fixed before `customizations.yaml` is used to deploy manifests.  To do this, simply remove any routes that have the form:

```
      - dst: ~FIXME~ e.g., 10.104.0.0/17
        gw: ~FIXME~ e.g., 10.252.0.1
```

in the routes array, and also remove any route whose `dst` field is the same as the setting for `nmn_supernet`.

In the example above, this would look like this:

```
spec:
  ...
  wlm:
    ...
    macvlansetup:
      nmn_subnet: 10.252.2.0/23
      nmn_supernet: 10.252.0.0/17
      nmn_supernet_gateway: 10.252.0.1
      nmn_vlan: vlan002
      # NOTE: the term DHCP here is misleading, this is merely
      #       a range of reserved IPs for UAIs that should not
      #       be handed out to others becase the network
      #       attachment will hand them out to UAIs.
      nmn_dhcp_start: 10.252.2.10
      nmn_dhcp_end: 10.252.3.254
      routes:
      - dst: 10.92.100.0/24
        gw: 10.252.0.1
      - dst: 10.106.0.0/17
        gw: 10.252.0.1
    ...
```

If this means that there are no longer any routes in the `macvlansetup` section when you are done, then fill in an empty array for `routes` as follows:

```
spec:
  ...
  wlm:
    ...
    macvlansetup:
      nmn_subnet: 10.252.2.0/23
      nmn_supernet: 10.252.0.0/17
      nmn_supernet_gateway: 10.252.0.1
      nmn_vlan: vlan002
      # NOTE: the term DHCP here is misleading, this is merely
      #       a range of reserved IPs for UAIs that should not
      #       be handed out to others becase the network
      #       attachment will hand them out to UAIs.
      nmn_dhcp_start: 10.252.2.10
      nmn_dhcp_end: 10.252.3.254
      routes: []
    ...
```

In this last case, your system is set up with all compute nodes connected to the same NMN network that the NCNs are connected to, so no routing is needed to reach them.
