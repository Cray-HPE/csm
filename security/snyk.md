# Snyk

## Scans

### Scan Source Repositories

TODO


### Scan Container Images

Using `snyk container test` to scan a container image is straight-forward. For
example, let's scan the `alpine` image:

```
$ snyk container test alpine

Testing alpine...

Organization:      shasta-csm-oss
Package manager:   apk
Project name:      docker-image|alpine
Docker image:      alpine
Platform:          linux/amd64
Base image:        alpine:3.15.0
Licenses:          enabled

✔ Tested 14 dependencies for known issues, no vulnerable paths found.

According to our scan, you are currently using the most secure version of the selected base image


```

However, things get more complicated when we want to efficiently scan all
container images in a CSM release using their canonical form with appropriate
registry mirrors and aggregate the results.

The following subsections attempt to explain how all the pieces fit together,
but the TL;DR for scanning all images in a CSM release is:

1.  Create and activate a virtual environment with the required security tools:

    ```
    $ make build/.env
    $ . build/.env/bin/activate
    ```

    Install [GNU Parallel]. Using Homebrew it's easy:

    ```
    $ brew install parallel
    ```

2.  Run `make images` to generate the complete list of images in
    build/images/index.txt:

    ```
    (.env)$ make images
    ```

4.  Use [GNU Parallel] to scan images from build/images/index.txt using
    `hack/snyk-scan.sh` and 75% of the cores available on the local machine:

    ```
    (.env)$ parallel -j 75% --halt-on-error now,fail=1 -v \
        -a build/images/index.txt --colsep '\t' \
        hack/snyk-scan.sh scan-results/docker '{2}' '{1}'
    ```

5.  Aggregate results using `hack/snyk-aggregate-results.sh` under
    scan-results/docker:

    ```
    (.env)$ hack/snyk-aggregate-results.sh scan-results/docker
    ```

6.  (Optional) Create HTML output using `hack/snyk-to-html.sh`:

    ```
    (.env)$ hack/snyk-to-html.sh
    ```


#### Canonical Form of Image References

Typically image references are of the form
`hostname[:port]/username/reponame[:tag]`. When using the Docker Hub Registry
(i.e., `docker.io`) the `hostname[:port]/` components may be omitted. In
addition, if the image is in the official Docker library, the `username/`
components may also be omitted. Lastly, if no tag (or digest) is specified, the
`latest` tag is assumed. So the canonical form of a simple image reference like
`alpine` is `docker.io/library/alpine:latest`.

#### CSM Registry Mirrors

CSM's Artifactory at artifactory.algol60.net has remote registries configured
for various registries (e.g., docker.io, quay.io, gcr.io) which behave as pull
through caches. Using them is important for several reasons:

- If the upstream registry limits pulls (e.g., docker.io), using the mirror
  will avoid getting throttled when pulling images from the upstream registry
  by virtue of the fact it implements a pull-through cache.
- The remote registries are configured to only permit specific images to be
  pulled, mainly to just avoid them being used as an arbitrary image cache.

#### Logical vs Physical Image References

By convention, we call any image ref used in a Helm chart or specified in
[docker/index.yaml](../docker/index.yaml) a _logical_ image reference. The
corresponding _physical_ image reference uses canonical form, is adjusted to an
appropriate registry mirrors, and pins the reference to a specific sha256
identifier. Use `build/images/inspect.sh` to get the corresponding _physical_
ref:

```
$ build/images/inspect.sh alpine
+ skopeo inspect docker://artifactory.algol60.net/docker.io/library/alpine
docker.io/library/alpine	artifactory.algol60.net/docker.io/library/alpine@sha256:21a3deaa0d32a8057914f36584b5288d2e5ecc984380bc0118285c70fa8c9300
```

#### Scan Physical Image References

To avoid potential race conditions and ensure that we scan the images
_actually_ shipped in a release, _physical_ image references must be scanned.
However, since the _logical_ refs are user-facing, the scan results need to be
adjusted. To facilitate result aggregation based on _logical_ image references,
use `hack/snyk-scan.sh` to scan a _physical_ ref and save the results to an
output directory based on its corresponding _logical_ ref:

```
$ hack/snyk-scan.sh
usage: snyk-scan.sh DIR PHYSICAL-IMAGE LOGICAL-IMAGE
```

> Note that `hack/snyk-scan.sh` takes the _physical_ image reference first,
> since that is the image actually being scanned; however, results are stored
> based on the _logical_ image reference.

Continuing the above example using `alpine`, the corresponding call to
`hack/snyk-scan.sh` using the output from `build/images/inspect.sh` is:

```
$ hack/snyk-scan.sh scan-results/docker \
    artifactory.algol60.net/docker.io/library/alpine@sha256:21a3deaa0d32a8057914f36584b5288d2e5ecc984380bc0118285c70fa8c9300 \
    docker.io/library/alpine
+ snyk container test artifactory.algol60.net/docker.io/library/alpine@sha256:21a3deaa0d32a8057914f36584b5288d2e5ecc984380bc0118285c70fa8c9300

Testing artifactory.algol60.net/docker.io/library/alpine@sha256:21a3deaa0d32a8057914f36584b5288d2e5ecc984380bc0118285c70fa8c9300...

Organization:      shasta-csm-oss
Package manager:   apk
Project name:      docker-image|artifactory.algol60.net/docker.io/library/alpine
Docker image:      artifactory.algol60.net/docker.io/library/alpine@sha256:21a3deaa0d32a8057914f36584b5288d2e5ecc984380bc0118285c70fa8c9300
Platform:          linux/amd64
Base image:        alpine:3.15.0
Licenses:          enabled

✔ Tested 14 dependencies for known issues, no vulnerable paths found.

According to our scan, you are currently using the most secure version of the selected base image


```

Inspect the specified output directory to find multiple Snyk results files:
snyk.json (JSON encoded results) and snyk.txt (text based results, also shown
when running `hack/snyk-scan.sh`).

```
$ tree scan-results/docker
scan-results/docker
└── docker.io
    └── library
        └── alpine
            ├── snyk.json
            └── snyk.txt

3 directories, 2 files
```

#### Images in a CSM Release

Starting in CSM 1.2, container images do not have to be explicitly listed in
[docker/index.yaml](../docker/index.yaml) if they are _extractable_ from a
chart. Unfortunately, this means charts must be processed in order to discover
all the images that must be included in a CSM release. Charts are deployed
using [Loftsman manifests](../manifests) and `build/images/extract.sh` can be
used to extract images from charts deployed by a specific manifest.

```
$ build/images/extract.sh
usage: extract.sh MANIFEST [CHART ...]
```

For example, to extract all images used by the `cray-powerdns-manager` chart in
the `core-services.yaml` manifest:

```
$ build/images/extract.sh manifests/core-services.yaml cray-powerdns-manager
+ manifests/core-services.yaml
HELM_BIN="helm"
HELM_CACHE_HOME="/Users/zcrisler/Library/Caches/helm"
HELM_CONFIG_HOME="/Users/zcrisler/Library/Preferences/helm"
HELM_DATA_HOME="/Users/zcrisler/Library/helm"
HELM_DEBUG="false"
HELM_KUBEAPISERVER=""
HELM_KUBEASGROUPS=""
HELM_KUBEASUSER=""
HELM_KUBECAFILE=""
HELM_KUBECONTEXT=""
HELM_KUBETOKEN=""
HELM_MAX_HISTORY="10"
HELM_NAMESPACE="default"
HELM_PLUGINS="/Users/zcrisler/Library/helm/plugins"
HELM_REGISTRY_CONFIG="/Users/zcrisler/Library/Preferences/helm/registry.json"
HELM_REPOSITORY_CACHE="/Users/zcrisler/Library/Caches/helm/repository"
HELM_REPOSITORY_CONFIG="/Users/zcrisler/Library/Preferences/helm/repositories.yaml"
+ helm repo add csm-algol60 https://artifactory.algol60.net/artifactory/csm-helm-charts/
"csm-algol60" has been added to your repositories
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "csm-algol60" chart repository
Update Complete. ⎈Happy Helming!⎈
+ csm-algol60/cray-powerdns-manager --version 0.5.2
     1	artifactory.algol60.net/csm-docker/stable/cray-powerdns-manager:0.5.2
artifactory.algol60.net/csm-docker/stable/cray-powerdns-manager:0.5.2
```

If no chart is specified, `build/images/extract.sh` will extract images from all charts in the manifest:

```
$ build/images/extract.sh manifests/core-services.yaml 
+ manifests/core-services.yaml
HELM_BIN="helm"
HELM_CACHE_HOME="/Users/zcrisler/Library/Caches/helm"
HELM_CONFIG_HOME="/Users/zcrisler/Library/Preferences/helm"
HELM_DATA_HOME="/Users/zcrisler/Library/helm"
HELM_DEBUG="false"
HELM_KUBEAPISERVER=""
HELM_KUBEASGROUPS=""
HELM_KUBEASUSER=""
HELM_KUBECAFILE=""
HELM_KUBECONTEXT=""
HELM_KUBETOKEN=""
HELM_MAX_HISTORY="10"
HELM_NAMESPACE="default"
HELM_PLUGINS="/Users/zcrisler/Library/helm/plugins"
HELM_REGISTRY_CONFIG="/Users/zcrisler/Library/Preferences/helm/registry.json"
HELM_REPOSITORY_CACHE="/Users/zcrisler/Library/Caches/helm/repository"
HELM_REPOSITORY_CONFIG="/Users/zcrisler/Library/Preferences/helm/repositories.yaml"
+ helm repo add csm-algol60 https://artifactory.algol60.net/artifactory/csm-helm-charts/
"csm-algol60" has been added to your repositories
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "csm-algol60" chart repository
Update Complete. ⎈Happy Helming!⎈
+ csm-algol60/cray-hms-sls --version 2.0.2
     1	artifactory.algol60.net/csm-docker/stable/cray-postgres-db-backup:0.2.0
     2	artifactory.algol60.net/csm-docker/stable/cray-sls:1.13.0
     3	artifactory.algol60.net/csm-docker/stable/docker-kubectl:1.19.15
     4	artifactory.algol60.net/csm-docker/stable/docker.io/library/postgres:13.2-alpine
+ csm-algol60/cray-hms-smd --version 2.0.3
     1	artifactory.algol60.net/csm-docker/stable/cray-postgres-db-backup:0.2.0
     2	artifactory.algol60.net/csm-docker/stable/cray-smd:1.38.0
     3	artifactory.algol60.net/csm-docker/stable/docker-kubectl:1.19.15
     4	artifactory.algol60.net/csm-docker/stable/docker.io/library/postgres:13.2-alpine
+ csm-algol60/cray-hms-meds --version 2.0.0
     1	artifactory.algol60.net/csm-docker/stable/cray-meds:1.17.0
     2	artifactory.algol60.net/csm-docker/stable/docker-kubectl:1.19.15
     3	artifactory.algol60.net/csm-docker/stable/docker.io/curlimages/curl:7.73.0
+ csm-algol60/cray-hms-reds --version 2.0.0
     1	artifactory.algol60.net/csm-docker/stable/cray-reds:1.21.0
     2	artifactory.algol60.net/csm-docker/stable/docker-kubectl:1.19.15
     3	artifactory.algol60.net/csm-docker/stable/quay.io/coreos/etcd:v3.3.22
+ csm-algol60/cray-hms-discovery --version 2.0.1
     1	artifactory.algol60.net/csm-docker/stable/hms-discovery:1.10.0
+ csm-algol60/cray-dhcp-kea --version 0.10.0
     1	artifactory.algol60.net/csm-docker/stable/cray-dhcp-kea:0.10.0
+ csm-algol60/cray-dns-unbound --version 0.7.1
     1	artifactory.algol60.net/csm-docker/stable/cray-dns-unbound:0.7.1
+ csm-algol60/cray-dns-powerdns --version 0.2.2
     1	artifactory.algol60.net/csm-docker/stable/cray-dns-powerdns:0.2.2
     2	artifactory.algol60.net/csm-docker/stable/docker-kubectl:1.19.15
     3	artifactory.algol60.net/csm-docker/stable/docker.io/library/postgres:13.2-alpine
+ csm-algol60/cray-powerdns-manager --version 0.5.2
     1	artifactory.algol60.net/csm-docker/stable/cray-powerdns-manager:0.5.2
artifactory.algol60.net/csm-docker/stable/cray-dhcp-kea:0.10.0
artifactory.algol60.net/csm-docker/stable/cray-dns-powerdns:0.2.2
artifactory.algol60.net/csm-docker/stable/cray-dns-unbound:0.7.1
artifactory.algol60.net/csm-docker/stable/cray-meds:1.17.0
artifactory.algol60.net/csm-docker/stable/cray-postgres-db-backup:0.2.0
artifactory.algol60.net/csm-docker/stable/cray-powerdns-manager:0.5.2
artifactory.algol60.net/csm-docker/stable/cray-reds:1.21.0
artifactory.algol60.net/csm-docker/stable/cray-sls:1.13.0
artifactory.algol60.net/csm-docker/stable/cray-smd:1.38.0
artifactory.algol60.net/csm-docker/stable/docker-kubectl:1.19.15
artifactory.algol60.net/csm-docker/stable/docker.io/curlimages/curl:7.73.0
artifactory.algol60.net/csm-docker/stable/docker.io/library/postgres:13.2-alpine
artifactory.algol60.net/csm-docker/stable/hms-discovery:1.10.0
artifactory.algol60.net/csm-docker/stable/quay.io/coreos/etcd:v3.3.22
```

> **Caution:** Take note of the Helm configuration printed at the start of
> `build/images/extract.sh`. The top-level [Makefile](../Makefile) sets
> `HELM_CACHE_HOME` and `HELM_CONFIG_HOME` environment variables to directories
> under build/.helm to avoid polluting the default system cache and config when
> running `make images` (which is discussed below). The
> build/.helm/cache/repository directory is used by `release.sh` to package
> Helm charts into a CSM release.
>
> If you do not want to pollute your local Helm client's settings when running
> `build/images/extract.sh`, simply set and export `HELM_CACHE_HOME` and/or
> `HELM_CONFIG_HOME` as appropriate. See https://helm.sh/docs/helm/helm/ for
> more information about configuring Helm.


#### build/images/index.txt

The process of extracting and resolving references for all images required by a
CSM release is scripted using GNU Make to generate build/images/index.txt,
which maps _logical_ image references to _physical_ refs. As discussed above,
the recommended way of building build/images/index.txt is to run `make images`
from the top-level directory. It sets up environment variables so that Helm
configuration and cached data are under build/.helm then calls sub-make against
[build/images/Makefile].



#### build/images/chartmap.csv


The process of extracting and resolving references for all images required by Helm Charts
is scripted using GNU Make to generate build/images/chartmap.csv,
which maps Loftsman Manifests to a Helm Chart, to a _logical_ image reference. 
As discussed above, the recommended way of building build/images/chartmap.csv is to run `make images`
from the top-level directory. It sets up environment variables so that Helm
configuration and cached data are under build/.helm then calls sub-make against
[build/images/Makefile].


### Scan Helm Charts

Snyk can find security issues in Infrastructure-As-Code files such as
Kubernetes manifests (i.e., YAML-encoded specifications of Kubernetes
resources) using `snyk iac`. Use `helm template` to render the Kubernetes
resources managed by the chart. For example, from the chart's source directory:

```
$ helm template . --generate-name --dry-run
```

Be aware of these caveats when rendering a chart:

- Charts can support a number of options that may significantly impact the
  generated resources. Be sure to test with recommended defaults and options.
- Manifest files support value overrides for specific chart releases. Consult
  the [CSM manifests](../manifests) to see which settings ship by default.
- Value overrides for specific chart releases may also be specified in
  [customizations.yaml](../vendor/stash.us.cray.com/scm/shasta-cfg/stable/customizations.yaml).
- Loftsman always sets `global.chart.name` and `global.chart.version` values
  when _shipping_ a chart release since they are used by the `cray-service`
  base chart. As a result, they may have to be manually set.

Charts do not have to be rendered from a source working tree. They may also be
rendered directly from a chart repository. In this scenario be sure to either
add the repository to your Helm client via `helm repo add` and specify the chart as
`<repo>/<chart>` or use the `--repo` option to specify the repository URL. For
example, [extract.sh](../build/images/extract.sh#L38) uses `helm template` to
render charts and extract container images for packaging and scanning as
follows:

```
$ helm repo add $REPO $URL
$ helm template $REPO/$CHART --version $VERSION --generate-name --dry-run
```

The cray-powerdns-manager example in the below section uses `--repo`:

```
$ helm template $CHART --version $VERSION --repo $REPO --generate-name --dry-run
```

> When templating charts in a script, consider using a retry mechanism to
> account for intermittent network connectivity issues. [GNU Parallel] provides
> useful retry capabilities (e.g.`parallel --nonall --retries 5 helm template
> ...`) and is recommended.

To scan a chart for issues, save the output of `helm template` to a file, e.g.
k8s-manifest.yaml, and then run `snyk iac test`. For example:

> Note that standard options like `--json`/`--json-file-output`,
> `--severity-threshold`, and `--policy-file` are also supported.

```
$ snyk iac test k8s-manifest.yaml
```

The results will be relative to the scanned file and will require additional
analysis in order to trace resolution back to the appropriate chart template or
value.


#### Example: cray-powerdns-manager version 0.5.2

The cray-powerdns-manager chart is deployed as part of the [core-services.yaml manifest](../manifests/core-services.yaml#L65-L68):

```yaml
apiVersion: manifests/v1beta1
metadata:
  name: core-services
spec:
  sources:
    charts:
    - name: csm-algol60
      type: repo
      location: https://artifactory.algol60.net/artifactory/csm-helm-charts/
  charts:
...
  - name: cray-powerdns-manager
    source: csm-algol60
    version: 0.5.2
    namespace: services
```

Let's attempt to render the `cray-powerdns-manager` chart based on this
configuration:

```
$ helm template cray-powerdns-manager --version 0.5.2 \
  --repo https://artifactory.algol60.net/artifactory/csm-helm-charts/ \
  --set global.chart.name=cray-powerdns-manager \
  --set global.chart.version=0.5.2 \
  --set manager.base_domain=shasta.dev.cray.com
Error: execution error at (cray-powerdns-manager/templates/configmap.yaml:8:18): manager.base_domain is not set in customizations.yaml

Use --debug flag to render out invalid YAML
```

The error indicates that the required value `manager.base_domain` is not set,
and is expected to be provided in customizations.yaml as opposed to the
manifest. (In this case, no default value for `manager.base_domain` is provided
in values.yaml in order to ensure that it is explicitly overridden for each
system. This is uncommon but serves to highlight the importance of ensuring
default values and options are set when rendering charts for scanning
purposes.) Since we are not particularly concerned about the value of
`manager.base_domain`, let's try again and set it to an arbitrary string, e.g.
`shasta.dev.cray.com`:

```
$ helm template cray-powerdns-manager --version 0.5.2 \
  --repo https://artifactory.algol60.net/artifactory/csm-helm-charts/ \
  --set global.chart.name=cray-powerdns-manager \
  --set global.chart.version=0.5.2 \
  --set manager.base_domain=shasta.dev.cray.com
---
# Source: cray-powerdns-manager/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cray-powerdns-manager-config
data:
  primary_server: ""
  secondary_servers: ""
  base_domain: shasta.dev.cray.com
  notify_zones: ""
---
# Source: cray-powerdns-manager/charts/cray-service/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: cray-powerdns-manager
  labels:
    app.kubernetes.io/name: cray-powerdns-manager
    helm.sh/base-chart: cray-service-7.0.1
    helm.sh/chart: cray-powerdns-manager-0.5.2
    app.kubernetes.io/instance: RELEASE-NAME
    app.kubernetes.io/managed-by: Helm
    
  annotations:
    cray.io/service: cray-powerdns-manager
    
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: http
      name: http
      protocol: TCP
  selector:
    app.kubernetes.io/name: cray-powerdns-manager
    app.kubernetes.io/instance: RELEASE-NAME
---
# Source: cray-powerdns-manager/charts/cray-service/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cray-powerdns-manager
  labels:
    app.kubernetes.io/name: cray-powerdns-manager
    helm.sh/base-chart: cray-service-7.0.1
    helm.sh/chart: cray-powerdns-manager-0.5.2
    app.kubernetes.io/instance: RELEASE-NAME
    app.kubernetes.io/managed-by: Helm
    
  annotations:
    cray.io/service: cray-powerdns-manager
    
spec:
  replicas: 1
  strategy:
    
    type: Recreate
    # Need an explicit rollingUpdate: null to upgrade from default RollingUpdate
    # strategy or K8S API Server will reject the merged deployment
    rollingUpdate: null
  selector:
    matchLabels:
      app.kubernetes.io/name: cray-powerdns-manager
      app.kubernetes.io/instance: RELEASE-NAME
  template:
    metadata:
      labels:
        app.kubernetes.io/name: cray-powerdns-manager
        app.kubernetes.io/instance: RELEASE-NAME
      annotations:
        service.cray.io/public: "true"
        
    spec:
      
      serviceAccountName: "jobs-watcher"
      priorityClassName: csm-high-priority-service
      containers:
      - name: cray-powerdns-manager
        image: artifactory.algol60.net/csm-docker/stable/cray-powerdns-manager:0.5.2
        imagePullPolicy: Always
        env:
          - name: BASE_DOMAIN
            valueFrom:
              configMapKeyRef:
                key: base_domain
                name: cray-powerdns-manager-config
          - name: PRIMARY_SERVER
            valueFrom:
              configMapKeyRef:
                key: primary_server
                name: cray-powerdns-manager-config
          - name: SECONDARY_SERVERS
            valueFrom:
              configMapKeyRef:
                key: secondary_servers
                name: cray-powerdns-manager-config
          - name: NOTIFY_ZONES
            valueFrom:
              configMapKeyRef:
                key: notify_zones
                name: cray-powerdns-manager-config
          - name: PDNS_URL
            value: http://cray-dns-powerdns-api:8081
          - name: PDNS_API_KEY
            valueFrom:
              secretKeyRef:
                key: pdns_api_key
                name: cray-powerdns-credentials
          - name: KEY_DIRECTORY
            value: /keys
        ports:
          - containerPort: 8080
            name: http
        livenessProbe:
          httpGet:
            path: /v1/liveness
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /v1/readiness
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 30
        volumeMounts:
          - mountPath: /keys
            name: dnssec-keys
            readOnly: true
        securityContext:
          runAsUser: 65534
          runAsGroup: 65534
          runAsNonRoot: true
      
      
      
      
      volumes:
---
# Source: cray-powerdns-manager/charts/cray-service/templates/ingress.yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: "cray-powerdns-manager"
  labels:
    app.kubernetes.io/name: cray-powerdns-manager
    helm.sh/base-chart: cray-service-7.0.1
    helm.sh/chart: cray-powerdns-manager-0.5.2
    app.kubernetes.io/instance: RELEASE-NAME
    app.kubernetes.io/managed-by: Helm
    
spec:
  hosts:
    - "*"
  gateways:
    - services-gateway
    - customer-admin-gateway
  http:
    - match:
        - uri:
            prefix: "/apis/powerdns-manager/"
      rewrite:
        uri: "/"
      route:
        - destination:
            host: "cray-powerdns-manager"
            port:
              number: 80
```

Those results look better, but if you carefully examine the output you'll
notice there still appears to be some things missing. This is because
cray-powerdns-manager requires additional configuration from
[customizations.yaml](vendor/stash.us.cray.com/scm/shasta-cfg/stable/customizations.yaml).
Let's examine the corresponding customizations:

```
apiVersion: customizations/v1
metadata:
  name: stable
spec:
  network:
...
    netstaticips:
      site_to_system_lookups: ~FIXME~
...
    dns:
      external: ~FIXME~ e.g., eniac.dev.cray.com
...
      primary_server_name: ~FIXME~ e.g., primary
      secondary_servers: ~FIXME~ e.g., externaldns1.my.domain/1.1.1.1,externaldns2.my.domain/2.2.2.2
      notify_zones: ~FIXME~ e.g., shasta.dev.cray.com,8.101.10.in-addr.arpa
...
  kubernetes:
...
    sealed_secrets:
...
      dnssec:
        generate:
          name: dnssec-keys
          data:
            - type: static_b64
              args:
                name: dummy
                value: ZHVtbXkK
...
    services:
...
      cray-powerdns-manager:
        manager:
          primary_server: "{{ network.dns.primary_server_name }}/{{ network.netstaticips.site_to_system_lookups }}"
          secondary_servers: "{{ network.dns.secondary_servers }}"
          base_domain: "{{ network.dns.external }}"
          notify_zones: "{{ network.dns.notify_zones }}"
        cray-service:
          sealedSecrets:
            - '{{ kubernetes.sealed_secrets.dnssec | toYaml }}'
...
```

As we can see, there are a number of additional values that are expected when
deploying the cray-powerdns-manager chart. Instead of specifying them
individually to `helm template` using the `--set` flag, let's assemble a test
values.yaml file which will be specified using `-f`.

First, notice that most of the values come from `network` settings which are
provided by cray-site-init (CSI) during initial system installation. Their
values are probably not that important to enable Snyk to successfully scan for
issues, so setting them to example values will be sufficient. In fact, the only
complex value appears to be the `dnssec` sealed secret. Using
vendor/stash.us.cray.com/scm/shasta-cfg/stable/utils/secrets-seed-customizations.sh
we can generate a SealedSecret resource corresponding to the `dummy` value:

```
$ cd vendor/stash.us.cray.com/scm/shasta-cfg/stable
$ utils/secrets-seed-customizations.sh customizations.yaml spec.kubernetes.sealed_secrets.dnssec.generate 
Creating Sealed Secret dnssec-keys
  Generating type static_b64...
```

Now read the generated `dnssec` SealedSecret from customizations.yaml:

```
$ utils/bin/darwin/yq r customizations.yaml spec.kubernetes.sealed_secrets.dnssec
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  annotations:
    sealedsecrets.bitnami.com/cluster-wide: "true"
  creationTimestamp: null
  name: dnssec-keys
spec:
  encryptedData:
    dummy: AgAXtBnJ85XQ9JlR9sfR3kNTS/CRNZsg+TRWZef28j6IWkxm7VOBxsbzEShvcO4IaeDJVPbQ9SPSlByxqB0Fq8H22W4AaGK5Oaol8COakgEJIGmYTloo+j6h5LRQ6V0Hzcnob9+y6G8vKLcvRNDtARZ9KboJr7GNtZ0ybUvhqX8rqt8ZifLuawGDUIX5/hGbF/Qw0a0hu/Aslp6Av2AwutZSXDZ1K8LNqTkopuXs66R7TUGWBciFxCdOJg6qGHCXXA3ogDfVuBk9kGMpd6TKPCFW0D4eI32JLIuUtmlBzA9AywIkdzwU9/tp7C/r+P4euW52R7CUCqaz329cS92nM5+6rPQwUrnJwAcCr/WflAbxr11hOcu6dDJMjotpiRDct3MJF/qLjDG64CuZmeXQo2O9CP+6/dIJ0zaff8YZni16fkTrL47alndu9m/v9YZDorneJ7n0SF6M4n37H1KjHPRC+QjG4iAcZVijAdhJA5vZhpKKS2oxzAvwL+VgdXbyQ1kM8fbFOsvSyzcfxGhrw2N6PS78o2iAuK5afskcEQy3v5VjqQa8pvp+cPuu2K/BgXRxNIPa4fDckWk66rRwFILjuhPU/lYqLk8jZ/rExF1LDqrnD2eEbrjAPvnv5vkXFDvBUO+cLVPUv3b4GSV+Vq5HxkQYALbTszO9YpXdraZBjfgm52MEaLXmRgERKhuZsKqiY82dGVA=
  template:
    metadata:
      annotations:
        sealedsecrets.bitnami.com/cluster-wide: "true"
      creationTimestamp: null
      name: dnssec-keys
```

With all the above information, assemble `snyk-values.yaml` as:

```yaml
global:
  chart:
    name: cray-powerdns-manager
    version: 9.9.9
manager:
  primary_server: primary/127.0.0.1
  secondary_servers: externaldns1.my.domain/1.1.1.1,externaldns2.my.domain/2.2.2.2
  base_domain: shasta.dev.cray.com
  notify_zones: shasta.dev.cray.com,8.101.10.in-addr.arpa
cray-service:
  sealedSecrets:
    - apiVersion: bitnami.com/v1alpha1
      kind: SealedSecret
      metadata:
        annotations:
          sealedsecrets.bitnami.com/cluster-wide: "true"
        creationTimestamp: null
        name: dnssec-keys
      spec:
        encryptedData:
          dummy: AgAXtBnJ85XQ9JlR9sfR3kNTS/CRNZsg+TRWZef28j6IWkxm7VOBxsbzEShvcO4IaeDJVPbQ9SPSlByxqB0Fq8H22W4AaGK5Oaol8COakgEJIGmYTloo+j6h5LRQ6V0Hzcnob9+y6G8vKLcvRNDtARZ9KboJr7GNtZ0ybUvhqX8rqt8ZifLuawGDUIX5/hGbF/Qw0a0hu/Aslp6Av2AwutZSXDZ1K8LNqTkopuXs66R7TUGWBciFxCdOJg6qGHCXXA3ogDfVuBk9kGMpd6TKPCFW0D4eI32JLIuUtmlBzA9AywIkdzwU9/tp7C/r+P4euW52R7CUCqaz329cS92nM5+6rPQwUrnJwAcCr/WflAbxr11hOcu6dDJMjotpiRDct3MJF/qLjDG64CuZmeXQo2O9CP+6/dIJ0zaff8YZni16fkTrL47alndu9m/v9YZDorneJ7n0SF6M4n37H1KjHPRC+QjG4iAcZVijAdhJA5vZhpKKS2oxzAvwL+VgdXbyQ1kM8fbFOsvSyzcfxGhrw2N6PS78o2iAuK5afskcEQy3v5VjqQa8pvp+cPuu2K/BgXRxNIPa4fDckWk66rRwFILjuhPU/lYqLk8jZ/rExF1LDqrnD2eEbrjAPvnv5vkXFDvBUO+cLVPUv3b4GSV+Vq5HxkQYALbTszO9YpXdraZBjfgm52MEaLXmRgERKhuZsKqiY82dGVA=
        template:
          metadata:
            annotations:
              sealedsecrets.bitnami.com/cluster-wide: "true"
            creationTimestamp: null
            name: dnssec-keys
```

> Note that it would probably be ideal to store a test values.yaml like the
> above `snyk-values.yaml` in the test subdirectory of the chart's repository.

Now we can render the chart's resources most closely aligned with an actual
deployment:

```
$ helm template cray-powerdns-manager --version 0.5.2 \
  --repo https://artifactory.algol60.net/artifactory/csm-helm-charts/ \
  -f snyk-values.yaml \
  > k8s-manifest.yaml
$ cat -n k8s-manifest.yaml 
     1	---
     2	# Source: cray-powerdns-manager/templates/configmap.yaml
     3	apiVersion: v1
     4	kind: ConfigMap
     5	metadata:
     6	  name: cray-powerdns-manager-config
     7	data:
     8	  primary_server: "primary/127.0.0.1"
     9	  secondary_servers: "externaldns1.my.domain/1.1.1.1,externaldns2.my.domain/2.2.2.2"
    10	  base_domain: shasta.dev.cray.com
    11	  notify_zones: "shasta.dev.cray.com,8.101.10.in-addr.arpa"
    12	---
    13	# Source: cray-powerdns-manager/charts/cray-service/templates/service.yaml
    14	apiVersion: v1
    15	kind: Service
    16	metadata:
    17	  name: cray-powerdns-manager
    18	  labels:
    19	    app.kubernetes.io/name: cray-powerdns-manager
    20	    helm.sh/base-chart: cray-service-7.0.1
    21	    helm.sh/chart: cray-powerdns-manager-9.9.9
    22	    app.kubernetes.io/instance: RELEASE-NAME
    23	    app.kubernetes.io/managed-by: Helm
    24	    
    25	  annotations:
    26	    cray.io/service: cray-powerdns-manager
    27	    
    28	spec:
    29	  type: ClusterIP
    30	  ports:
    31	    - port: 80
    32	      targetPort: http
    33	      name: http
    34	      protocol: TCP
    35	  selector:
    36	    app.kubernetes.io/name: cray-powerdns-manager
    37	    app.kubernetes.io/instance: RELEASE-NAME
    38	---
    39	# Source: cray-powerdns-manager/charts/cray-service/templates/deployment.yaml
    40	apiVersion: apps/v1
    41	kind: Deployment
    42	metadata:
    43	  name: cray-powerdns-manager
    44	  labels:
    45	    app.kubernetes.io/name: cray-powerdns-manager
    46	    helm.sh/base-chart: cray-service-7.0.1
    47	    helm.sh/chart: cray-powerdns-manager-9.9.9
    48	    app.kubernetes.io/instance: RELEASE-NAME
    49	    app.kubernetes.io/managed-by: Helm
    50	    
    51	  annotations:
    52	    cray.io/service: cray-powerdns-manager
    53	    
    54	spec:
    55	  replicas: 1
    56	  strategy:
    57	    
    58	    type: Recreate
    59	    # Need an explicit rollingUpdate: null to upgrade from default RollingUpdate
    60	    # strategy or K8S API Server will reject the merged deployment
    61	    rollingUpdate: null
    62	  selector:
    63	    matchLabels:
    64	      app.kubernetes.io/name: cray-powerdns-manager
    65	      app.kubernetes.io/instance: RELEASE-NAME
    66	  template:
    67	    metadata:
    68	      labels:
    69	        app.kubernetes.io/name: cray-powerdns-manager
    70	        app.kubernetes.io/instance: RELEASE-NAME
    71	      annotations:
    72	        service.cray.io/public: "true"
    73	        
    74	    spec:
    75	      
    76	      serviceAccountName: "jobs-watcher"
    77	      priorityClassName: csm-high-priority-service
    78	      containers:
    79	      - name: cray-powerdns-manager
    80	        image: artifactory.algol60.net/csm-docker/stable/cray-powerdns-manager:0.5.2
    81	        imagePullPolicy: Always
    82	        env:
    83	          - name: BASE_DOMAIN
    84	            valueFrom:
    85	              configMapKeyRef:
    86	                key: base_domain
    87	                name: cray-powerdns-manager-config
    88	          - name: PRIMARY_SERVER
    89	            valueFrom:
    90	              configMapKeyRef:
    91	                key: primary_server
    92	                name: cray-powerdns-manager-config
    93	          - name: SECONDARY_SERVERS
    94	            valueFrom:
    95	              configMapKeyRef:
    96	                key: secondary_servers
    97	                name: cray-powerdns-manager-config
    98	          - name: NOTIFY_ZONES
    99	            valueFrom:
   100	              configMapKeyRef:
   101	                key: notify_zones
   102	                name: cray-powerdns-manager-config
   103	          - name: PDNS_URL
   104	            value: http://cray-dns-powerdns-api:8081
   105	          - name: PDNS_API_KEY
   106	            valueFrom:
   107	              secretKeyRef:
   108	                key: pdns_api_key
   109	                name: cray-powerdns-credentials
   110	          - name: KEY_DIRECTORY
   111	            value: /keys
   112	        ports:
   113	          - containerPort: 8080
   114	            name: http
   115	        livenessProbe:
   116	          httpGet:
   117	            path: /v1/liveness
   118	            port: 8080
   119	          initialDelaySeconds: 10
   120	          periodSeconds: 30
   121	        readinessProbe:
   122	          httpGet:
   123	            path: /v1/readiness
   124	            port: 8080
   125	          initialDelaySeconds: 15
   126	          periodSeconds: 30
   127	        volumeMounts:
   128	          - name: dnssec-keys
   129	            readOnly: true
   130	            mountPath: "/secrets/sealed/dnssec-keys"
   131	          - mountPath: /keys
   132	            name: dnssec-keys
   133	            readOnly: true
   134	        securityContext:
   135	          runAsUser: 65534
   136	          runAsGroup: 65534
   137	          runAsNonRoot: true
   138	      
   139	      
   140	      
   141	      
   142	      volumes:
   143	        - name: dnssec-keys
   144	          secret:
   145	            secretName: dnssec-keys
   146	---
   147	# Source: cray-powerdns-manager/charts/cray-service/templates/sealedsecrets.yaml
   148	apiVersion: bitnami.com/v1alpha1
   149	kind: SealedSecret
   150	metadata:
   151	  annotations:
   152	    sealedsecrets.bitnami.com/cluster-wide: "true"
   153	  creationTimestamp: null
   154	  name: dnssec-keys
   155	spec:
   156	  encryptedData:
   157	    dummy: AgAXtBnJ85XQ9JlR9sfR3kNTS/CRNZsg+TRWZef28j6IWkxm7VOBxsbzEShvcO4IaeDJVPbQ9SPSlByxqB0Fq8H22W4AaGK5Oaol8COakgEJIGmYTloo+j6h5LRQ6V0Hzcnob9+y6G8vKLcvRNDtARZ9KboJr7GNtZ0ybUvhqX8rqt8ZifLuawGDUIX5/hGbF/Qw0a0hu/Aslp6Av2AwutZSXDZ1K8LNqTkopuXs66R7TUGWBciFxCdOJg6qGHCXXA3ogDfVuBk9kGMpd6TKPCFW0D4eI32JLIuUtmlBzA9AywIkdzwU9/tp7C/r+P4euW52R7CUCqaz329cS92nM5+6rPQwUrnJwAcCr/WflAbxr11hOcu6dDJMjotpiRDct3MJF/qLjDG64CuZmeXQo2O9CP+6/dIJ0zaff8YZni16fkTrL47alndu9m/v9YZDorneJ7n0SF6M4n37H1KjHPRC+QjG4iAcZVijAdhJA5vZhpKKS2oxzAvwL+VgdXbyQ1kM8fbFOsvSyzcfxGhrw2N6PS78o2iAuK5afskcEQy3v5VjqQa8pvp+cPuu2K/BgXRxNIPa4fDckWk66rRwFILjuhPU/lYqLk8jZ/rExF1LDqrnD2eEbrjAPvnv5vkXFDvBUO+cLVPUv3b4GSV+Vq5HxkQYALbTszO9YpXdraZBjfgm52MEaLXmRgERKhuZsKqiY82dGVA=
   158	  template:
   159	    metadata:
   160	      annotations:
   161	        sealedsecrets.bitnami.com/cluster-wide: "true"
   162	      creationTimestamp: null
   163	      name: dnssec-keys
   164	---
   165	# Source: cray-powerdns-manager/charts/cray-service/templates/ingress.yaml
   166	apiVersion: networking.istio.io/v1alpha3
   167	kind: VirtualService
   168	metadata:
   169	  name: "cray-powerdns-manager"
   170	  labels:
   171	    app.kubernetes.io/name: cray-powerdns-manager
   172	    helm.sh/base-chart: cray-service-7.0.1
   173	    helm.sh/chart: cray-powerdns-manager-9.9.9
   174	    app.kubernetes.io/instance: RELEASE-NAME
   175	    app.kubernetes.io/managed-by: Helm
   176	    
   177	spec:
   178	  hosts:
   179	    - "*"
   180	  gateways:
   181	    - services-gateway
   182	    - customer-admin-gateway
   183	  http:
   184	    - match:
   185	        - uri:
   186	            prefix: "/apis/powerdns-manager/"
   187	      rewrite:
   188	        uri: "/"
   189	      route:
   190	        - destination:
   191	            host: "cray-powerdns-manager"
   192	            port:
   193	              number: 80
```

Finally, it's time to scan with `snyk iac` to discover any issues:

```
$ snyk iac test k8s-manifest.yaml 

Testing k8s-manifest.yaml...


Infrastructure as code issues:
  ✗ Container is running without privilege escalation control [Medium Severity] [SNYK-CC-K8S-9] in Deployment
    introduced by [DocId: 2] > input > spec > template > spec > containers[cray-powerdns-manager] > securityContext > allowPrivilegeEscalation

  ✗ Container does not drop all default capabilities [Medium Severity] [SNYK-CC-K8S-6] in Deployment
    introduced by [DocId: 2] > input > spec > template > spec > containers[cray-powerdns-manager] > securityContext > capabilities > drop

  ✗ Container is running without cpu limit [Low Severity] [SNYK-CC-K8S-5] in Deployment
    introduced by [DocId: 2] > input > spec > template > spec > containers[cray-powerdns-manager] > resources > limits > cpu

  ✗ Container is running with writable root filesystem [Low Severity] [SNYK-CC-K8S-8] in Deployment
    introduced by [DocId: 2] > input > spec > template > spec > containers[cray-powerdns-manager] > securityContext > readOnlyRootFilesystem

  ✗ Container is running without memory limit [Low Severity] [SNYK-CC-K8S-4] in Deployment
    introduced by [DocId: 2] > input > spec > template > spec > containers[cray-powerdns-manager] > resources > limits > memory


Organization:      shasta-csm-oss
Type:              Kubernetes
Target file:       k8s-manifest.yaml
Project name:      build
Open source:       no
Project path:      k8s-manifest.yaml

Tested k8s-manifest.yaml for known issues, found 5 issues


```

All of the issues appear to be related to the `cray-powerdns-manager` container
defined starting at line 79 in `k8s-manifests.yaml`. Resolving such issues may
require additional support from parent charts, e.g., the cray-service base
chart, even though the fix may be straight-forward.



[GNU Parallel]: https://www.gnu.org/software/parallel/
