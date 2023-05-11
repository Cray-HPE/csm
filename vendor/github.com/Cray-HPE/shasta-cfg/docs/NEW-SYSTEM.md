# Create System-Specific Repository

SHASTA-CFG is packaged as part of the CSM release under the `shasta-cfg`
directory. The following procedures reference the absolute path to the
`shasta-cfg` directory in the CSM release using the `CFGDIR` variable. Also,
the system-specific repository directory is given by the `SITEDIR` variable.

**Note:** On the pit server, the typical settings are:

```bash
pit:~ # CFGDIR=/var/www/ephemeral/csm-${CSM_RELEASE}/shasta-cfg
pit:~ # SITEDIR=/var/www/ephemeral/prep/site-init
```

## Procedure


1.  Create and initialize a new directory to store the system’s configuration:

    ```bash
    pit:~ # mkdir -p “$SITEDIR”
    pit:~ # “${CFGDIR}/meta/init.sh” “$SITEDIR”
    Source Directory is: $CFGDIR
    Target Directory is: $SITEDIR
    Copying docs...
    Copying scripts/utils...
    Migrating customizations...
    Creating sealed secret key-pair if needed...
    Generating a 4096 bit RSA private key
    ....................................................................++
    ....................................................................................................++
    writing new private key to '$SITEDIR/certs/sealed_secrets.key'
    -----
    Creating git repo at target (if not already a repo)
    Initializing git repository in $SITEDIR
    Initialized empty Git repository in $SITEDIR/.git/

    **** IMPORTANT: Review and update $SITEDIR/customizations.yaml and introduce custom edits (if applicable). ****
    ```

2.  As directed, update `customizations.yaml` content as directed by the
    installation procedure(s), paying particular attention to sealed secrets
    (generators, plain secrets if any) and any `~FIXME~` values listed
    elsewhere.

3.  Encrypt secret content in `customizations.yaml`:

    ```bash
    pit:~ # “${SITEDIR}/utils/secrets-reencrypt.sh” “${SITEDIR}/customizations.yaml” “${SITEDIR}/certs/sealed_secrets.key” “${SITEDIR}/certs/sealed_secrets.crt”
    pit:~ # “${SITEDIR}/utils/secrets-seed-customizations.sh” “${SITEDIR}/customizations.yaml”
    Creating Sealed Secret keycloak-certs
      Generating type static_b64...
    Creating Sealed Secret keycloak-master-admin-auth
      Generating type static...
      Generating type static...
      Generating type randstr...
      Generating type static...
    Creating Sealed Secret cray_reds_credentials
      Generating type static...
      Generating type static...
    Creating Sealed Secret cray_meds_credentials
      Generating type static...
    Creating Sealed Secret cray_hms_rts_credentials
      Generating type static...
      Generating type static...
    Creating Sealed Secret vcs-user-credentials
      Generating type randstr...
      Generating type static...
    Creating Sealed Secret generated-platform-ca-1
      Generating type platform_ca...
    Creating Sealed Secret pals-config
      Generating type zmq_curve...
      Generating type zmq_curve...
    Creating Sealed Secret munge-secret
      Generating type randstr...
    Creating Sealed Secret slurmdb-secret
      Generating type static...
      Generating type static...
      Generating type randstr...
      Generating type randstr...
    Creating Sealed Secret keycloak-users-localize
      Generating type static...
    ```

4.  Optionally add, commit, and push your git changes to an upstream repo. If
    production system or operational security is a concern, store your sealed
    secret key-pair outside of git/in a secure offline system.

    **Note:** The key pair will be required to migrate future upstream changes
    to your existing system repository or to run product stream installers.
