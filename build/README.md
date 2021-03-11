# Building a Release Distribution

CSM releases are managed via [CASMREL issues]. For a specific issue (i.e.,
version):

1. Carefully review the CASMREL issue and ensure all required issues have PRs
   merged and are marked DONE. By convention, PRs on the CASMREL issue itself
   should be merged last. When all required issues are closed and PRs merged,
   mark it `IN REVIEW`.

2. `git checkout ${ref}` the appropriate branch (i.e., `release/X.Y` or `main`)

3. `git pull` updates

4. Run `./assets.sh` to verify that the URLs for the Cray Preinstall Toolkit
   and Kubernetes and Storage-Ceph node-image assets are valid.

5. TODO Verify docker/index.yaml and helm/index.yaml contents to prevent the
   build from failing because of a typo or a dependency that does not exist.

6. `git tag v${version}` with the corresponding version as indicated in the
   CASMREL issue.

7. `git push --tags` will trigger the [Jenkins `csm` job under
   `casmpet-team`)][Jenkins job] (see [Jenkinsfile](/Jenkinsfile)), which will
   run [release.sh](/release.sh) with `RELEASE_VERSION` based on the tag.

8. Monitor the [Jenkins build] and restart it if it fails from transient
   errors (e.g., connection timeouts to helmrepo.dev.cray.com,
   dtr.dev.cray.com, or artifactory repositories).

9. On success, mark the CASMREL issue `DONE` and add a comment with a link
   to the release distribution in the corresponding Artifactory repository:

   - [shasta-distribution-unstable-local] for pre-release versions (e.g.,
     alpha, beta, release candidates)
   - [shasta-distribution-stable-local] for release versions

   For example, the comment for CSM 0.9.0 would be:

   > Release distribution at
   > https://arti.dev.cray.com/artifactory/shasta-distribution-stable-local/csm/csm-0.9.0.tar.gz

10. Announce the availability of the release in the #casm-release-management
    Slack channel. E.g.,

    > CSM v0.9.0 at
    > https://arti.dev.cray.com/artifactory/shasta-distribution-stable-local/csm/csm-0.9.0.tar.gz


[CASMREL issues]: https://connect.us.cray.com/jira/projects/CASMREL/issues/
[Jenkins job]: https://cje2.dev.cray.com/teams-casmpet-team/job/casmpet-team/job/csm/
[Jenkins build]: https://cje2.dev.cray.com/teams-casmpet-team/blue/organizations/casmpet-team/csm/activity
[shasta-distribution-stable-local]: https://arti.dev.cray.com/artifactory/shasta-distribution-stable-local/csm/
