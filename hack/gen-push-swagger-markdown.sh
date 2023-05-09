#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2023 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#

set -e -o pipefail
function usage() {
    echo "Generate API docs from swagger file URLs provided in csm manifests."
    echo "Optionally commit to docs-csm, tag head of the branch with next"
    echo "version increment and wait for docs-csm RPM to be published."
    echo ""
    echo "Usage: $0 <docs-csm-branch> [--push [--wait]]"
    echo ""
    echo "If --push specified:"
    echo "    * push changes (if any) and new tag (if any) to specified docs-csm branch"
    echo "    * git must be set to allow push to specified tag of docs-csm and push a new tag:"
    echo "      if GITHUB_APP_INST_TOKEN env variable is set, git https connection with x-access-token"
    echo "      will be used, git ssh connection otherwise."
    echo ""
    echo "If --wait specified:"
    echo "    * wait for docs-csm RPM package to be published at https://artifactory.algol60.net"
    echo "    * ARTIFACTORY_USERNAME and ARTIFACTORY_TOKEN environment variables must be set"
    exit 1
}

function error() {
    echo "${1}"
    exit 1
}

function wait_for_docs_csm_publish() {
    tag="${1}"
    filename="docs-csm-${tag#v}-1.noarch.rpm"
    # 120 attempts with 10 sec wait gives ~ 20 minutes for package to be published.
    attempts=120
    wait=10
    echo "Waiting for ${filename} to be published ..."
    counter=0
    while [ $counter -le $attempts ]; do
        num_results=$(curl -Ss -u "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_TOKEN}" "https://artifactory.algol60.net/artifactory/api/search/artifact?name=${filename}&repos=csm-rpms" | jq -r '.results | length')
        if [ $((num_results)) -eq 0 ]; then
            echo "Attempt ${counter} / ${attempts}: not published yet"
        else
            echo "Package ${filename} was successfully published."
            return 0
        fi
        counter=$(($counter + 1))
        sleep $wait
    done
    echo "ERROR: giving up after ${attempts} attempts."
    exit 2
}

function increment_push_tag() {
    wait="${1}"
    last_tag="$(git describe --tags | awk -F- '{print $1}')"
    echo "${last_tag}" | grep -E -q -x 'v[0-9]+\.[0-9]+\.[0-9]+' || error "ERROR: Unable to compute version increment. Latest tag ${last_tag} of docs-csm repo is not in vX.Y.Z format."
    new_tag=$(echo "${last_tag}" | awk -F. '{print $1 "." $2 "." (int($3)+1) }')
    echo "Tagging docs-csm with new tag ${new_tag} ..."
    git tag "${new_tag}"
    echo "Pushing tag ${new_tag} of docs-csm ..."
    git push -q origin "${new_tag}"
    if [ "${wait}" == "1" ]; then
        wait_for_docs_csm_publish "${new_tag}"
    fi
}

docs_csm_branch="${1}"; shift || usage
push=0
wait=0

while [ -n "${1}" ]; do
    case "${1}" in
        --push)
            push=1
            ;;
        --wait)
            wait=1
            ;;
        *)
            usage
            ;;
    esac
    shift
done

manifest_dir=$(realpath "${0}")
manifest_dir=$(dirname "${manifest_dir}")
manifest_dir=$(realpath "${manifest_dir}/../")/manifests
dest_dir="$(mktemp -d)"
trap 'echo "Cleaning up ..."; docker rm -f widdershins >/dev/null; docker rm -f yq-swagger >/dev/null; rm -rf "${dest_dir}"' EXIT

mkdir -p "${dest_dir}"
echo "Cloning ${docs_csm_branch} branch of docs-csm ..."
if [ -z "${GITHUB_APP_INST_TOKEN}" ]; then
    git clone -q --branch "${docs_csm_branch}" git@github.com:Cray-HPE/docs-csm.git "${dest_dir}/docs-csm"
else
    bash_settings="$-"
    # Avoid token exposure in tracing log
    set +x
    # If tag protection is enabled on the repo, tag can not be pushed using deploy key (via ssh protocol). Application with
    # elevated permission to create protected tag is needed. Application can only authenticate for git access with installation token via https:
    # https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/authenticating-as-a-github-app-installation
    git clone -q --branch "${docs_csm_branch}"  "https://x-access-token:${GITHUB_APP_INST_TOKEN}@github.com/Cray-HPE/docs-csm.git" "${dest_dir}/docs-csm"
    if echo "${bash_settings}" | grep -q x; then
        set -x
    fi
fi
mkdir -p "${dest_dir}/api"
rm -rf "${dest_dir}/docs-csm/api"
mkdir -p "${dest_dir}/docs-csm/api"

echo "Preparing yq container ..."
docker run -u "$(id -u):$(id -g)" --rm --name yq-swagger --entrypoint sh --detach -i -v "${dest_dir}/api:${dest_dir}/api" -v "${manifest_dir}":"${manifest_dir}" artifactory.algol60.net/docker.io/mikefarah/yq:4 >/dev/null
yq="docker exec yq-swagger yq"

echo "Preparing widdershins container ..."
docker run --rm --name widdershins --entrypoint bash --detach -i -v "${dest_dir}:${dest_dir}" node:16 >/dev/null
docker exec widdershins npm install -g widdershins
widdershins="docker exec widdershins widdershins"

find "${manifest_dir}" -name "*.yaml" | while read -r manifest_file; do
    echo "Parsing ${manifest_file} ..."
    ${yq} e '.spec.charts[].swagger[] | (.name + "|" + .url + "|" + (.version // "") + "|" + (.title // ""))' "${manifest_file}" | while read -r swagger_def; do
        IFS='|' read -r endpoint_name endpoint_url endpoint_version endpoint_title <<< "${swagger_def}"
        echo "Downloading from ${endpoint_url} ..."
        curl -SsL -o "${dest_dir}/api/${endpoint_name}.yaml" "${endpoint_url}"
        if [ -n "${endpoint_title}" ]; then
            ${yq} e -i ".info.title=\"${endpoint_title}\"" "${dest_dir}/api/${endpoint_name}.yaml"
        fi
        if [ -n "${endpoint_version}" ]; then
            ${yq} e -i ".info.version=\"${endpoint_version}\"" "${dest_dir}/api/${endpoint_name}.yaml"
        fi
        echo "Producing markdown for ${endpoint_name} out of ${endpoint_url} ..."
        ${widdershins} "${dest_dir}/api/${endpoint_name}.yaml" -o "${dest_dir}/docs-csm/api/${endpoint_name}.md" --omitHeader --language_tabs http shell python go
    done
done

cd "${dest_dir}/docs-csm/api"
echo "# REST API Documentation" > README.md
for file in *.md; do
    if [ "${file}" != README.md ]; then
        title=$(cat "${file}" | grep -E '<h1 id=".*">.*</h1>' | head -1 | sed -e 's/<h1 id=".*">//' | sed -e 's|</h1>||') || true
        if [ -z "${title}" ]; then
            error "Could not determine title for service named ${file%.md}"
        fi
        echo " * [${title}](./${file})" >> README.md
    fi
done
ln -sf ./README.md ./index.md

cd "${dest_dir}/docs-csm"
git add .
if [ -z "$(git status --porcelain)" ]; then
    echo "No changes to existing API documentation."
    if [ -z "$(git tag --points-at HEAD)" ]; then
        if [ "${push}" == "1" ]; then
            increment_push_tag "${wait}"
        else
            echo "Head of docs-csm branch ${docs_csm_branch} is not tagged (re-run with --push to create and push new tag)."
        fi
    else
        echo "Head of docs-csm branch ${docs_csm_branch} is already tagged."
    fi
elif [ "${push}" != "1" ]; then
    echo "The following changes are proposed for docs-csm repo (re-run with --push to commit and generate release tag):"
    git status
else
    git commit -m "Automated API docs swagger to md conversion"
    echo "Pushing branch ${docs_csm_branch} of docs-csm ..."
    git push -q origin "${docs_csm_branch}"
    increment_push_tag "${wait}"
fi