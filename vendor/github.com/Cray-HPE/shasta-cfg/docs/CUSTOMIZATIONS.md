# Overview

Each system will have it's own customizations.yaml. The intent of this file is
to hold any and all system specific customizations.

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

Product stream installers will take `customizations.yaml` and inject it into
Loftsman Manifests, adding the customizations for a chart to the `values` field
for that chart.

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
the yaml block/object/array without quotes. The quoting is just used to ensure
we have valid yaml at all times to use yaml parsing libraries.

## There is a hyphen/dash in my jinja lookup and its giving me an error

This is a limitation of jinja2. However, there is an easy fix!

```
"{{ foo['my-hyphen'].bar }}"
```

## What if I am removing/altering a pre-existing customization?

By design the `utils/migrate-customizations.sh` script synchronizes changes in
a conservative way since it does not want to remove existing system specific
values from a system repositories `customizations.yaml`.  This can mean that
changes introduced into a shasta-cfg distribution are not automatically picked
up on subsequent migrates which can cause issues.

To combat this developers can provide migration scripts in `utils/migrations/`
that modify the `customizations.yaml` more explicitly.  Please take a look at
the existing scripts in that directory if you need to create a new one.  They
all follow the same basic pattern of taking in the `customizations.yaml` file
and modifying it using a `yq` script.

### Example yq script to delete a key

```yaml
- command: delete
  path: spec.kubernetes.services.cray-keycloak.setup.image.pullPolicy
```

### Example yq script to modify a key

```yaml
- command: update
  path: spec.kubernetes.services.capsules-warehouse-server.config.server.authJwksUrl
  value: "http://cray-keycloak-http.services.svc.cluster.local/keycloak/realms/shasta/protocol/openid-connect/certs"
```

*NB* - You should only use this to update keys that are system independent!

### Complex yq scripts

If you need to make a more complex migration please refer to the [yq
documentation](https://mikefarah.gitbook.io/yq/commands/write-update#using-a-script-file-to-update)

### Testing your Migration Script

Note that the `utils/migrate-customizations.sh` script will run each migration
script only once and writes a file `utils/migrations/<script-name>.complete` to
indicate that a migration should not run again. If you need multiple testing
iterations you will need to ensure the system repository you use for testing is
cleaned up each time and your shasta cfg distribution is updated with further
changes to your migration scripts before retrying.

To test your migration script, ensure the corresponding `.complete` file does
not exist for your migration script and that `customizations.yaml` needs to be
fixed. Run `./utils/migrate-customizations.sh customizations.yaml` to run all
migrations missing a `.complete` file and update `customizations.yaml` in
place. Use `git diff` to verify the fix was successfully applied.

Afterwards clean up by using `git reset` and/or `git checkout` as appropriate.
