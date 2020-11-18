# CSM

This repo is intended to include all of the pieces required to create a new build and release of CSM.

The idea is that a build of this repo will assemble all of the individual CSM components, tag the various repos (and this repo), bump the CSM version, and package all of the artifacts into a single package that could then be uploaded to Artifactory.

## Components

For now, we're including these repos as part of the CSM release.

* TODO

## Artifacts

For now, these artifacts are included as part of CSM

* ncn-common
* ncn-base
* ncn-k8s
* ncn-ceph
* livecd-iso
* csi
* CSM manifests
* tests

## Artifact Repositories

CSM builds will eventually be packaged and uploaded to Artifactory.  Builds will be unstable by default until promoted to stable.

These are the repos we'll be using

| Repo                            |  URL  |
|---------------------------------|-------|
| csm-distribution-stable-local   | https://arti.dev.cray.com:443/artifactory/csm-distribution-stable-local/ |
| csm-distribution-unstable-local | https://arti.dev.cray.com:443/artifactory/csm-distribution-unstable-local/ |

