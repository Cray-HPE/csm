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

Requires the release distributions for both _source_ (`$src_version`) and
_destination_ (`$dst_version`) versions to be extracted in the same directory.

> **`CAUTION:`** The patch process is known to work with Git >= 2.16.5. Older
> versions of Git may not correctly compute the binary patch or report
> summary or stat details.

1. Save the patch filename to a variable for convenience:

   ```bash
   $ patchfile="csm-${src_version}-${dst_version}.patch"
   ```

2. Compute the binary patch. Note that this will take a while due to the size
   of CSM release distributions:

   ```bash
   $ git diff --no-index --binary "csm-${src_version}" "csm-${dst_version}" > "$patchfile"
   ```
   
   > **`WARNING:`** Depending on the number and scope of changes, `git` may
   > complain about rename detection:
   >
   > ```
   > warning: inexact rename detection was skipped due to too many files.
   > warning: you may want to set your diff.renameLimit variable to at least 1574 and retry the command.
   > ```
   >
   > In this case, specify the `-l` flag to `git diff` with based on the
   > suggestion in the warning message. For example, for the above warning
   > message, rerunning as `git diff -l1600 ...` succeeded without any issues.
    

3. Compute and review _summary_ and _numstat_ files that describe the patch.
   These are useful for analyzing the patch contents and should be attached to
   the CASMREL issue for the _destination_ version.

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
   $ curl -sSLki -X PUT -H "X-JFrog-Art-Api: ${apikey}" -H "X-Checksum-Sha1: $(sha1sum "${patchfile}.gz" | awk '{print $1}')" "https://arti.dev.cray.com/artifactory/${repo}/csm/${patchfile}.gz" -T "${patchfile}.gz"
   ```


## Applying a Release Distribution Patch

Assumes the _source_ version (`$src_version`) release distribution and the
desired compressed patch (`${patchfile}.gz`) have been downloaded.

1. Extract the source release distribution:

   ```bash
   $ tar -zxvf csm-${src_version}.tar.gz
   ```

2. Decompress the patch:

   ```bash
   $ gunzip "${patchfile}.gz"
   ```

3. Apply the patch:

   > **`CAUTION:`** The patch process is known to work with Git >= 2.16.5.
   > Older versions of Git may not correctly apply the binary patch. Run
   > `git version` to see what version of Git is currently installed:
   >
   > ```bash
   > $ git version
   > git version 2.26.2
   > ```
   >
   > **`NOTE:`** Since CSM 0.8.0, release distributions have included Git >=
   > 2.26.2 in the `embedded` repository. Install it using `zypper` as follows:
   >
   > ```bash
   > $ sudo zypper addrepo -fG "csm-${src_version}/rpm/embedded" "csm-${src_version}-embedded"
   > $ sudo zypper install -y git
   > ```

   ```bash
   $ git apply -p2 --whitespace=nowarn --directory="csm-${src_version}" "$patchfile"
   ```

4. Set `CSM_RELEASE` based on the new version:

   ```bash
   $ export CSM_RELEASE="$(./csm-${src_version}/lib/version.sh)"
   ```

5. Update the name of CSM release distribution directory:

   ```bash
   $ mv csm-${src_version} "$CSM_RELEASE"
   ```

6. Tar up the patched release distribution:

   > If desired, the `--remove-files` option may be appended to the below command.
   > **`CAUTION:`** This will remove files after they are added to the
   > archive. However, the install process may require some of these files, so
   > it may be safer to delay deleting them.

   ```bash
   $ tar -cvzf ${CSM_RELEASE}.tar.gz "${CSM_RELEASE}/"
   ```

7. Proceed with installation using `${CSM_RELEASE}.tar.gz`


[CASMREL issues]: https://connect.us.cray.com/jira/projects/CASMREL/issues/
[Jenkins job]: https://cje2.dev.cray.com/teams-casmpet-team/job/casmpet-team/job/csm/
[Jenkins build]: https://cje2.dev.cray.com/teams-casmpet-team/blue/organizations/casmpet-team/csm/activity
[shasta-distribution-unstable-local]: https://arti.dev.cray.com/artifactory/shasta-distribution-unstable-local/csm/
[shasta-distribution-stable-local]: https://arti.dev.cray.com/artifactory/shasta-distribution-stable-local/csm/
[Artifactory]: https://arti.dev.cray.com/
[profile page]: https://arti.dev.cray.com/ui/admin/artifactory/user_profile
