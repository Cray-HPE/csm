# Update System-Specific Repository

SHASTA-CFG is packaged as part of the CSM release under the `shasta-cfg`
directory. The following procedures reference the absolute path to the
`shasta-cfg` directory in the CSM release using the `CFGDIR` variable. Also,
the system-specific repository directory is given by the `SITEDIR` variable.

**Note:** On the pit server, the typical settings are:

```bash
pit:~ # CFGDIR=/var/www/ephemeral/csm-${CSM_RELEASE}/shasta-cfg
pit:~ # SITEDIR=/var/www/ephemeral/prep/site-init
```

or the following if following the CRAY System Management Guide:

```bash
pit:~ # CFGDIR=/mnt/pitdata/csm-${CSM_RELEASE_VERSION}/shasta-cfg
pit:~ # SITEDIR=/mnt/pitdata/prep/site-init
```

# Procedure

1.  Migrate (i.e., update) the existing system repository with new settings in
    `$CFGDIR`.

    ```bash
    pit:~ # "${CFGDIR}/meta/init.sh" "$SITEDIR"
    Source Directory is: $CFGDIR
    Target Dirctory is: $SITEDIR
    Copying docs...
    Copying scripts/utils...
    Migrating customizations...
    01_sealed_secrets migration previously completed, skipping...
    02_ingressgatewayhmn migration previously completed, skipping...
    02_keycloak migration previously completed, skipping...
    03_capsules migration previously completed, skipping...
    04_nexus migration previously completed, skipping...
    05_sysmgmt-health migration previously completed, skipping...
    06_unbound_airgap_forwarder migration previously completed, skipping...
    07_istio_opa_issuers migration previously completed, skipping...
    08_keycloak_sealed_secrets migration previously completed, skipping...
    09_reset_nexus_config migration previously completed, skipping...
    Deleting existing sealed secret from source spec.kubernetes.sealed_secrets.cray-keycloak
    Deleting existing sealed secret from source spec.kubernetes.sealed_secrets.keycloak_master_admin_auth
    Deleting existing sealed secret from source spec.kubernetes.sealed_secrets.gitea
    Deleting existing sealed secret from source spec.kubernetes.sealed_secrets.gen_platform_ca_1
    Deleting existing sealed secret from source spec.kubernetes.sealed_secrets.pals
    Deleting existing sealed secret from source spec.kubernetes.sealed_secrets.munge
    Deleting existing sealed secret from source spec.kubernetes.sealed_secrets.slurmdb
    Deleting existing sealed secret from source spec.kubernetes.sealed_secrets.keycloak_users_localize
    Creating sealed secret key-pair if needed...
    Certs already exist, use SEALED_SECRETS_REGEN=true to regenerate.
    You SHOULD to take a backup to reencrypt any secrets that from the 'old' key!
    Creating git repo at target (if not already a repo)

    **** IMPORTANT: Review and update $SITEDIR/customizations.yaml and introduce custom edits (if applicable). ****
    ```

2.  As directed, update `customizations.yaml` content as directed by the
    installation procedure(s), paying particular attention to sealed secrets
    (REDS/MEDS/RTS sealed secrets, generators, plain secrets if any) and any
    `~FIXME~` values listed elsewhere.

3.  Encrypt secret content in `customizations.yaml`:

    ```bash
    pit:~ # “${SITEDIR}/utils/secrets-reencrypt.sh” “${SITEDIR}/customizations.yaml” “${SITEDIR}/certs/sealed_secrets.key” “${SITEDIR}/certs/sealed_secrets.crt”
    pit:~ # “${SITEDIR}/utils/secrets-seed-customizations.sh” “${SITEDIR}/customizations.yaml”
    Creating Sealed Secret cray_reds_credentials
      Generating type static...
      Generating type static...
    Creating Sealed Secret cray_meds_credentials
      Generating type static...
    Creating Sealed Secret cray_hms_rts_credentials
      Generating type static...
      Generating type static...
    ```

4.  Optionally add, commit, and push your git changes to an upstream repo. If
    production system or operational security is a concern, store your sealed
    secret key-pair outside of git/in a secure offline system.

    **Note:** The key pair will be required to migrate future upstream changes
    to your existing system repository or to run product stream installers.
