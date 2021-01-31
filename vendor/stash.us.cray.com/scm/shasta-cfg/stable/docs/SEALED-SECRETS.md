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

This uses `openssl rand -hex` to generate a random string of given length

Usage:

```yaml
    - type: randstr
      args:
        name: {field name} # Required
        length: {length of string in int} # Required
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
                  MIIG/gIBADANBgkqhkiG9w0BAQEFAASCBugwggbkAgEAAoIBgQDvhzXCUmGalTDo
                  uswnppXbM+E+OwU79xvaZBsiGEDPpERPZfizpSO3/6IWnYvCUCrb1V4rIhkSKGYq
                  LLVMhmEkfiEImDnx+ksbZau3/w23ogP4qj+BpbTRF707//IOfXgRSD1Q+mVQ7MVo
                  crOt8e/hR4DqZjbkWOrw9pdrfvV159o6x9RVpip33BkAtDzONYApY6ePhzS1BFmo
                  I9R0zMGNeVpy7I2m47YUwpyGAWjRoof0P2BFHX7vdEoJE/TWAlbbiqlM9OHmR85J
                  I/O0MwP63C2Eqn9HajbF1GPVw2IvGN6fE3THtmVDVwxD17cFsKxtVl8gMHljkw9V
                  I+U5piuIfDPvaCoUIC3hlv7jsQs9j52LyZZF3sOKP3xsGG4a5ThqK08EKEgrFovg
                  MYsQrt8aSx7o/7K6IzDOD9QVf7dmkFVxlbPGAjR6nlQ5aW7gFEOAr1CbbZFS+lKi
                  KGjHGraIv93MTqqToE7yRJ6Sv0yP7U9clCi6MNi89AWFfZDkLAsCAwEAAQKCAYAW
                  R61odeE+T8JM45M53PTzfs/kyfiiq0mb9tPPSBI/Pjhcak/H5gR8iPq6v8zQNkTG
                  TgKEYJeUaM2X/rCefaFrk4/fDMnXCEEUO1DNvJu6CQf1iWB+3rsC+AJSImyRjHou
                  oVmSvrfN3zg9ju3HsElv2wbSxs80TlEMOOO8zAJpBTf3X78QeHRa0c5BkoJVbASP
                  1QUxBJKSg+UTDsIkWydl0XPoXLiQXX4CUFfe3yKw3T1oKrz5sNSt0VNRpNmRToY3
                  s96Teuv2iBUnN4UciuFajgjlP0Wt2YvntWoYcwJ7mOjwo6Ru5IXdPMeLBx/xKeLF
                  j2SnPiozSAg2OV8G+yffOIcV7598s2Jh9LpgEX0S2NWPdSrjp33IWM9clivzQXaV
                  fFZtFcb3dkrXTt2jVuj6hQR5dsVMC/D/sfORPuAudejmUkAYmozTI9vgcOJpWw3h
                  AT8KBZ6xR3ifr3/GwJk9eosFMeLCTnUprhgbMzM9sde31NOzgYPhiPrN4GJRp4EC
                  gcEA+e3m7HNrSY766GOaiYwiVdzLftL7i6Ie0QTHqJLLESu2/XyxuoML6IRXc+Df
                  A/HVtuwJMqxEe3APvOcwS/Qs6qnPhh0WNz9vJ+3D/uo7Om3cbIR8J6QlsQID9Kas
                  /OAOqxcbtedkkiDSzVM1SPzNh+R85FBDK2xBM433Eu9xET0V8YZegT99SWg72l8+
                  M37/EhGvtyQpYpY8lYs8pI3Xj7IRLt+jkPKu59uDdATMvVntOMheddpTwYW7XdUI
                  M67VAoHBAPVYodD9Hoe5AcUBrahM7trGzAw3z8fom5lf/wmzJ6Mow8lgH6tliwCs
                  4NS5PR45olONhK7o7vd/PXvzP1QSIHLNbInveCH29O0ZmBasDlF/eDT+Hcdzq0sw
                  YWUR+9mX5kNS3DuZaWy6f2PDQC+mzPn1yxGmwL2yW0sY6ExfKjmFVSjqG7Mt/oMo
                  BriKaANd3ctge3aRm2MHniXOPq+jC2Zq1rRopWgWIWDzchQsyl4e6iHs5s80nQsE
                  R9nrC6CfXwKBwQDMlwLB7HmW7YRXV7HZhu1UfDnYx71CwKOZVuBaDlBM7gwN1VVn
                  6H6HCE7OfPYStJTN+MpOwNYOdd1sNZRDmM5sCjXnA0h8UWEcvnYC5ps1aVlXO9ym
                  VqjEDXJPg2F4X7GiPHhin9ikBlqJ2eN0q/1TkKbr/wf9M9Dr8vqedYOJKQgdfnE+
                  PErDHKBiUjUI0pzanb/Jm8CFA5b0k9ZAnhwndQy74jZzITYsdnVVM9il6EdYhC1P
                  LDoD4QVP+mOMa0ECgcEA0ZCKb4O1j0Kk000ysx47q53A7vLBRUVXmzOXGgbwZXpN
                  efXkNze9+q6wQKOVI/sgv3OTEQAgFkGWGAjXYA03sDftbQiiOYjC/r8s3LjMZiqW
                  V9VzREl11/yURIuO7vbDlV/yg+nvVhMa+vDtI4a7cQrVENe5rI7rUgMNcSacX5OX
                  ASKu1GcGDaujyf9XBwEnkS9xZf7LllQMbshzXPzMoQfDK0hzeKvmiPSIzdjQZoLL
                  hHzhTb3oIl/eq7IMNX/LAoHAYuVeWbSXROyXITXrYcYMwgtYjjUWThQmrLQImJjj
                  HDUNMqq8w8OaQsV+JpZ0lwukeYst3d8vH8Eb4UczUaR+oJpBeEmXjXCGYG4Ec1EQ
                  H72VrrZoJowoqORDSp88h+akcF6+vPJPuNC/Ea7+eAeiYqgxOX5nc2uLjZxBt4OC
                  AhKMY5mnBN2pfAkGVpuyUw3dqGctTSCT0jnxvFPXpldgdAmXi2NTPqPd0IzmLKNG
                  jja1TCeqn9XRTy+EArf1bYi+
                  -----END PRIVATE KEY-----
                cert: |-
                  -----BEGIN CERTIFICATE-----
                  MIIEZTCCAs2gAwIBAgIJAKnqv1FyMOp/MA0GCSqGSIb3DQEBCwUAMFsxDzANBgNV
                  BAoMBlNoYXN0YTERMA8GA1UECwwIUGxhdGZvcm0xGjAYBgNVBAMMEVJvb3QgR2Vu
                  ZXJhdGVkIENBMRkwFwYDVQQDDBBQbGF0Zm9ybSBSb290IENBMB4XDTIwMDcwMTIz
                  MjU1MVoXDTIwMDcxMTIzMjU1MVowJDEPMA0GA1UECgwGU2hhc3RhMREwDwYDVQQL
                  DAhQbGF0Zm9ybTCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAO+HNcJS
                  YZqVMOi6zCemldsz4T47BTv3G9pkGyIYQM+kRE9l+LOlI7f/ohadi8JQKtvVXisi
                  GRIoZiostUyGYSR+IQiYOfH6Sxtlq7f/DbeiA/iqP4GltNEXvTv/8g59eBFIPVD6
                  ZVDsxWhys63x7+FHgOpmNuRY6vD2l2t+9XXn2jrH1FWmKnfcGQC0PM41gCljp4+H
                  NLUEWagj1HTMwY15WnLsjabjthTCnIYBaNGih/Q/YEUdfu90SgkT9NYCVtuKqUz0
                  4eZHzkkj87QzA/rcLYSqf0dqNsXUY9XDYi8Y3p8TdMe2ZUNXDEPXtwWwrG1WXyAw
                  eWOTD1Uj5TmmK4h8M+9oKhQgLeGW/uOxCz2PnYvJlkXew4o/fGwYbhrlOGorTwQo
                  SCsWi+AxixCu3xpLHuj/srojMM4P1BV/t2aQVXGVs8YCNHqeVDlpbuAUQ4CvUJtt
                  kVL6UqIoaMcatoi/3cxOqpOgTvJEnpK/TI/tT1yUKLow2Lz0BYV9kOQsCwIDAQAB
                  o2MwYTAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBBjAdBgNVHQ4EFgQU
                  uNa6qcbJsHdxo6k8kaR5o53DNbIwHwYDVR0jBBgwFoAU/SFNwDBMcAYWBC2SCsDf
                  OyZJbEMwDQYJKoZIhvcNAQELBQADggGBAD8O1Vg9WLFem0RZiZWjtXiNOTZmaksE
                  +a49CE7yGqyETljlVOvbkTUTr4eJnzq2prYJUF8QavSBs38OahcxkTU2GOawZa09
                  hFc1aBiGSPAxTxJqdHV+G3QZcce1CG2e9VyrxqNudosNRNBEPMOsgg4LpvlRqMfm
                  QhPEJcfvVaCopDZBFXLBPxqmt9BckWFmTSsK09xnrCE/40YD69hdUQ6USJaz9/cd
                  UfNm0HIugRUMvFUP2ytdJmbV+1YQbfVsFrKU4aClrMg+ECX83od5N1TUNQwMePLh
                  IizLGoGDF353eRVKxlzyI724Ni9W82rMW66TQdA7vU6liItHYrhDmcZ+mK2R0F5B
                  ZuYjsLf/BCQ1uDv/bsVG40ogjH/eI/qfhRIzbgVVTF74uKG97pOakp2iQaG9USFd
                  9/s6ouQQXfkDZ2a/vzs8SBD4eIx7vmeABPRqlHTE8VzohxugxMbJNMdZRPGrEeH6
                  uddqVNpMH9ehQtsDdt0nmfVIy9/An3BKFw==
                  -----END CERTIFICATE-----
                ca_bundle: |-
                  -----BEGIN CERTIFICATE-----
                  MIIEezCCAuOgAwIBAgIJAMjuQjQKUpUtMA0GCSqGSIb3DQEBCwUAMFsxDzANBgNV
                  BAoMBlNoYXN0YTERMA8GA1UECwwIUGxhdGZvcm0xGjAYBgNVBAMMEVJvb3QgR2Vu
                  ZXJhdGVkIENBMRkwFwYDVQQDDBBQbGF0Zm9ybSBSb290IENBMB4XDTIwMDcwMTIz
                  MjU1MVoXDTIwMDcxMTIzMjU1MVowWzEPMA0GA1UECgwGU2hhc3RhMREwDwYDVQQL
                  DAhQbGF0Zm9ybTEaMBgGA1UEAwwRUm9vdCBHZW5lcmF0ZWQgQ0ExGTAXBgNVBAMM
                  EFBsYXRmb3JtIFJvb3QgQ0EwggGiMA0GCSqGSIb3DQEBAQUAA4IBjwAwggGKAoIB
                  gQDQ0DTdZmqCOfrWb8KTXJ0hT1r2G51rRE5eAp8d/PoVCgV1gg5h1+jbiv3yYd2R
                  BgM/CPZPvEJaL03wR1gO9NiGEXh1ALd8+yv1O1VRKNb6JuB5cPZFHE3Z8El6aGMc
                  zrqN1ZekRPrZMM1W5Iw78olOMZvsxYw0ZIJqfKOWYB9jYUNM1KohHVj65f/HD/Em
                  kC+9VFhepRV9z21q6fBU13bMz6/NlW19omvbTMwrVSPbYi2nSzqOfi00GXmVh/9Q
                  WElBrAeiGLOsjWkeQ8sFF8ab4SSvzLAAilyQqkBhz2jIxB4L7iG+b9KEgVLeOoMH
                  1Rs7RhduOMEQypZGVA/vsu/86/5ctM1Cu60mZP+s5B7oT2rwypz0ihLiVCaDCcS5
                  lDK7PPT5GxZPD8TAqX0SgtaxJnSB/RzavGPSS7efFvlWXh18frwlwa+FgOnyCw1/
                  qR3BHarcZX9XZivBQSupxQAaUNPMlk0N4wYi6oWrmf21zwd7NtZAinxC2F98J1sn
                  sK8CAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAQYwHQYD
                  VR0OBBYEFP0hTcAwTHAGFgQtkgrA3zsmSWxDMA0GCSqGSIb3DQEBCwUAA4IBgQAp
                  ApgLdQBK6fZ7CWlEWwXSKxcjv3akuSqf1NXfn/J9e1rAqqyYoTDE9DXG9dYHL9OA
                  p78KLsLy9fQmrLMmjacXw49bpXDG6XN1WLJfhgQg3j7lXvOvXyxynOgKDtBlroiU
                  nMoK+or9lF2lBIuY34GPyZCL/+vB8s1tu0dGBDgHMUL8/k5d27sdGZZUljC7CgcC
                  k+ABrv19IygDpZpZ6m5N27xajnKpJSjXOfpMCPdhCuNRMgMTX6x8bxZzVAx9ogQ8
                  16ZzAziB4iMXeCggaY/+YnoEstzTDPXB8FuqeGEVt63Y9ZA7NgWYvVExtKFGGhOL
                  lnEhCLjQyu6/LgOJNfNM9EofaE/IU+i0talgFA+ygSChmYdXzFJn4EfAY9XbwEwV
                  Pw+NHbkpv82jIpc+mopuMRdDO5OyFb+IGkn7ITUFE9N+u97oz2PjD5nQ/Z5DGjBu
                  y3sefnrlqaRanHYkmOnOBTwImPSq8RE8eJP2aRrnu+2YrnoACXxS+XWUXtNhXJ4=
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
