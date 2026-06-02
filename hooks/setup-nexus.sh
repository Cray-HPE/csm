#!/usr/bin/env bash
#
#  MIT License
#
#  (C) Copyright 2026 Hewlett Packard Enterprise Development LP
#
#  Permission is hereby granted, free of charge, to any person obtaining a
#  copy of this software and associated documentation files (the "Software"),
#  to deal in the Software without restriction, including without limitation
#  the rights to use, copy, modify, merge, publish, distribute, sublicense,
#  and/or sell copies of the Software, and to permit persons to whom the
#  Software is furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included
#  in all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
#  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
#  OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
#  ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
#  OTHER DEALINGS IN THE SOFTWARE.
#
set -eo pipefail

HOOKS_PATH="$(readlink -f hooks)"
source "${HOOKS_PATH}/install.sh"
. /etc/cray/upgrade/csm/myenv

requires curl jq

load-install-deps

# Deletes any given nexus repository by name.
function nexus-delete-repo() {
    nexus-get-credential
    local name="${1:-}"
    local error=0
    printf >&2 "Deleting %s ..." "$name"
    if ! curl \
    -fLs \
    -u "${NEXUS_USERNAME}":"${NEXUS_PASSWORD}" \
    -X DELETE \
    "${NEXUS_URL}/service/rest/v1/repositories/${name}" ; then
        error=1
    fi
    if [ "$error" -ne 0 ]; then
        echo >&2 'Errors found.'
    else
        echo 'Done'
    fi
    return "$error"
}

# Returns the member repository of the CSM noos repository group.
function get-csm-noos-member {
    nexus-get-credential
    local repo_name
    repo_name=$(curl -fLs -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" -X GET "${NEXUS_URL}/service/rest/v1/repositories/raw/group/csm-noos" | jq -r '.group.memberNames[0]')
    if [ "$repo_name" = 'null' ] || [ -z "$repo_name" ]; then
        echo >&2 'Could not resolve a member repository for csm-noos!'
        return 1
    fi
    echo "$repo_name"
    exit 0
}

# Returns a JSON payload of all the artifacts within a given repository.
function get-artifact-list {
    nexus-get-credential
    local repo_name
    repo_name="$1"
    if [ -z "$repo_name" ]; then
        echo >&2 'Can not get artifacts, no repository name was resolved.'
        return 1
    fi

    local items='[]'
    local page_items
    local response
    local encodedToken
    local continuationToken

    url="${NEXUS_URL}/service/rest/v1/components?repository=${repo_name}"
    tmp_items_file="$(mktemp)"
    tmp_page_file="$(mktemp)"
    tmp_merge_file="$(mktemp)"

    # Start with empty array
    printf '[]' > "${tmp_items_file}"

    while :; do
       response="$(curl -fLs -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" -X GET "${url}")" || {
           echo "Request failed for URL: ${url}" >&2
           break
       }

       jq -c '.items // []' <<< "${response}" > "${tmp_page_file}" || {
           echo "Failed to parse items from response" >&2
           break
       }

       # Merge arrays from files (no huge argv)
       jq -cs '.[0] + .[1]' "${tmp_items_file}" "${tmp_page_file}" > "${tmp_merge_file}" || {
           echo "Failed to merge items" >&2
           break
       }
       mv "${tmp_merge_file}" "${tmp_items_file}"

       continuationToken="$(jq -r '.continuationToken // empty' <<< "${response}")" || {
             echo "Failed to parse continuationToken" >&2
             break
       }

       [ -z "${continuationToken}" ] && break

       encodedToken="$(jq -rn --arg t "${continuationToken}" '$t | @uri')"
       url="${NEXUS_URL}/service/rest/v1/components?repository=${repo_name}&continuationToken=${encodedToken}"
    done

    cat "${tmp_items_file}"
    rm -f "${tmp_items_file}" "${tmp_page_file}" "${tmp_merge_file}"

}

# Downloads items based on the Nexus components payload structure and returns their download location.
function download-items {
    nexus-get-credential
    local items
    local decoded
    local artifact_path
    local download_url
    items="$1"
    if [ -z "$items" ]; then
        echo >&2 'No items to download!'
        return 1
    fi
    workdir="$CSM_ARTI_DIR/$(mktemp -d .rpm-XXXXXXX)"
    for item in $(jq -r '.[] | @base64' <(echo "$items")); do
        decoded="$(echo "$item" | base64 --decode | jq -r)"
        dir="${workdir}$(jq -r '.group' <(echo "$decoded"))"
        mkdir -p "$dir"
        download_url="$(jq -r '.assets[0].downloadUrl' <(echo "$decoded"))"
        artifact_path="$(jq -r '.assets[0].path' <(echo "$decoded"))"
	curl -fLs -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" -o "${workdir}/${artifact_path}" "${download_url}" || return "$?"
    done
    echo "$workdir"
}

printf 'Resolving repository member for csm-noos ... '
repository="$(get-csm-noos-member)"
if [ -n "$repository" ]; then
    echo 'Done'
else
    echo 'Failed!'
    exit 1
fi

echo "Working on repository: $repository"

if [ -d "${CSM_ARTI_DIR}/$repository" ]; then
    printf "Found [%s] in hotfix directory from previous run. Cleaning ... " "$repository"
    rm -rf "${CSM_ARTI_DIR:?}/${repository:?}"
    echo 'Done'
fi

printf "Resolving artifacts ... "
artifacts=$(get-artifact-list "$repository")
if [ -n "$artifacts" ]; then
    echo 'Done'
else
    echo 'Failed!'
    exit 1
fi

printf 'Downloading resolved artifacts ... '
downloads=$(download-items "$artifacts")
if [ ! -d "$downloads" ]; then
    echo 'Failed!'
    exit 1
else
    mv "$downloads" "$repository"
    echo 'Done'
fi

printf 'Checking if IUF has already uploaded the rpms to Nexus ... '
if rsync -rltDq --ignore-existing "${CSM_ARTI_DIR}/rpm/cray/csm/noos/" "${CSM_ARTI_DIR}/${repository}"; then
    echo 'Done'
else
    echo 'Failed!'
    exit 1
fi

createrepo "$repository"

nexus-delete-repo csm-noos
nexus-delete-repo "$repository"

export repository
# shellcheck disable=SC2016
envsubst '$repository' < "${CSM_ARTI_DIR}/nexus-repositories.template.yaml" > "${CSM_ARTI_DIR}/nexus-repositories-csm-1.7.1-patch-noos.yaml"

echo "Creating repository [$repository] and repository group [csm-noos] ... "
nexus-setup repositories "${CSM_ARTI_DIR}/nexus-repositories-csm-1.7.1-patch-noos.yaml"

echo "Uploading artifacts ... "
nexus-upload raw "$repository/" "$repository"
nexus-wait-for-rpm-repomd "$repository"

clean-install-deps

cat >&2 <<EOF
+ Nexus setup complete
setup-nexus.sh: OK
EOF
