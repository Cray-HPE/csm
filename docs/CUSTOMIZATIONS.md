# Overview

Each system will have it's own customizations.yaml. The intent of this file is to
hold any and all system specific customizations.

The customizations.yaml is any and all customizations to be passed into
loftsman when deploying charts. Jinja2 syntax can be used, however, the context
is ONLY within the same file. You cannot use any external dependencies in this
file.

**Note:** customizations.yaml is REQUIRED to ALWAYS be valid yaml syntax.

**Warning:** `{{...}}` blocks must be wrapped in quotes.

It is not a jinja template, it is a yaml file that will render jinja lookups.
Even if the jinja block is quoted, it will still render lookups to yaml blocks.

Only [standard jinja2
filters](https://jinja.palletsprojects.com/en/2.11.x/templates/#builtin-filters)
are available.

Product stream installers will take ```customizations.yaml``` and
inject it into Loftsman Manifests, adding the customizations for a chart to the
`values` field for that chart.

This allows HPE to ship static loftsman manifests to customers without having
to do complex merging and comparisons, knowing defaults, changes to default,
and customizations.

# System-specific settings

The customizations.yaml requires various system-specific settings, whose values
contain `~FIXME~`, to be updated before running manifests are generated. It is
important to remember that these settings have no impact outside of
customizations.yaml. Parameters simply provide information for customizations,
e.g., charts under `kubernetes.services`. So if you're unsure about a
particular value, search customizations.yaml to see where it is used.
Consequently, if a parameter isn't used, then it's value doesn't matter;
although, keep in mind that a future upgrade may expect it to be set
appropriately. Lastly, avoid unnecessary complexity by creating _global_
parameters; reserve those for system-instrinsic settings or common settings
shared across charts. It's okay to have `~FIXME~` in chart-specific settings.

# FAQ

## Why can't I template a block of yaml?

You can! Even though you quote your jinja block, the rendering will expand into
the yaml block/object/array without quotes. The quoting is just used to ensure we
have valid yaml at all times to use yaml parsing libraries.

## There is a hyphen/dash in my jinja lookup and its giving me an error

This is a limitation of jinja2. However, there is an easy fix!

    "{{ foo['my-hyphen'].bar }}"

## What if I am removing/altering a pre-existing customization?

By design the `utils/sync.sh` script synchronizes changes in a conservative way since it
does not want to remove existing system specific values from a system repositories
`customizations.yaml`.  This can mean that changes introduced into the `stable` repository
are not automatically picked up on subsequent sync's which can cause issues.

To combat this developers can provide migration scripts in `utils/migrations/` that modify the
`customizations.yaml` more explicitly.  Please take a look at the existing scripts in that
directory if you need to create a new one.  They all follow the same basic pattern of
taking in the `customizations.yaml` file and modifying it using a `yq` script.

### Example yq script to delete a key

```
- command: delete
  path: spec.kubernetes.services.cray-keycloak.setup.image.pullPolicy
```

### Example yq script to modify a key

```
- command: update
  path: spec.kubernetes.services.capsules-warehouse-server.config.server.authJwksUrl
  value: "http://cray-keycloak-http.services.svc.cluster.local/keycloak/realms/shasta/protocol/openid-connect/certs"
```
*NB* - You should only use this to update keys that are system independent!

### Complex yq scripts

If you need to make a more complex migration please refer to the [yq documentation](https://mikefarah.gitbook.io/yq/commands/write-update#using-a-script-file-to-update)

### Testing your Migration Script

Testing your migration scripts is a little tricky since typically your script is just applying a change
you have already made to `customizations.yaml` in the `stable` repository.  The following steps
should allow you to verify that your migration script does what you want:

- Ensure you have pushed a branch with your migration script to the `stable` repository
- Check out one of the system repositories
- In the system repository run `./utils/sync.sh <your-branch>`
- You should see output indicating that your migration script was run
- Manually inspect `customizations.yaml` to ensure the expected change(s) were applied
  by your migration script

Afterwards ensure you don't commit the changes to the system repository you tested against by
using `git reset` and/or `git checkout` to clean up.

Note that the migration process will apply each script only once and writes a file
`utils/migrations/<script-name>.complete` to indicate that a migration should not run again.
If you need multiple testing iterations you will need to ensure the system repository you use for
testing is cleaned up each time and your `stable` repository branch is updated with further
changes to your migration scripts before retrying.


## Rough Mapping of Shasta 1.2 Ansible Variables to Shasta 1.3 Customizations

> Information is retained for reference purposes, and is not guaranteed to be accurate (subject to future deprecation)

| Parameter                              | Description                                       | Example Value (YAML) | `yq r` Arguments |
|----------------------------------------|---------------------------------------------------|----------------------|------------------|
| `network.ntp.hmn`                      | NTP host:port for the hardware management network | `"time-hmn:123"`     | |
| `network.river.node_management`        | NMN IPv4 subnet                                   | `"10.252.0.0/17"`    | `/etc/ansible/hosts/group_vars/all/networks.yml networks.node_management.blocks.ipv4.(label==river).network` |
| `network.river.hardware_management`    | HMN IPv4 subnet                                   | `"10.254.0.0/17"`    | `/etc/ansible/hosts/group_vars/all/networks.yml networks.hardware_management.blocks.ipv4.(label==river).network` |
| `network.macvlan.subnets.default`      |                                                   | `"10.252.0.0/17"`    | `/etc/ansible/hosts/group_vars/all/networks.yml networks.node_management.blocks.ipv4.(label==river).subnets.(label==default).network` |
| `network.macvlan.subnets.mtn`          |                                                   | `"10.100.0.0/17"`    | `/etc/ansible/hosts/group_vars/all/networks.yml networks.node_management.blocks.ipv4.(label==mountain).network` |
| `network.macvlan.gateways.mtn`         |                                                   | `"10.252.0.1"`       | `/etc/ansible/hosts/group_vars/all/networks.yml networks.node_management.blocks.ipv4.(label==river).gateway` |
| `network.macvlan.dhcp.start`           | Start of IPv4 range for UAIs                      | `"10.252.124.10"`    | `/etc/ansible/hosts/group_vars/all/networks.yml networks.node_management.blocks.ipv4.(label==river).subnets.(label==uai_macvlan).dhcp.start` |
| `network.macvlandhcp.end`              | End of IPv4 range for UAIs                        | `"10.252.125.244"`   | `/etc/ansible/hosts/group_vars/all/networks.yml networks.node_management.blocks.ipv4.(label==river).subnets.(label==uai_macvlan).dhcp.end` |
| `network.static_ips.dns.site_to_system_lookups` | CAN IP assigned to external DNS that enables resolution of customer-facing services | `"10.102.5.113"` | |
| `network.static_ips.dns.system_to_site_lookups` | DNS IP to resolve site/internet names    | `"172.30.84.40"`     | |
| `network.static_ips.api_gw.default`    | NMN IP assigned to istio-ingressgateway           | `"10.92.100.71"`     | `/etc/ansible/hosts/group_vars/all/networks.yml networks.node_management.blocks.ipv4.(label==services).subnets.(label==metallb).reserved.(label==api_gw_service).address` |
| `network.static_ips.api_gw.hmn`        | HMN IP assigned to istio-ingressgateway-hmn       | `"10.94.100.1"`      | `/etc/ansible/hosts/group_vars/all/networks.yml networks.hardware_management.blocks.ipv4.(label==services).subnets.(label==metallb).reserved.(label==hms_collector_service).address` |
| `network.static_ips.nmn_tftp`          | NMN IP reserved for tftp                          | `"10.92.100.60"`     | `/etc/ansible/hosts/group_vars/all/networks.yml networks.node_management.blocks.ipv4.(label==services).subnets.(label==metallb).reserved.(label==tftp_service).address` |
| `network.static_ips.hmn_tftp`          | HMN IP reserved for tftp                          | `"10.94.100.60"`     | `/etc/ansible/hosts/group_vars/all/networks.yml networks.hardware_management.blocks.ipv4.(label==services).subnets.(label==metallb).reserved.(label==tftp_service).address` |
| `network.static_ips.metal_lb.sshot_kafka` | NMN IP reserved for SLINGSHOT's Kafka          | `"10.92.100.76"`     | `/etc/ansible/hosts/group_vars/all/networks.yml networks.node_management.blocks.ipv4.(label==services).subnets.(label==metallb).reserved.(label==slingshot_kafka_extern_service).address` |
| `network.static_ips.fabric_lb.sshot_fabric_kafka` | NMN IP reserved for NextGen SLINGSHOT's Kafka          | `"10.92.100.76"`     | `/etc/ansible/hosts/group_vars/all/networks.yml networks.node_management.blocks.ipv4.(label==services).subnets.(label==metallb).reserved.(label==slingshot_kafka_extern_service).address` |
| `network.static_ips.ncn_masters`       | List of NMN IPv4 addresses for manager NCNs       | `["10.252.0.10", "10.252.0.11", "10.252.0.12"]` | `/etc/ansible/hosts/group_vars/all/networks.yml networks.node_management.blocks.ipv4.(label==river).subnets.(label==default).reserved.(label==ncn-m*).address` |
| `network.static_ips.ncn_storage`       | List of NMN IPv4 addresses for storage NCNs       | `["10.252.0.7", "10.252.0.8", "10.252.0.9"]` | `/etc/ansible/hosts/group_vars/all/networks.yml networks.node_management.blocks.ipv4.(label==river).subnets.(label==default).reserved.(label==ncn-s*).address` |
| `network.static_ips.slurmctld`         | NMN IP reserved for slurmctld                     | `10.252.124.2` | `/etc/ansible/hosts/group_vars/all/networks.yml networks.node_management.blocks.ipv4.(label==river).subnets.(label==uai_macvlan).reserved.(label==slurmctld_service).address` |
| `network.static_ips.slurmdbd`          | NMN IP reserved for slurmdbd                      | `10.252.124.3` | `/etc/ansible/hosts/group_vars/all/networks.yml networks.node_management.blocks.ipv4.(label==river).subnets.(label==uai_macvlan).reserved.(label==slurmdbd_service).address` |
| `network.static_ips.pbs`               | NMN IP reserved for PBS                           | `10.252.124.4` | `/etc/ansible/hosts/group_vars/all/networks.yml networks.node_management.blocks.ipv4.(label==river).subnets.(label==uai_macvlan).reserved.(label==pbs_service).address` |
| `network.static_ips.pbs_comm`          | NMN IP reserved for PBS comm                      | `10.252.124.5` | `/etc/ansible/hosts/group_vars/all/networks.yml networks.node_management.blocks.ipv4.(label==river).subnets.(label==uai_macvlan).reserved.(label==pbs_comm_service).address` |
| `repositories.containers`              | Not used, but required by schema                  | `{}` | |
| `repositories.helm`                    | Not used, but required by schema                  | `{}` | |
| `repositories.rpm`                     | Not used, but required by schema                  | `{}` | |
| `dns.domains.external`                 | Domain to use for customer-facing services that resolve to CAN IPs | `system-name.customer.domain.com`   | |
| `dns.urls.external.s3`                 | Customer access FQDN for Ceph-RGW                 | `s3.system-name.customer.domain.com`                 | |
| `dns.urls.external.auth`               | Customer access FQDN for authentication and authorization services (e.g., Keycloak) | `auth.system-name.customer.domain.com` | |
| `dns.urls.external.api`                | Customer access FQDN for Shasta API               | `shasta.system-name.customer.domain.com`             | |
| `dns.urls.internal.s3`                 | Cluster-internal FQDN for Ceph-RGW                | `rgw.local:8080`                                     | |
| `dns.urls.internal.api`                | Cluster-internal FQDN for Shasta API              | `api-gw-service-nmn.local`                           | |
| `dns.uis.prometheus_istio`             | Customer access FQDN for Istio's Prometheus       | `prometheus-istio.system-name.customer.domain.com`   | |
| `dns.uis.kiali_istio`                  | Customer access FQDN for Istio's Kiali            | `kiali-istio.system-name.customer.domain.com`        | |
| `dns.uis.jaeger_istio`                 | Customer access FQDN for Istio's Jaeger           | `jaeger-istio.system-name.customer.domain.com`       | |
| `dns.uis.prometheus_sysmgmt_health`    | Customer access FQDN for system management Prometheus | `prometheus.system-name.customer.domain.com`     | |
| `dns.uis.alertmanager_sysmgmt_health`  | Customer access FQDN for system management Alertmanager | `alertmanager.system-name.customer.domain.com` | |
| `dns.uis.grafana_sysmgmt_health`       | Customer access FQDN for system management Grafana | `grafana.system-name.customer.domain.com`           | |
| `dns.uis.vcs`                          | Customer access FQDN for VCS (i.e., Gitea)        | `vcs.system-name.customer.domain.com`                | |
| `dns.uis.sma_grafana`                  | Customer access FQDN for SMA Grafana              | `sma-grafana.system-name.customer.domain.com`        | |
| `dns.uis.sma_kibana`                   | Customer access FQDN for SMA Kibana               | `sma-kibana.system-name.customer.domain.com`         | |
| `dns.uis.nexus`                        | Customer access FQDN for Nexus                    | `nexus.system-name.customer.domain.com`              | |
