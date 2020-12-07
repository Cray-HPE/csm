SHASTARELM/release
==================

SHSATARELM/release contains utilities for creating release distributions (e.g.,
packaging assets) and facilitating installation (e.g., configuring Nexus,
uploading assets). It may be _vendored_ into a product stream repository as
appropriate.

* `lib/release.sh` -- Common functions for building release distributions;
  e.g., syncing assets from remote repositories to a release distribution
  directory.

* `lib/install.sh` -- Common functions for installation; e.g., creating Nexus
  repositories, uploading assets to Nexus repositories.


Release Distributions
---------------------

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


Vendor SHASTARELM/release
-------------------------

Use [`git-vendor`](https://github.com/brettlangdon/git-vendor), a wrapper
around `git-subtree` commands for checking out and updating vendored
dependencies, to vendor SHASTARELM/release in a product’s release repository.
Installation via [Homebrew](https://brew.sh) is simply `brew install
git-vendor`, then

```
$ git vendor add release https://stash.us.cray.com/scm/shastarelm/release.git
```

This will create the directory
`vendor/stash.us.cray.com/scm/shastarelm/release` and will track `master`
branch. Fetch updates via

```
$ git vendor update release
```


`release.sh`
------------

Use library functions in `lib/release.sh` to perform common tasks associated
with building a release distribution.

### Generating Nexus Configuration

Use `generate-nexus-config` to generate a complete
Nexus configuration for blob stores and repositories.

### Syncing Assets

TODO

### RPM Repositories

The default repository format for RPMs is `yum`. Nexus will automatically
generate repository metadata `yum` repositories; however, Shasta 1.3
experienced issues with Nexus keeping metadata up-to-date for large
repositories. Instead, it is highly recommended that products define `raw`
format repositories and use the `createrepo` utility to generate repository
metadata when building a release distribution.

### Vendor Installation Tools

Keep in mind that `install.sh` will be run from the context of a release
distribution, not a release repository. Remember to have `release.sh` add
dependent installation scripts (e.g., `lib/install.sh`) to the release
distribution so they're available during install.


`install.sh`
------------

Use functions in `lib/install.sh` to perform common installation tasks.

### Configuring Nexus

TODO

### Uploading Assets to Nexus Repositories

TODO
