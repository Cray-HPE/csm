# CSM

This is the CSM release repository. In contains scripts for building and
installing a CSM release distribution.

CSM release distributions are automatically uploaded to one of the following
Artifactory repositories by the CI pipeline:

* _Stable_ major-minor-patch releases --
  [shasta-distribution-stable-local](https://arti.dev.cray.com:443/artifactory/shasta-distribution-stable-local/)
* _Unstable_ pre-releases --
  [shasta-distribution-unstable-local](https://arti.dev.cray.com:443/artifactory/shasta-distribution-unstable-local/)


## Git Workflow

Changes are developed on feature branches named after the corresponding JIRA
ticket(s) and merged into `main` based on the [CASM release
process](https://connect.us.cray.com/confluence/display/CASM/CASM+Merge+and+Release+Process)
(see also the [CASM release
dashboard](https://connect.us.cray.com/confluence/display/CASM/CASM+Release+Progress+Dashboard)).
Think of `main` as always tracking the _next_ (patch) release.

Release branches track the lifespan of a specific _X.Y_ release and are named
`release/csm-X.Y`. The commit on `release/csm-X.Y` corresponding to patch
release `X.Y.Z` is tagged as `vX.Y.Z`. (This is important because the CI
pipeline is triggered based on these _version_ tags.)

Release distributions for the _latest_ CSM release are made by merging `main`
into the corresponding `release/csm-X.Y` branch, and then tagging the HEAD of
`release/csm-X.Y` with `vX.Y.Z` where `Z` is either:

* `0` -- indicating the start of a new CSM _X.Y_ release; or,
* `+1` of the previous patch number.


## Release Process


### Preparation

CSM releases are prescribed by [CASMREL
tickets](https://connect.us.cray.com/jira/projects/CASMREL/issues/) for a
specific version. The following procedure updates `main` branch with approved
changes for the next release.

**Note**: The [`git vendor`](https://github.com/brettlangdon/git-vendor) tool
is used to vendor dependencies from other repositories.

1.  Review the corresponding [CASMREL
    ticket](https://connect.us.cray.com/jira/projects/CASMREL/issues/) and
    ensure all required issues have PRs merged and are marked DONE. Merge any
    PRs against the CASMREL ticket itself last (by convention).

2.  Run `./assets.sh` to verify that the URLs for the Cray Preinstall Toolkit
    and Kubernetes and Storage-Ceph node-image assets are valid.

3.  Update vendored repositories as appropriate:

    *   `git vendor update release master` -- To update to the latest
        [release](https://stash.us.cray.com/projects/SHASTARELM/repos/release/browse)
        tooling.

    *   `git vendor update shasta-cfg master` -- To update to the latest
        version of [SHASTA-CFG/stable](https://stash.us.cray.com/projects/SHASTA-CFG/repos/stable/browse).

    *   `git vendor update docs-csm-install release/shasta-1.4` -- To
        update to the latest [_stable_ CSM install
        docs](https://stash.us.cray.com/projects/MTL/repos/docs-csm-install/browse?at=refs%2Fheads%2Frelease%2Fshasta-1.4).

        **NOTE:** Unlike the `release` and `shasta-cfg` vendored repositories,
        `docs-csm-install` builds an RPM that is installed in the Cray
        Preinstall Toolkit ISO. That is why it is vendored from the
        `release/shasta-1.4` branch.

    *   `git push` changes to `main`

4.  Mark the CASMREL ticket as `IN REVIEW`.


### Create Release Distribution

The [`csm` Jenkins job (under
`casmpet-team`)](https://cje2.dev.cray.com/teams-casmpet-team/job/casmpet-team/job/csm/)
is configured to run release.sh (see Jenkinsfile) on any commit with a version
tag (i.e., a tag beginning with `v`). In order to create a release
distribution, the following procedure updates and tags the corresponding
release branch and relies on the pipeline to run release.sh with
`RELEASE_VERSION` set to the output of version.sh.



1.  Checkout the current release branch as corresponding to the version in the
    CASMREL ticket, e.g., `git checkout release/csm-0.8`.

2.  Merge in `main`: `git merge --no-edit --no-ff origin/main`

3.  Tag the current release branch with the version corresponding to the
    CASMREL ticket, e.g., `git tag v0.8.0`.

4.  Push the updates to the release branch, e.g., `git push -u origin
    release/csm-0.8`.

5.  Push tags: `git push --tags`

6.  Monitor the [release’s
    build](https://cje2.dev.cray.com/teams-casmpet-team/blue/organizations/casmpet-team/csm/activity)
    and restart it if it fails from transient errors (e.g., connection timeouts
    to helmrepo.dev.cray.com, dtr.dev.cray.com, or artifactory repositories).

7.  On success, mark the CASMREL ticket as `DONE` and add a comment with the
    [URL of the release
    distribution](https://arti.dev.cray.com/artifactory/shasta-distribution-stable-local/csm/),
    e.g.:

    > Release distribution at
    > https://arti.dev.cray.com/artifactory/shasta-distribution-stable-local/csm/csm-0.8.0.tar.gz

8.  Announce the availability of the release in the #casm-release-management
    Slack channel, e.g.:

    > CSM v0.8.0 at
    > https://arti.dev.cray.com/artifactory/shasta-distribution-stable-local/csm/csm-0.8.0.tar.gz

