# CSM Cosign Keys

CSM [cosign] keys are stored in GCP KMS under the `sdlc-ops` project. Keys are stored in keyrings based on their utility:

- `projects/sdlc-ops/locations/global/keyRings/csm-builds` -- [Build keys](#build-keys) are used by build processes to sign container images
- `projects/sdlc-ops/locations/global/keyRings/csm-releases` -- [Release keys](#release-keys) used to sign container imaages specific to a CSM release

## Build Keys

Use [gcloud] to view and manage keys:

```bash
$ gcloud kms keys list --location=global --keyring=csm-builds
NAME                                                                               PURPOSE          ALGORITHM            PROTECTION_LEVEL  LABELS  PRIMARY_ID  PRIMARY_STATE
projects/sdlc-ops/locations/global/keyRings/csm-builds/cryptoKeys/github-cray-hpe  ASYMMETRIC_SIGN  EC_SIGN_P256_SHA256  HSM
projects/sdlc-ops/locations/global/keyRings/csm-builds/cryptoKeys/jenkins-csm      ASYMMETRIC_SIGN  EC_SIGN_P256_SHA256  HSM
```

### github-cray-hpe

Cosign URL: `gcpkms://projects/sdlc-ops/locations/global/keyRings/csm-builds/cryptoKeys/github-cray-hpe/versions/1`

Public key (version 1):
```bash
$ gcloud kms keys versions get-public-key --location=global --keyring=csm-builds --key=github-cray-hpe 1
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAERxLYOVq/kBeE05mUZqTk85CaOpSC
CdYeLlCt+K941eQgNWQLBdMiDPnicw5i9o278apo/OLD5AZVSX8ZXPYkKQ==
-----END PUBLIC KEY-----
```

### jenkins-csm

Cosign URL: `gcpkms://projects/sdlc-ops/locations/global/keyRings/csm-builds/cryptoKeys/jenkins-csm/versions/1`

Public key (version 1):
```bash
$ gcloud kms keys versions get-public-key --location=global --keyring=csm-builds --key=jenkins-csm 1
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEhEQ9X1j2d7qDHEXJRbYnAcYMhGop
OBhknIvSWQYhOpiH74CtJX4/KKPOQJxmb+ZHdZjC9GQZzxyayp2EvLF2Og==
-----END PUBLIC KEY-----
```

## Release Keys

Use [gcloud] to view and manage keys:

```bash
$ gcloud kms keys list --location=global --keyring=csm-releases
Listed 0 items.
```


[cosign]: https://github.com/sigstore/cosign
[gcloud]: https://cloud.google.com/sdk/gcloud
