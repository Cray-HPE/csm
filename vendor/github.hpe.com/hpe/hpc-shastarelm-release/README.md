# SHASTARELM/release

SHSATARELM/release contains utilities for creating release distributions (e.g.,
packaging assets) and facilitating installation (e.g., configuring Nexus,
uploading assets). It may be _vendored_ into a product stream repository as
appropriate.


## Release Distributions

To facilitate integration with future CI pipeline enhancements, product stream
repositories should contain a `release.sh` script that generates a release
distribution, a tar-gzipped file containing all necessary assets and scripts to
configure and install the corresponding product.

Release distributions are tar-gzipped files and are expected to maintain the
following conventional structure:

* `README` -- Description of product and contents of the release distribution.

* `INSTALL` -- High-level installation documentation describing how to run
  `install.sh`, including available options and recommended settings, as well
  as where to find more comprehensive documentation (e.g., URL, in
  `docs/install.html`).

* `install.sh` -- The entry point script that facilitates installation.

* `lib/` -- Directory containing helper scripts used in `install.sh`.

* `vendor/` -- Directory containing installation tools vendored from upstream
  sources.

* `nexus-blobstores.yaml` and `nexus-repositories.yaml` -- Nexus configuration
  files for blob stores and repositories to be created during `install.sh`.

* `manifests/` -- Directory containing Loftsman manifests defining Helm charts
  to be deployed. Manifests are expected to be _generated_ using `manifestgen`
  along with the system’s `customizations.yaml` before being deployed using
  `loftsman ship`.

* `docs/` -- Directory containing rendered/generated (e.g., HTML, PDF) product
  documentation; may also include source files and build scripts (e.g.,
  `Makefile`).

Asset directories, assuming the release distribution packages assets of that type:

* `docker/` -- Directory containing ~~Docker~~ container images. Note that this
  directory is often generated from a Skopeo sync index and should have
  subdirectories based on image repositories. Container images should be
  uploaded to the `registry` supported by CSM. (Exposing access to additional
  registries will require changes to Nexus’ ingress configuration; i.e., _these
  aren’t the droids you’re looking for_.)

* `helm/` -- Directory containing Helm charts. Note that Helm charts are
  commonly uploaded to the `charts` repository supported by CSM; however,
  subdirectories are recommended if charts will be uploaded to different
  product-specific Nexus repositories.

* `rpms/` -- Directory containing RPM repositories. Subdirectories are expected
  to correspond to Nexus repositories (defined in `neuxs-repositories.yaml`)
  and must contain valid repository metadata (i.e., repodata/repomd.xml).

* `squashfs/` -- Directory containing SquashFS files. Subdirectories are
  recommended if files will be uploaded to different Nexus repositories.


## Vendor SHASTARELM/release

Use [`git-vendor`](https://github.com/brettlangdon/git-vendor), a wrapper
around `git-subtree` commands for checking out and updating vendored
dependencies. Installation via Homebrew is simply `breq install git-vendor`.
Once installed, vendor this library into a product release repository via:

```bash
$ git vendor add release https://stash.us.cray.com/scm/shastarelm/release.git master
```


## Nexus Setup

The `lib/install.sh` library contains some helper functions for setting up and
configuring Nexus. In particular:

* `nexus-setup` -- Facilitates setup of blob stores and repositories
* `nexus-upload` -- Uploads a directory of assets to a repository
* `nexus-sync` -- Uploads container images to a registry

In order to use the above helpers, release distributions should vendor the
installer dependencies using the `vendor-install-deps` from `lib/release.sh`.
Before using the helpers, installers must load them using `load-install-deps`
and are expected to clean them up using `clean-install-deps`. In particular, be
aware that `load-install-deps` sets environment variables to identify the
install tools, which are then used in the above helpers.

More advanced operations may use the Nexus REST API directly at
https://packages.local/service/rest.


### Naming RPM Repositories

RPM repositories should be named `<product>[-<product version>]-<os dist>-<os
version>[-compute][-<arch>]` where

* `<product>` indicates the product (e.g, ‘cos’, ‘csm’, ‘sma’)

* `-<product version>` indicates the product version (e.g., `-1.4.0`,
  `-latest`, `-stable`); group or proxy repositories that represent _current_
  or _active_ repositories omit `-<product version>`

* `-<os dist>` indicates the OS distribution (e.g., `-sle`)

* `-<os version>` indicates the OS version (e.g., `-15sp1`, `-15sp2`)

* `-compute` must be specified if the repository contains RPMs specific to
  compute nodes and omitted otherwise; there is no suffix for repositories
  containing NCN RPMs

* `-<arch>` must be specified if the repository is specific to a system
  architecture (e.g., `-noarch`, `-x86_64`) and omitted otherwise


### Deleting Blob Stores and Repositories

The `nexus-setup` helper attempts to first create and then update resources. In
general, it is able to adjust various settings for existing resources provided
they are of the same `type`. However, if the existing resource is of a
different type (e.g., when creating a `hosted` repository when a `proxy` one
already exists), it will most likely fail. When this happens, the typical
resolution is to delete the existing repository to allow `nexus-setup` to
recreate it with the desired configuration.

To delete a blob store, send an HTTP `DELETE` to
`/service/rest/v1/blobstores/<name>`. For example,

```
# curl -sfkSL -X DELETE "https://packages.local/service/rest/v1/blobstores/<name>"
```

To delete a repository, send an HTTP `DELETE` to
`/service/rest/beta/repositories/<name>`. For example,

```
# curl -sfkSL -X DELETE "https://packages.local/service/rest/beta/repositories/<name>”
```

Using `yq` all the blob stores or repositories defined in
`nexus-blobstores.yaml` or `nexus-repositories.yaml` may be deleted with a
single command. For blob stores, use:

`yq` v3:

```
# yq r -d '*' nexus-blobstores.yaml name | while read blobstore; do curl -sfkSL -X DELETE "https://packages.local/service/rest/v1/blobstores/${blobstore}"; done
```

`yq` v4:

```
# yq e -N '.name' nexus-blobstores.yaml | while read blobstore; do curl -sfkSL -X DELETE "https://packages.local/service/rest/v1/blobstores/${blobstore}"; done
```

For repositories, use:

`yq` v3:

```
# yq r -d '*' nexus-repositories.yaml name | while read repo; do curl -sfkSL -X DELETE "https://packages.local/service/rest/beta/repositories/${repo}"; done
```

`yq` v4:

```
 yq e -N '.name' nexus-repositories.yaml | while read repo; do curl -sfkSL -X DELETE "https://packages.local/service/rest/beta/repositories/${repo}"; done
```

**WARNING:** It is strongly recommended that installers do **NOT**
automatically delete resources as part of Nexus setup. Otherwise valid content
may be inadvertently deleted.
