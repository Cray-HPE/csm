# Add Unbound to `data.json`

This adds unbound DNS as the first DNS server to NCNs. This allows it to take precedence once it is online, and in the meantime allow k8s/ceph to deploy with LiveCD DNS and /etc/hosts.

> NOTE: This WAR will restart basecamp.

After doing this, the NCNs will handle DNS handoff themselves. Editing of `/etc/resolv.conf` should not be required.

