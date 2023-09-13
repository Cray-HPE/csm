#!/usr/bin/env bash

# Copyright 2020-2022 Hewlett Packard Enterprise Development LP

: "${PACKAGING_TOOLS_IMAGE:=arti.hpc.amslabs.hpecorp.net/internal-docker-stable-local/packaging-tools:0.13.0}"
: "${RPM_TOOLS_IMAGE:=arti.hpc.amslabs.hpecorp.net/internal-docker-stable-local/rpm-tools:1.0.0}"
: "${SKOPEO_IMAGE:=arti.hpc.amslabs.hpecorp.net/quay-remote/skopeo/stable:v1.13.2}"
: "${CRAY_NEXUS_SETUP_IMAGE:=arti.hpc.amslabs.hpecorp.net/csm-docker-remote/stable/cray-nexus-setup:0.7.1}"
: "${ARTIFACTORY_HELPER_IMAGE:=arti.hpc.amslabs.hpecorp.net/dst-docker-master-local/arti-helper:latest}"
: "${CFS_CONFIG_UTIL_IMAGE:=arti.hpc.amslabs.hpecorp.net/csm-docker-remote/stable/cfs-config-util:3.3.1}"
: "${LIST_IMAGES_IMAGE:=arti.hpc.amslabs.hpecorp.net/csm-docker-remote/stable/list-images:1.0.0}"
: "${SNYK_SCAN_IMAGE:=arti.hpc.amslabs.hpecorp.net/csm-docker-remote/stable/snyk-scan:1.1.0}"
: "${SNYK_AGGREGATE_RESULTS_IMAGE:=arti.hpc.amslabs.hpecorp.net/csm-docker-remote/stable/snyk-aggregate-results:1.0.1}"
: "${SNYK_TO_HTML_IMAGE:=arti.hpc.amslabs.hpecorp.net/csm-docker-remote/stable/snyk-to-html:1.0.0}"
: "${CRAY_NLS_IMAGE:=arti.hpc.amslabs.hpecorp.net/csm-docker-remote/stable/cray-nls:0.10.0}"


# Prefer to use docker, but for environments with podman
if [[ "${USE_PODMAN_NOT_DOCKER:-"no"}" == "yes" ]]; then
    echo >&2 "warning: using podman, not docker"
    shopt -s expand_aliases
    alias docker=podman
    declare -a podman_run_flags=(--userns keep-id)
else
    declare -a podman_run_flags=('') 
fi

function requires() {
    while [[ $# -gt 0 ]]; do
        command -v "$1" >/dev/null 2>&1 || {
            echo >&2 "command not found: ${1}"
            exit 1
        }
        shift
    done
}

requires docker realpath

# usage: cmd_retry <cmd> <arg1> ...
#
# Run the specified command until it passes or until it fails too many times
function cmd_retry() {
    local -i attempt
    # For now I'm hard coding these values, but it would be easy to make them into function
    # arguments in the future, if desired
    local -i max_attempts=10
    local -i sleep_time=12
    attempt=1
    while [ true ]; do
        # We redirect to stderr just in case the output of this command is being piped
        echo "Attempt #$attempt to run: $*" 1>&2
        if "$@" ; then
            return 0
        elif [ $attempt -lt $max_attempts ]; then
           echo "Sleeping ${sleep_time} seconds before retry" 1>&2
           sleep ${sleep_time}
           attempt=$(($attempt + 1))
           continue
        fi
        echo "ERROR: Unable to get $url even after retries" 1>&2
        return 1
    done
    echo "PROGRAMMING LOGIC ERROR: This line should never be reached" 1>&2
    exit 1
}

# usage: run_cmd <command> [arg1] [arg2] ...
# Runs the command. On success, just returns 0.
# On fail, prints an appropriate error message, returns 1
function run_cmd
{
    local -i rc
    rc=0
    "$@" || rc=$?
    [ $rc -eq 0 ] && return 0
    echo "ERROR: Command failed with return code $rc: $*" 1>&2
    return 1
}

# usage: generate-nexus-config (blobstore|repository) FILE
#
# Generates complete Nexus configuration for blobstores and repositories given
# an existing "template".
function generate-nexus-config() {
    docker run --rm -i "$PACKAGING_TOOLS_IMAGE" generate-nexus-config "$@"
}

# usage: helm-sync INDEX DIRECTORY
#
# Syncs the helm charts listed in the specified INDEX to the given DIRECTORY.
function helm-sync() {
    local index="$1"
    local destdir="$2"

    [[ -d "$destdir" ]] || mkdir -p "$destdir"

    #pass the repo credentials environment variables to the container that runs helm-sync
    REPO_CREDS_DOCKER_OPTIONS=""
    REPO_CREDS_HELMSYNC_OPTIONS=""
    if [ -n "${REPOCREDSVARNAME:-}" ]; then
        REPO_CREDS_DOCKER_OPTIONS="-e ${REPOCREDSVARNAME}"
        REPO_CREDS_HELMSYNC_OPTIONS="-c ${REPOCREDSVARNAME}"
    fi
    
    docker run ${REPO_CREDS_DOCKER_OPTIONS} --rm -u "$(id -u):$(id -g)" ${podman_run_flags[@]} \
        ${DOCKER_NETWORK:+"--network=${DOCKER_NETWORK}"} \
        -v "$(realpath "$index"):/index.yaml:ro" \
        -v "$(realpath "$destdir"):/data" \
        "$PACKAGING_TOOLS_IMAGE" \
        helm-sync ${REPO_CREDS_HELMSYNC_OPTIONS} -n "${HELM_SYNC_NUM_CONCURRENT_DOWNLOADS:-1}" /index.yaml /data
}

# usage: rpm-sync-latest DIRECTORY ARTIFACTORY_RPM_URL
#
# Fetches latest RPMs in the specified ARTIFACTORY_RPM_URL (Arti repo) to the given DIRECTORY/RELEASE_NAME.

function rpm-sync-latest() {
    local artifactory_rpm_release_url="$1"
    local destdir="$2"

    if [ -z "${HPE_ARTIFACTORY_USR}" ] || [ -z "${HPE_ARTIFACTORY_PSW}" ]; then
      echo 'Artifactory username or password missing, set HPE_ARTIFACTORY_USR & HPE_ARTIFACTORY_PSW environment variables'
    fi

    [[ -d "$destdir" ]] || mkdir -p "$destdir"

    docker run --rm -u "$(id -u):$(id -g)" ${podman_run_flags[@]} \
            ${DOCKER_NETWORK:+"--network=${DOCKER_NETWORK}"} \
            -v "$(realpath "$destdir"):/artifactory/downloads" \
            "$ARTIFACTORY_HELPER_IMAGE" \
            latest-rpms -r "${artifactory_rpm_release_url}" \
            -d "/artifactory/downloads" \
            -u "${HPE_ARTIFACTORY_USR}" \
            -p "${HPE_ARTIFACTORY_PSW}"
}

# usage: rpm-sync-src-latest DIRECTORY ARTIFACTORY_RPM_URL
#
# Fetches latest RPMs (including src rpms) in the specified ARTIFACTORY_RPM_URL (Arti repo) to the given DIRECTORY/RELEASE_NAME.

function rpm-sync-src-latest() {
    local artifactory_rpm_release_url="$1"
    local destdir="$2"

    if [ -z "${HPE_ARTIFACTORY_USR}" ] || [ -z "${HPE_ARTIFACTORY_PSW}" ]; then
      echo 'Artifactory username or password missing, set HPE_ARTIFACTORY_USR & HPE_ARTIFACTORY_PSW environment variables'
    fi

    [[ -d "$destdir" ]] || mkdir -p "$destdir"

    docker run --rm -u "$(id -u):$(id -g)" ${podman_run_flags[@]} \
            ${DOCKER_NETWORK:+"--network=${DOCKER_NETWORK}"} \
            -v "$(realpath "$destdir"):/artifactory/downloads" \
            "$ARTIFACTORY_HELPER_IMAGE" \
            latest-rpms -r "${artifactory_rpm_release_url}" \
            -d "/artifactory/downloads" \
            -u "${HPE_ARTIFACTORY_USR}" \
            -p "${HPE_ARTIFACTORY_PSW}" \
	    --src
}

# usage: rpm-sync INDEX DIRECTORY
#
# Syncs RPMs listed in the specified INDEX to the given DIRECTORY.
function rpm-sync() {
    local index="$1"
    local destdir="$2"
    local FAIL_ON_SIG_ERROR="" 
    if [ $# -ge 3 ]; then
        if [ -n "$3" ]; then
            FAIL_ON_SIG_ERROR="-s"
        fi
    fi 

    [[ -d "$destdir" ]] || mkdir -p "$destdir"

   #pass the repo credentials environment variables to the container that runs rpm-sync
    REPO_CREDS_DOCKER_OPTIONS=""
    REPO_CREDS_RPMSYNC_OPTIONS=""
    if [ -n "${REPOCREDSVARNAME:-}" ]; then
        REPO_CREDS_DOCKER_OPTIONS="-e ${REPOCREDSVARNAME}"
        REPO_CREDS_RPMSYNC_OPTIONS="-c ${REPOCREDSVARNAME}"
    fi

    docker run ${REPO_CREDS_DOCKER_OPTIONS} --rm -u "$(id -u):$(id -g)" ${podman_run_flags[@]} \
        ${DOCKER_NETWORK:+"--network=${DOCKER_NETWORK}"} \
        -v "$(realpath "$index"):/index.yaml:ro" \
        -v "$(realpath "$destdir"):/data" \
        "$PACKAGING_TOOLS_IMAGE" \
        rpm-sync ${REPO_CREDS_RPMSYNC_OPTIONS} -n "${RPM_SYNC_NUM_CONCURRENT_DOWNLOADS:-1}" ${FAIL_ON_SIG_ERROR} -v -d /data /index.yaml
}

# usage: extract-from-container SOURCE DESTINATION KEY
#
# Extracts files or directories with names matching the regular expression KEY from the directory-formatted
# Docker image SOURCE to the directory DESTINATION.
#
# input:
#     SOURCE      -- Directory where the Docker image layers reside
#     DESTINATION -- Directory where the extracted content should be placed; will be created if it does not exist
#     KEY         -- Key to match against; Key can be a file or a directory; Either the file or entire directory
#                    is copied to the destination directory; The key can use the wildcards used in regular expressions for grep.
# Exit codes:
#     0 - item found and extracted
#     1 - item not found or extraction failed
#

function extract-from-container () {
    local SAVED_SHELLOPTS="${SHELLOPTS}"
    echo "SHELLOPTS = ${SHELLOPTS}"
    set +e
    trap - ERR
    local SRC_DIR=$1
    local DEST_DIR=$2
    local KEY=$3

    if [ "$#" -ne 3 ]; then
        echo "Expected parameters: <Source Directory> <Destination Directory> <Key>";
        echo "Received $# parameters: $*"
        exit 1;
    fi

    if [ ! -d "${SRC_DIR}" ]; then
        echo "ERROR -- Source directory: ${SRC_DIR} is not a directory."
        exit 1;
    fi

    [[ -d "${DEST_DIR}" ]] || mkdir -p "${DEST_DIR}"

    layers="$(find "${SRC_DIR}" -type f | grep -Ev 'manifest|version')"
    for i in $layers; do
        file_matches=$(tar --force-local -tf "${i}" 2> /dev/null | grep -o "${KEY}" | sort -u)
        if [[ -n "$file_matches" ]]; then
            local cmd="tar --force-local -xf ${i} -C${DEST_DIR} ${file_matches//$'\n'/ }"
            echo "$cmd"
            $cmd
            echo ""
            # If key found a directory, move the contents out of the directory.
            name=$(basename "${file_matches}")
            if [[ -d "${DEST_DIR}"/"${name}" ]]; then
                shopt -s dotglob
                cp -a "${DEST_DIR}"/"${name}"/* "${DEST_DIR}"
                rm -rf "${DEST_DIR:?}"/"${name}"
            fi
        fi
    done
    if [[ "${SAVED_SHELLOPTS}" =~ "errexit" ]]; then
        set -e
    fi
    echo "SHELLOPTS = ${SHELLOPTS}"

}


# There are some debug statements included in the following Python script and in
# the skopeo-sync function. These can be removed later, but until we have more
# runtime with builds using this retry logic, I'd prefer to leave them in for now.

# Script arguments: <current index.yaml> [<original index.yaml> <list of paths to completed images>]
UPDATE_YAML_PY="
import sys
import yaml

index_yaml=sys.argv[1]

print('Loading docker image data from %s' % index_yaml)
with open(index_yaml, 'rt') as f:
    index_data = yaml.safe_load(f)

try:    
    orig_index_yaml=sys.argv[2]
    completed_image_file=sys.argv[3]
except IndexError:
    completed_image_file=None
    orig_index_yaml=None

if completed_image_file:
    print('Loading original docker image data from %s' % orig_index_yaml)
    with open(orig_index_yaml, 'rt') as f:
        orig_index_data = yaml.safe_load(f)

    images_not_found=list()

    print('Processing list of completed image directories in %s' % completed_image_file)
    with open(completed_image_file, 'rt') as f:
        for line in f:
            found = False
            line = line.rstrip()
            print('DEBUG: line=%s' % line)
            num_fields = len(line.split('/'))
            for n in range(1, num_fields):
                source='/'.join(line.split('/')[:n])
                image='/'.join(line.split('/')[n:])
                image_name=':'.join(image.split(':')[:-1])
                print('DEBUG: Original index: Checking for image %s, image_name %s in source %s' % (image, image_name, source))
                try:
                    source_image_versions=orig_index_data[source]['images'][image_name]
                except (KeyError, TypeError):
                    continue
                image_version=image.split(':')[-1]
                print('DEBUG: Original index: Checking for version %s' % image_version)
                if image_version in source_image_versions:
                    print('Original index: Found version %s of image %s in source %s.' % (image_version, image_name, source))
                    found = True

                try:
                    source_entry = index_data[source]
                except (KeyError, TypeError):
                    continue
                try:
                    source_images = source_entry['images']
                except (KeyError, TypeError):
                    print('Source has no images. Removing it from index: %s' % source)
                    del index_data[source]
                    continue
                image='/'.join(line.split('/')[n:])
                image_name=':'.join(image.split(':')[:-1])
                print('DEBUG: Checking for image %s, image_name %s in source %s' % (image, image_name, source))
                try:
                    source_image_versions = source_images[image_name]
                except (KeyError, TypeError):
                    continue
                image_version=image.split(':')[-1]
                print('DEBUG: Checking for version %s' % image_version)
                while image_version in source_image_versions:
                    print('Found version %s of image %s in source %s. Removing it from index' % (image_version, image_name, source))
                    source_image_versions.remove(image_version)
                if len(source_image_versions) == 0:
                    print('No more versions left for image %s in source %s. Removing it from index' % (image_name, source))
                    del source_images[image_name]
                    if len(source_images) == 0:
                        print('No more images left for source %s. Removing it from index' % source)
                        del index_data[source]
            if not found:
                print('Image not found in original index: %s' % line)
                images_not_found.append(line)

    print('Writing unfound images to %s for deletion' % completed_image_file)
    with open(completed_image_file, 'wt') as f:
        if images_not_found:
            f.write('\n'.join(images_not_found)+'\n')

print('Writing updated docker image index to %s' % index_yaml)
with open(index_yaml, 'wt') as f:
    yaml.dump(index_data, f,  default_flow_style=False)

sys.exit(0)
"
# This is just a wrapper for the above Python script, passing any arguments into it
function update-index-yaml() {
    python3 -c "${UPDATE_YAML_PY}" "$@"
}

# usage: get-pyyaml TARGET_DIRECTORY
function get-pyyaml() {
    # If we can import yaml, then nothing to do
    if python3 -c "import yaml" ; then
        echo "PyYAML appears to be installed"
        return 0
    fi
    echo "PyYAML does not appear to be installed. Installing it to '$1'"
    python3 -m ensurepip || true
    run_cmd pip3 install PyYAML \
            --no-cache-dir \
            --trusted-host arti.hpc.amslabs.hpecorp.net \
            --index-url https://arti.hpc.amslabs.hpecorp.net:443/artifactory/api/pypi/pypi-remote/simple \
            --ignore-installed \
            --target="$1" \
            --upgrade || return 1
    if [[ -n ${PYTHONPATH} ]]; then
        export PYTHONPATH="${PYTHONPATH}:$1"
    else
        export PYTHONPATH="$1"
    fi
    # Make sure we can import it
    if python3 -c "import yaml" ; then
        return 0
    fi
    echo "ERROR: Cannot import PyYAML even after pip installing it" 1>&2
    return 1
}

# usage: print-time NUM_SECONDS
function print-time() {
    local -i tmp_minutes \
             tmp_seconds
    tmp_minutes=$(($1 / 60))
    tmp_seconds=$(($1 % 60))
    if [ ${tmp_minutes} -gt 0 ]; then
        echo -n "${tmp_minutes} minute"
        [ ${tmp_minutes} -eq 1 ] || echo -n "s"
        echo -n ", "
    fi
    echo -n "${tmp_seconds} second"
    [ ${tmp_seconds} -eq 1 ] || echo -n "s"
    echo
}

# usage: skopeo-sync INDEX DIRECTORY
#
# Syncs the container images listed in the specified INDEX to the given
# DIRECTORY.
function skopeo-sync() {
    local orig_index=$(dirname "$1")/orig-$(basename "$1")
    local index=$(dirname "$1")/copy-$(basename "$1")
    local destdir="$2"

    # Define variables used for skopeo retry bandaid
    local -i max_retry_attempts=${MAX_SKOPEO_RETRY_ATTEMPTS:-'20'}
    local -i max_retry_minutes=${MAX_SKOPEO_RETRY_TIME_MINUTES:-'30'}
    local -i start_time_seconds=${SECONDS}
    local -i attempt_number=1
    local -i function_rc=1
    local -i total_synced=0
    local -i previously_synced=0
    local -i end_time_seconds \
             attempt_start_seconds \
             attempt_duration_seconds \
             total_duration_seconds \
             new_synced
    local tmpdir=/tmp/.release.sh.$$.$RANDOM.$RANDOM.$RANDOM    
    local completed_image_file="${tmpdir}/completed_images"
    local pymod_dir="${tmpdir}/pymod"
    local tmp_index="${tmpdir}/index"

    # We don't know if we're being called with set -e or not, so best to play it safe
    run_cmd cp -v "$1" "${orig_index}" || return 1
    run_cmd mkdir -pv "$destdir" "$tmpdir" "${pymod_dir}" || return 1
    
    # Normally I would use let for arithmetic, but if the let expression evaluates to 0,
    # the return code is non-0, which breaks us if we're operating under set -e
    # Therefore, in this function, arithmetic is performed in the following fashion:
    end_time_seconds=$((${start_time_seconds} + ${max_retry_minutes}*60))

    # Display the values of our $end_time_seconds variable. We have nothing to hide.
    echo "skopeo-sync: end_time_seconds=${end_time_seconds}"

    # Make sure we've got PyYAML
    get-pyyaml "${pymod_dir}"

    # Pre-process the index file through our Python script, just so that when we later do diffs,
    # it is comparing apples to apples, so to speak
    update-index-yaml "${orig_index}" || return 1
    run_cmd cp -v "${orig_index}" "$index" || return 1

    #DEBUG
    run_cmd cat "$index" || return 1

    while [ true ]; do
        echo "$(date) skopeo-sync: Beginning attempt #${attempt_number}"
        attempt_start_seconds=${SECONDS}
        skopeo_args=("--retry-times" "5" "--src" "yaml" "--dest" "dir" "--scoped")
        if [ -n "${ARTIFACTORY_USER:-}" ] && [ -n "${ARTIFACTORY_TOKEN:-}" ]; then
            skopeo_args+=("--src-creds" "${ARTIFACTORY_USER}:${ARTIFACTORY_TOKEN}")
        fi

        if docker run --rm -u "$(id -u):$(id -g)" ${podman_run_flags[@]} \
                ${DOCKER_NETWORK:+"--network=${DOCKER_NETWORK}"} \
                -v "$(realpath "$index"):/index.yaml:ro" \
                -v "$(realpath "$destdir"):/data" \
                "$SKOPEO_IMAGE" \
                sync "${skopeo_args[@]}" "/index.yaml" "/data"
        then
            function_rc=0
            echo "$(date) skopeo-sync: Attempt #${attempt_number} PASSED!"
        else
            echo "$(date) skopeo-sync: Attempt #${attempt_number} FAILED!"
        fi

        # DEBUG
        ls -R "$destdir" || true

        total_duration_seconds=$(($SECONDS - ${start_time_seconds}))
        attempt_duration_seconds=$(($SECONDS - ${attempt_start_seconds}))
        echo "skopeo-sync: Attempt duration: $(print-time ${attempt_duration_seconds})"
        if [ ${function_rc} -eq 0 ]; then
            # This means our latest attempt succeeded
            break
        elif [ $SECONDS -ge ${end_time_seconds} ]; then
            echo "skopeo-sync: ERROR: Maximum retry time exceeded. Aborting."
            break
        elif [ ${attempt_number} -ge ${max_retry_attempts} ]; then
            echo "skopeo-sync: ERROR: Maximum retry attempts exceeded. Aborting."
            break
        fi
        echo "skopeo-sync: Total duration so far: $(print-time ${total_duration_seconds})"

        # Ok, I lied earlier. I will use let in this one instance, since this should never be 0.
        let attempt_number+=1

        echo "skopeo-sync: Cleaning up incomplete images"
        find "${destdir}" -type d -name \*:\* ! -exec bash -c "[[ -f {}/manifest.json ]]" \; -print -exec rm -rvf {} \; -prune || return 1

        # For reasons I have not yet figured out, the job always tries to sync alpine:3.12
        # So it has to be removed if we are going to retry
        echo "skopeo-sync: Cleaning up alpine:3.12"
        find "${destdir}" -type d -name "alpine:3.12" -print -exec rm -rvf {} \; -prune || return 1

        # Remove any completed images from index.yaml
        if ! find "${destdir}" -type d -name \*:\* -print > "${completed_image_file}" ; then
            echo "ERROR searching for completed images or writing to '${completed_image_file}'" 1>&2
            return 1
        elif [ -s "${completed_image_file}" ]; then
            total_synced=$(wc -l "${completed_image_file}" | awk '{ print $1 }')
            new_synced=$((${total_synced} - ${previously_synced}))
            previously_synced=${total_synced}
            echo "skopeo-sync: Found ${new_synced} new completely synced images"

            # Strip off the leading ${destdir}/ from the paths
            run_cmd sed -i "s#^${destdir}/##" "${completed_image_file}" || return 1
            run_cmd cp -v "$index" "${tmp_index}" || return 1
            
            # DEBUG
            run_cmd cat "$index" || return 1
            run_cmd cat "${orig_index}" || return 1
            run_cmd cat "${completed_image_file}" || return 1

            update-index-yaml "$index" "${orig_index}" "${completed_image_file}"
            diff "${tmp_index}" "$index" || true

            # DEBUG
            run_cmd cat "${completed_image_file}" || return 1

            # For reasons I have not yet figured out, some images are synced which do not appear to be listed
            # in the manifest. It may be a dependency of some kind, or perhaps something to do with "latest".
            # Regardless, if we're going to retry, I delete these.
            echo "skopeo-sync: Delete completed images not found in original index (if any)"
            if [ -s "${completed_image_file}" ]; then
                grep -E "^[^[:space:]]" "${completed_image_file}" | sed "s#^#${destdir}/#" > "${completed_image_file}"
                #DEBUG
                run_cmd cat "${completed_image_file}" || return 1
                cat "${completed_image_file}" | xargs -r -t rm -rvf
            fi
        fi

        echo "skopeo-sync: Retrying"
    done
    echo "skopeo-sync: Totals: ${attempt_number} attempt(s) over $(print-time ${total_duration_seconds})"

    # It gives me a warm feeling to clean up after myself
    if [ -f "${index}" ]; then
        run_cmd rm -vf "${index}" || return 1
    fi
    if [ -d "${tmpdir}" ]; then
        run_cmd rm -rvf "${tmpdir}" || return 1
    fi
    
    return ${function_rc}
}

# usage: reposync URL DIRECTORY
#
# Syncs the RPM repository at URL to the specified DIRECTORY.
function reposync() {
    local url="$1"
    local name="$(basename "$2")"
    local destdir="$(dirname "$2")"

    [[ -d "$destdir" ]] || mkdir -p "$destdir"

    docker run --rm -u "$(id -u):$(id -g)" ${podman_run_flags[@]} \
        ${DOCKER_NETWORK:+"--network=${DOCKER_NETWORK}"} \
        -v "$(realpath "$destdir"):/data" \
        "$RPM_TOOLS_IMAGE" \
        /usr/local/bin/reposync "$name" "$url"
}

# usage: createrepo DIRECTORY
#
# Creates an RPM repository from RPMs under the specified DIRECTORY.
#
# Useful when using rpm-sync to copy RPMs from various upstream repositories
# to a single directory.
function createrepo() {
    local repodir="$1"

    if [[ ! -d "$repodir" ]]; then
        echo >&2 "error: no such directory: ${repodir}"
        return 1
    fi

    docker run --rm -u "$(id -u):$(id -g)" ${podman_run_flags[@]} \
        ${DOCKER_NETWORK:+"--network=${DOCKER_NETWORK}"} \
        -v "$(realpath "$repodir"):/data" \
        "$RPM_TOOLS_IMAGE" \
        createrepo --verbose /data
}

# usage: vendor-install-deps [--no-cray-nexus-setup] [--no-skopeo]
#                            [--include-cfs-config-util]
#                            RELEASE DIRECTORY
#
# Vendors installation tools for a specified RELEASE to the given DIRECTORY.
#
# Even though compatible tools may be available on the target system, vendoring
# them ensures sufficient versions are shipped.
function vendor-install-deps() {
    local include_nexus="yes"
    local include_skopeo="yes"
    local include_cfs_config_util="no"

    while [[ $# -gt 2 ]]; do
        local opt="$1"
        shift
        case "$opt" in
        --no-cray-nexus-setup) include_nexus="no" ;;
        --no-skopeo) include_skopeo="no" ;;
        --include-cfs-config-util) include_cfs_config_util="yes" ;;
        --) break ;;
        --*) echo >&2 "error: unsupported option: $opt"; exit 2 ;; 
        *)  break ;;
        esac
    done

    local release="$1"
    local destdir="$2"

    [[ -d "$destdir" ]] || mkdir -p "$destdir"

    if [[ "${include_nexus:-"yes"}" == "yes" ]]; then
        docker run --rm -u "$(id -u):$(id -g)" ${podman_run_flags[@]} \
            ${DOCKER_NETWORK:+"--network=${DOCKER_NETWORK}"} \
            -v "$(realpath "$destdir"):/data" \
            "$SKOPEO_IMAGE" \
            copy "docker://${CRAY_NEXUS_SETUP_IMAGE}" "docker-archive:/data/cray-nexus-setup.tar:cray-nexus-setup:${release}"
    fi

    if [[ "${include_skopeo:-"yes"}" == "yes" ]]; then
        docker run --rm -u "$(id -u):$(id -g)" ${podman_run_flags[@]} \
            ${DOCKER_NETWORK:+"--network=${DOCKER_NETWORK}"} \
            -v "$(realpath "$destdir"):/data" \
            "$SKOPEO_IMAGE" \
            copy "docker://${SKOPEO_IMAGE}" "docker-archive:/data/skopeo.tar:skopeo:${release}"
    fi

    if [[ "${include_cfs_config_util:-"no"}" == "yes" ]]; then
        docker run --rm -u "$(id -u):$(id -g)" ${podman_run_flags[@]} \
            ${DOCKER_NETWORK:+"--network=${DOCKER_NETWORK}"} \
            -v "$(realpath "$destdir"):/data" \
            "$SKOPEO_IMAGE" \
            copy "docker://${CFS_CONFIG_UTIL_IMAGE}" "docker-archive:/data/cfs-config-util.tar:cfs-config-util:${release}"
    fi
}

# usage: gen-version-sh RELEASE_NAME RELEASE_VERSION
#
# Generates version.sh script that outputs the specified RELEASE_NAME and/or
# RELEASE_VERSION.
function gen-version-sh() {
    cat <<EOF
#!/usr/bin/env bash

# Copyright 2020 Hewlett Packard Enterprise Development LP

: "\${RELEASE:="\${RELEASE_NAME:="${1}"}-\${RELEASE_VERSION:="${2}"}"}"

# return if sourced
return 0 2>/dev/null

# otherwise print release information
if [[ \$# -eq 0 ]]; then
    echo "\$RELEASE"
else
    case "\$1" in
    -n|--name) echo "\$RELEASE_NAME" ;;
    -v|--version) echo "\$RELEASE_VERSION" ;;
    *)
        echo >&2 "error: unsupported argumented: \$1"
        echo >&2 "usage: \${0##*/} [--name|--version]"
        ;;
    esac
fi
EOF
}

# usage: list-images INDEX_FILE [INDEX_FILE ... ]
#
# Reads one or more index.yaml files specifying container image locations
# and writes a list to stdout.
function list-images() {
    local index_files="$*"
    local index_file file_path
    declare -a file_paths
    declare -a file_mount_options
    # Get full paths of each file
    for index_file in $index_files; do
        file_path="$(realpath "$index_file")"
        file_paths+=( "$file_path" )
        file_mount_options+=( "--mount" )
        file_mount_options+=( "type=bind,src=${file_path},target=${file_path},ro=true" )
    done

    docker run --user "$(id -u):$(id -g)" --rm "${file_mount_options[@]}" \
         $LIST_IMAGES_IMAGE "${file_paths[@]}"
}

# usage: snyk-scan IMAGE [WORKDIR]
#
# Scans a container image with Snyk. This will output results
# into the current working directory.
function snyk-scan() {
    local image="$1"
    local image_basename
    image_basename="$(basename "$image")"
    snyk_environment_arguments=("--env" "SNYK_TOKEN=${SNYK_TOKEN}")
    if [ -n "${ARTIFACTORY_USER:-}" ] && [ -n "{$ARTIFACTORY_TOKEN:-}" ]; then
        snyk_environment_arguments+=("--env" "SNYK_REGISTRY_USERNAME=${ARTIFACTORY_USER}"
                                     "--env" "SNYK_REGISTRY_PASSWORD=${ARTIFACTORY_TOKEN}")
    fi

    docker run --user "$(id -u):$(id -g)" --rm "${snyk_environment_arguments[@]}" \
        --mount "type=bind,src=${PWD},target=/workdir" \
        "$SNYK_SCAN_IMAGE" "/workdir" "$image" "$image_basename"
}

# usage: snyk-aggregate-results [--helm-chart-map MAP.csv] SNYK_RESULTS_FILE [SNYK_RESULTS_FILE ...]
#
# Aggregates results from one or more `snyk.json` files (the results from snyk-scan)
# and creates an Excel spreadsheet from them. The spreadsheet is saved to the current
# working directory. Optionally, pass in a CSV file containing a mapping of containers
# to helm charts.
function snyk-aggregate-results() {
    local args="$*"
    local container_args file_mount_options arg
    declare -a container_args
    declare -a file_mount_options
    for arg in ${args}; do
        # If arg is not an option string, then assume it is a file which needs to be mounted.
        if [[ "$arg" != --* ]]; then
          file_path="$(realpath "$arg")"
          container_args+=( "$file_path" )
          file_mount_options+=( "--mount" )
          file_mount_options+=( "type=bind,src=${file_path},target=${file_path},ro=true" )
        else
          container_args+=( "$arg" )
        fi
    done
    docker run --user "$(id -u):$(id -g)" --rm "${file_mount_options[@]}" \
        --mount "type=bind,src=${PWD},target=/workdir" \
        "$SNYK_AGGREGATE_RESULTS_IMAGE" -o "/workdir/snyk.xlsx" "${container_args[@]}"
}

# usage: snyk-to-html SNYK_RESULTS_DIR
#
# Aggregates results from one or more `snyk.json` files (the results from snyk-scan)
# and creates HTML reports from them. Unlike snyk-aggregate-results which creates a single
# spreadsheet from multiple snyk results files, this function creates one HTML report per snyk
# results file. These files are saved in the same directory as `snyk.json`.
function snyk-to-html() {
    snyk_results_files="$*"
    local results_file results_file_dir results_filename
    for results_file in ${snyk_results_files}; do
        results_file_dir="$(dirname "$(realpath "$results_file")")"
        results_filename="$(basename "$results_file")"
        docker run --user "$(id -u):$(id -g)" --rm \
            --mount "type=bind,src=${results_file_dir},target=/workdir" \
            "$SNYK_TO_HTML_IMAGE" -i "/workdir/${results_filename}" -o "/workdir/snyk.html"
    done
}

# usage: iuf-validate IUF_PRODUCT_MANIFEST_FILE
#
# Validates the given Installation and Upgrade Framework (IUF) Product Manifest
# file against the IUF Product Manifest schema. On successful validation, the
# function returns 0. On a failed validation, the errors are printed to stderr,
# and the function returns 1.
function iuf-validate() {
    local manifest_file="$1"
    local manifest_basename
    manifest_basename="$(basename "$manifest_file")"

    docker run --rm -u "$(id -u):$(id -g)" ${podman_run_flags[@]} \
        ${DOCKER_NETWORK:+"--network=${DOCKER_NETWORK}"} \
        -v "$(realpath "$manifest_file"):/$manifest_basename" \
        "$CRAY_NLS_IMAGE" \
        validate "/$manifest_basename"
}
