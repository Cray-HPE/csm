# Release Guide


## Building a Release Distribution

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

7. `git push --tags` will trigger the [Jenkins job] (see
   [Jenkinsfile](../Jenkinsfile)), which will run [release.sh](../release.sh)
   with `RELEASE_VERSION` based on the tag.

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


## Creating a Release Distribution Patch

Requires the release distirbutions for both _source_ (`$src_version`) and
_destination_ (`$dst_version`) versions to be extracted in the same directory.

1. Save the patch filename to a variable for convenience:

   ```bash
   $ patchfile="csm-${src_version}-${dst_version}.patch"
   ```

2. Compute the binary diff. Note that this will take a while due to the size of
   CSM release distributions:

   ```bash
   $ git diff --no-index --binary "csm-${src_version}" "csm-${dst_version}" > "$patchfile"
   ```

3. Compute and review _summary_ and _numstat_ files that describe the patch.
   These are useful for analyzing the patch contents and should be attached
   to the CASMREL issue for the _destination_ version.

   ```bash
   $ git apply --summary -p2 --whitespace=nowarn --directory="csm-${src_version}" "$patchfile" > "${patchfile}-summary"
   $ git apply --numstat -p2 --whitespace=nowarn --directory="csm-${src_version}" "$patchfile" > "${patchfile}-numstat"
   ```

4. Compress the patch:

   ```bash
   $ gzip "$patchfile"
   ```

5. Login to [Artifactory] and generate an API key from your [profile page].
   Set it as `$apikey`.

6. Upload the compressed patch to [Artifactory] using `$apikey`. Use repository
   `$repo` based on the _destination_ release.

   - `repo=shasta-distribution-unstable-local` - Destination is a pre-release
     version (e.g., alpha, beta, release candidate)

   - `repo=shasta-distribution-stable-local` - Destination is a full release
     version

   ```bash
   $ curl -sSLki -X PUT -H "X-JFrog-Art-Api: ${apikey}" "https://arti.dev.cray.com/artifactory/${repo}/csm/${patchfile}.gz" -T "${patchfile}.gz"
   ```


## Applying a Release Distribution Patch

Assumes the _source_ version (`$src_version`) release distribution and the
desired compressed patch (`${patchfile}.gz`) have been downloaded.

1. Extract the source release distribution:

   ```bash
   $ tar -xzf csm-${src_version}.tar.gz
   ```

2. Decompress the patch:

   ```bash
   $ gunzip "${patchfile}.gz"
   ```

3. Apply the patch:

   ```bash
   $ git apply -p2 --whitespace=nowarn --directory="csm-${src_version}" "$patchfile"
   ```

4. Update the name of release distribution directory:

   ```bash
    $ mv csm-${src_version} "$(./csm-${src_version}/lib/version.sh)"
    ```


[CASMREL issues]: https://connect.us.cray.com/jira/projects/CASMREL/issues/
[Jenkins job]: https://cje2.dev.cray.com/teams-casmpet-team/job/casmpet-team/job/csm/
[Jenkins build]: https://cje2.dev.cray.com/teams-casmpet-team/blue/organizations/casmpet-team/csm/activity
[shasta-distribution-unstable-local]: https://arti.dev.cray.com/artifactory/shasta-distribution-unstable-local/csm/
[shasta-distribution-stable-local]: https://arti.dev.cray.com/artifactory/shasta-distribution-stable-local/csm/
[Artifactory]: https://arti.dev.cray.com/
[profile page]: https://arti.dev.cray.com/ui/admin/artifactory/user_profile
