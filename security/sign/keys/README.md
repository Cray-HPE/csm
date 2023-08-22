# CSM Cosign Keys

CSM [cosign] keys are stored in GCP KMS under the `hpe-prod-csm-security` project. Staging environment in `hpe-prod-csm-security` project is also available.

## Build Keys

Use [gcloud] to view and manage keys:

```bash
$ gcloud --project=hpe-prod-csm-security kms keys list --location=global --keyring=cosign
NAME                                                                                   PURPOSE          ALGORITHM                   PROTECTION_LEVEL  LABELS  PRIMARY_ID  PRIMARY_STATE
projects/hpe-prod-csm-security/locations/global/keyRings/cosign/cryptoKeys/csm-images  ASYMMETRIC_SIGN  RSA_SIGN_PKCS1_4096_SHA256  HSM
```

### csm-images

Cosign URL: `gcpkms://projects/hpe-stage-csm-security/locations/global/keyRings/cosign/cryptoKeys/csm-images/versions/1`

Public key (version 1):
```bash
$ gcloud --project=hpe-prod-csm-security kms keys versions get-public-key --location=global --keyring=cosign --key=csm-images 1
-----BEGIN PUBLIC KEY-----
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEApmSs9Qa6o3E8sYAlM64n
1cL0RG6Jdc6pG78B1P3s67xZTO76vxYuA0wfS8cvzPsUFHi5YcJEEBkFcDAUAEuk
3IW7vp054H9mcMKUUcDtdcBCvuwuQHkOJQNNay+FGuNLHUaZDyuEdVxHeKnpT04C
UDmJrp70xOJwMAhhiYKHItm+cK3FlHF77okLus4f/h+PW4d9rf0u9/tNAdMYINfe
D8m5qdPyE4P0hjnaEOV9sxvW3NmC0nY2DaY092BFqYN0mQ8hnHNaFj6dUJpLPOxc
nGmTiz0eJU8ZMNoYblRGUrgQoS/PkJKCBa/MZb/RYqmlfYOhLWPGgntUTBD38ydk
NavrPcGZscv3LfJZq/qag/osNMGgSrkoLsFaYYc8ruHVgs0zmSpNSezih6myPfJS
xDOBbTahWJt1giIgtFzP4zxys05srBE9p/OhlmC63PhEUdoueVzGf4LpEc/k8yMk
/VHhJMZ7VRzDreZF5GfiQJSbJ8Cta9JQEOAC9jvwOcV4p34/xyuGF08dysXdx3dU
7Kn3VGKApMeMSB3NChillFz/lG8f02fGeB3lBxHtbv+k2L59HAlERNMADfREolmu
cnR6uEeG/nWNlsmV2/8STOFUIYoNwTZyZ9BbKLZgzK27TuogXhXdI4EyOk0jfLbg
ZAIGzGlSCNBmrRl3muD6nW8CAwEAAQ==
-----END PUBLIC KEY-----
```

[cosign]: https://github.com/sigstore/cosign
[gcloud]: https://cloud.google.com/sdk/gcloud
