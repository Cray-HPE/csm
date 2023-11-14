# Overview

A Sealed Secret is a Kubernetes CRD Kind that is managed by the [Sealed Secrets Operator](https://github.com/bitnami-labs/sealed-secrets).

Sealed Secrets were desgined to protect secrets inside Git repositories, by way of an asymmetric key-pair. Access to the key-pair (notably the private key) yields the ability to decrypt sealed secret content.

For Shasta, the Sealed Secret inventory is managed in `customizations.yaml`. Sealed Secrets are canonically introduced by way of 'generators' supplied via this repository and described below. 

During a Shasta installation or upgrade event, Sealed Secrets are created (as stored in `customizations.yaml`) in Kuberetes. The Sealed Secret Operator is then repsonsible for decrypting a Sealed Secret into a Kuberbetes Secret -- so that it can be used workloads in Kuberetes. Sealed secrets are encrypted with the public key (included in certificate form) in `certs`, and the operator decrypts them using the private key (as deployed to Kubernetes as a secret at deploy time). 

# Introducing Sealed Secrets into Customizations

To create a new Sealed Secret, add an appropriate generator block into `customizations.yaml`, like so:

```
spec:
  kubernetes:
    sealed_secrets:
      example:
        generate:
          name: "example"
          data:
            - name: bar
              length: 16
            - name: baz
              length: 12
            - name: username
              value: admin
```

Then execute `utils/secrets-seed-customizations.sh`.

# Using Sealed Secrets in Helm Charts

Introducing a Sealed Secret only adds it to the available inventory, it does not inject it into a Helm Deployment (Chart) for use. 

There are (at least) two methods to 'inject' a Sealed Secret:

1. Through use of the `cray-service` 'base' Helm Chart ("easy way")
2. By introducing a specialized Helm Template into your chart ("harder way/path for out-of-stream integration")

If you opt to use the base chart, an example pre-generated `customizations.yaml` form, including chart value injection, would look like:

```
spec:
  kubernetes:
    sealed_secrets:
      example:
        generate:
          name: simple_credentials
          data:
          - type: randstr
            args:
              name: password
              length: 32
          - type: static
            args:
              name: username
              value: user1
    services:
      my-service:
        cray-service:
           mountSealedSecrets: true
           sealedSecrets:
            - "{{ kubernetes.sealed_secrets.example | toYaml }}"
```

If you optioned to use your own templating method, your Helm Template would look something like:

```
{{- if .Values.sealedSecrets -}}
{{- range $val := .Values.sealedSecrets }}
{{- if $val.kind }}
{{- if eq $val.kind "SealedSecret" }}
---
{{ toYaml $val }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
```

And your pre-generated `customizations.yaml` form, including chart value injection, would look like:

```
spec:
  kubernetes:
    sealed_secrets:
      example:
        generate:
          name: simple_credentials
          data:
          - type: randstr
            args:
              name: password
              length: 32
          - type: static
            args:
              name: username
              value: user1
    services:
      my-service:
        sealedSecrets:
        - "{{ kubernetes.sealed_secrets.example | toYaml }}"
```

> The name of the secret and its namespace is used in the encryption process. The cluster-wide annotation allows the above secret to be used in any namespace, if it is omitted, the secret has to be used in the same namespace with the same name. Needless to say, the information on how the SealedSecret was created is important and can't be inferred.

# Available Sealed Secret Generators

The following Sealed Secret Generators are available:

1. Pseudo-random String (randstr)
2. Static String (static)
3. RSA Keypair Generation (rsa)
4. Dynamic Platform Certificate Authority (CA) Creation (plaform_ca)
5. Platform Certificate Authority (CA) Import (static_platform_ca)
6. ZeroMQ Curve Key Pair (zmq_curve)

The source for generators can be found in `utils/generators`.

## Random String

This uses `openssl rand -hex` to generate a random string of given length if
the encoding is `hex` or `openssl rand -base64` if the encoding is `base64`.
If `url_safe` is true "*" and "/" characters in the base-64 encoded value are
translated to "-" and "_".

Usage:

```yaml
    - type: randstr
      args:
        name: {field name} # Required
        length: {length of string in int} # Optional, defaults to 32
        encoding: {hex or base64} # Optional, defaults to hex
        url_safe: {no or yes} # Optional, defaults to no
```

Returns:

```yaml
    data:
        {field name}: {randomly generated string}
```

## Static String

This is a pass through, which is commonly required for usernames or such
in third party secrets.

Usage:

```yaml
    - type: static
      args:
        name: {field name} # Required
        value: {value to use} # Required
```

Returns:

```yaml
    stringData:
        {field name}: {value}
```

## Base64 Static String

Similar to static, but allows binary transport through support of a base64 encoded input value.

Usage:

```yaml
    - type: static_b64
      args:
        name: {field name} # Required
        value: {base64 encoded value to use} # Required
```

Returns:

```yaml
    stringData:
        {field name}: {value}
```

## RSA Private/Public Key Pair

This generates an RSA public/private key pair

Usage:

```yaml
    - type: rsa
      args:
        pub_name: {field name for public key} # Required
        key_name: {field name for private key} # Required
```

Returns:

```yaml
    data:
        {pub_name}: {base64 encoded public key}
        {key_name}: {base64 encoded private key}
```

## Platform Generated Root and Intermediate CA

This generates a Root CA, and an Intermediate signed by the Root

Usage:

```yaml
  - type: platform_ca
    args:
      root_days: {number of days Root CA certificate should be valid} # Required
      int_days: {number of days Intermediate CA certificate should be valid} # Required
      root_cn: {Common name for Root CA}
      int_cn: {Common name for Intermediate CA}
```

Returns:

```yaml
    data:
      root_ca.key: {base64 encoded Root CA key (PEM)}
      int_ca.key: {base64 encoded Intermediate CA key (PEM)}
      root_ca.crt: {base64 encoded Root CA certificate (PEM)}
      int_ca.crt: {base64 encoded Intermediate CA certificate (PEM)}
      ca_bundle.crt: {base64 encoded Root + Intermediate CA certificate bundle (PEM)}
```

## Injected Platform Intermediate CA

This allows static assignment of an Intermediate CA generated elsewhere

The generator should reject an attempt to inject a root CA. 

Usage:

```yaml
  - type: static_platform_ca
    args:
      key: {PEM formatted Intermediate CA private key}
      cert: {PEM formatted Intermediate CA certificate}
      ca_bundle: {PEM formatted CA, full trust chain}
```

Returns:

```yaml
    data:
      int_ca.key: {base64 encoded Intermediate CA key (PEM)}
      int_ca.crt: {base64 encoded Intermediate CA certificate (PEM)}
      ca_bundle.crt: {base64 encoded Root + Intermediate CA certificate bundle (PEM)}
```

## ZeroMQ Curve Key Pair

This generates an CurveZMQ public/private key pair

```yaml
Usage:

    - type: zmq_curve
      args:
        pub_name: {field name for public cert} # Required
        key_name: {field name for private key} # Required
```

Returns:

```yaml
    stringData:
        {pub_name}: {public key}
        {key_name}: {secret key}
```

## Example Generator Input

```yaml
      test:
        generate:
          name: testing-credentials
          data:
            - type: randstr
              args:
                name: test_password
                length: 32
            - type: static
              args:
                name: test_username
                value: test
            - type: static_b64
              args:
                name: encoded_message
                value: SGVsbG8gd29ybGQK # Hello world b64
            - type: rsa
              args:
                pub_name: test_cert.cr
                key_name: test_cert.key
            - type: platform_ca
              args:
                root_days: 3651
                int_days: 3650
                root_cn: "Shasta Platform Generated Root CA"
                int_cn: "Shasta Platform Generated Intemediate CA"
            - type: static_platform_ca
              args:
                key: |-
                  -----BEGIN PRIVATE KEY-----
                  <REDACTIED>
                  -----END PRIVATE KEY-----
                cert: |-
                  -----BEGIN CERTIFICATE-----
                  <REDACTIED>
                  -----END CERTIFICATE-----
                ca_bundle: |-
                  -----BEGIN CERTIFICATE-----
                  <REDACTIED>
                  -----END CERTIFICATE-----
            - type: zmq_curve
              args:
                pub_name: client_key.pub
                key_name: client_key
```

# Developing Generators

Creating a new generator is simple. Create an executable file in this directory
(utils/generators). This file will be executed each time a secret field of its
type (the exact name of the file) is used.

### Arguments

You script will receive four arguments:

1. A JSON string of the data in the `args` section of the customizations.yaml
2. The path to yq to be used for yaml/json manipulation
3. The path to a temporary sandbox to use if needed. Please create all files
   in this sandbox, as we will properly delete for you to ensure sensitive
   data does not get left on disk.
4. The path to the output file you MUST write your return YAML to

### Return

Your script MUST do the following:

1. Write valid yaml the provided output file that can be parsed with `yq r`
2. Throw errors when they occur (`set -e`)
3. Return the top level field(s) of `data`
    a. `data` is used for fields that you MUST have already base64 encoded
4. Return one or more field/value pairs under the top level fields

For example, return the following in your output file:

```yaml
    data:
        test_password: MDU0Y2QyODNmNGMwMmNmMGQwMjljNDk3MzZhZjFjYWU1ZGM5YTJhMmIxY2FjMGUwYWU4OWYyMDY2NWM0ZTQ0Ywo=
        test_secret: MTViMGZjN2FmMGQ0Njg2OTIxZDNlMzE5ZDI4Yjg2NTdmZjgzZmUxYzZmNWM5M2M4MDg4ZmZiYzUyY2FiMWFhZQo=
```
