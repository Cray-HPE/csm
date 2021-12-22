#!/bin/sh

# NOTE: Portable shell functions uname_os and uname_arch were taken from
# https://github.com/client9/shlib under a public domain license.

set -eo pipefail

# Defaults
: "${BINDIR:="./bin"}"

: "${GRYPE_TAG:="latest"}"
: "${HELM_TAG:="v3.7.2"}"
: "${JQ_TAG:="jq-1.6"}"
: "${SNYK_TAG:="latest"}"
: "${TRIVY_TAG:="latest"}"
: "${YQ_TAG:="3.4.1"}"

usage() {
    echo >&2 "usage: ${0##*/} [-d BINDIR] NAME[=TAG]..."
    [ "$*" = "--long" ] && cat >&2 <<EOF

Options:
  -d BINDIR               Installs tools to BINDIR directory (default: ${BINDIR})

Available tools with default tags:

  grype[=${GRYPE_TAG}]

    Grype is a vulnerability scanner for container images and filesystems. See
    https://github.com/anchore/grype.

  helm[=${HELM_TAG}]

    Helm is the package manager for Kubernetes. See https://helm.sh.

  jq[=${JQ_TAG}]

    jq is a lightweight and flexible command-line JSON processor. See
    https://stedolan.github.io/jq/.

  snyk[=${SNYK_TAG}]

    Snyk scans and monitors software development projects for security
    vulnerabilities. See https://docs.snyk.io/features/snyk-cli.

  trivy[=${TRIVY_TAG}]

    Trivy is a simple and comprehensive scanner for vulnerabilities in
    container images, file systems, and Git repositories, as well as for
    configuration issues. See https://aquasecurity.github.io/trivy/.

  yq[=${YQ_TAG}]

    yq is a lightweight and portable commane-line YAML processor. See
    https://mikefarah.gitbook.io/yq/.

EOF
    exit 2
}

# Converts `uname -s` into standard golang OS types that cover most platforms.
# For a complete list of values supported by golang, run "go tool dist list".
uname_os() {
    os=$(uname -s | tr '[:upper:]' '[:lower:]')

    # Normalize OS value
    case "$os" in
        msys*) os="windows" ;;
        mingw*) os="windows" ;;
        cygwin*) os="windows" ;;
        win*) os="windows" ;; # for windows busybox and like # https://frippery.org/busybox/
    esac

    echo "$os"

    # Check for supported values
    case "$os" in
        darwin) ;;
        dragonfly) ;;
        freebsd) ;;
        linux) ;;
        android) ;;
        nacl) ;;
        netbsd) ;;
        openbsd) ;;
        plan9) ;;
        solaris) ;;
        windows) ;;
        *)
            echo >&2 "error: '$(uname -s)' got converted to '$os' which is not a GOOS value. Please file bug at https://github.com/client9/shlib"
            return 1
            ;;
    esac
}

# Converts `uname -m` into standardized golang OS types.
#
# Notes on ARM:
#   - arm 5,6,7: uname is of form `armv6l`, ` armv7l` where a letter
#     or something else is after the number. Has examples:
#     https://github.com/golang/go/wiki/GoArm
#     https://en.wikipedia.org/wiki/List_of_ARM_microarchitectures
#   - arm 8 is know as arm64, and aarch64
#   - See also https://github.com/golang/go/issues/13669
uname_arch() {
    arch=$(uname -m)

    # Normalize arch value
    case $arch in
        x86_64) arch="amd64" ;;
        x86) arch="386" ;;
        i686) arch="386" ;;
        i386) arch="386" ;;
        aarch64) arch="arm64" ;;
        armv5*) arch="armv5" ;;
        armv6*) arch="armv6" ;;
        armv7*) arch="armv7" ;;
    esac

    echo "${arch}"

    # Check for supported values
    case "$arch" in
        386) ;;
        amd64) ;;
        arm64) ;;
        armv5) ;;
        armv6) ;;
        armv7) ;;
        ppc64) ;;
        ppc64le) ;;
        mips) ;;
        mipsle) ;;
        mips64) ;;
        mips64le) ;;
        s390x) ;;
        amd64p32) ;;
        *)
            echo >&2 "error: '$(uname -m)' got converted to '$arch' which is not a GOARCH value.  Please file bug report at https://github.com/client9/shlib"
            return 1
            ;;
    esac
}

install_grype() {
    tag="${1:-"$GRYPE_TAG"}"
    curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh \
    | sed -e 's/cp -fR "${mount_point}\/" \.\//cp -fR "${mount_point}\/." .\//' \
    | sh -s -- -b "$BINDIR" "$tag"
}

install_trivy() {
    tag="${1:-"$TRIVY_TAG"}"
    curl -sSfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
    | sh -s -- -b "$BINDIR" "$tag"
}

install_snyk() {
    tag="${1:-"$SNYK_TAG"}"
    case "$OS" in
        linux)
            if [ -f /etc/alpine-release ]; then
                name="snyk-alpine"
            else
                name="snyk-linux"
            fi
            ;;
        darwin) name="snyk-macos" ;;
        windows) name="snyk-win.exe" ;;
        *)
            echo >&2 "Snyk is not supported on $PLATFORM"
            return 3
            ;;
    esac
    curl -sSfL "https://static.snyk.io/cli/${tag}/${name}" -o "${BINDIR}/snyk"
    chmod +x "${BINDIR}/snyk"
}

install_yq() {
    tag="${1:-"$YQ_TAG"}"
    curl -sSfL "https://github.com/mikefarah/yq/releases/download/${tag}/yq_${OS}_${ARCH}" -o "${BINDIR}/yq"
    chmod +x "${BINDIR}/yq"
}

install_jq() {
    tag="${1:-"$JQ_TAG"}"
    case "$PLATFORM" in
        darwin/amd64) name="jq-osx-amd64" ;;
        linux/amd64) name="jq-linux64" ;;
        linux/i386) name="jq-linux32" ;;
        windows/amd64) name="jq-win64.exe" ;;
        windows/i386) name="jq-win32.exe" ;;
        *)
            echo >&2 "jq is not supported on $PLATFORM"
            return 3
            ;;
    esac
    curl -sSfL "https://github.com/stedolan/jq/releases/download/${tag}/${name}" -o "${BINDIR}/jq"
    chmod +x "${BINDIR}/jq"
}

install_helm() {
    tag="${1:-"$HELM_TAG"}"
    case "$PLATFORM" in
        darwin/amd64) ;;
        darwin/arm64) ;;
        linux/386) ;;
        linux/amd64) ;;
        linux/arm) ;;
        linux/arm64) ;;
        linux/ppc64le) ;;
        linux/s390x) ;;
        windows/amd64) ;;
        *)
            echo >&2 "Helm is not supported on $PLATFORM"
            return 3
            ;;
    esac
    curl -sSfL "https://get.helm.sh/helm-${tag}-${OS}-${ARCH}.tar.gz" | tar -xzf - -O "${OS}-${ARCH}/helm" > "${BINDIR}/helm"
    chmod +x "${BINDIR}/helm"
}


# Parse args
while getopts ":d:h?x" flag; do
    case "$flag" in
        d) BINDIR="$OPTARG" ;;
        h) usage --long ;;
        \?) echo >&2 "${0##*/}: invalid option -- ${OPTARG}"; usage ;;
        :) echo >&2 "${0##*/}: option requires an argument -- ${OPTARG}"; usage;;
        x) set -x ;;
    esac
done
shift $((OPTIND - 1))

# In case '--' ended arg parsing
[ "${1:-}" = "--" ] && shift

# Ensure tool args were given
[ $# -gt 0 ] || set -- grype helm jq snyk trivy yq

OS="$(uname_os)"
ARCH="$(uname_arch)"
PLATFORM="${OS}/${ARCH}"

while [ $# -gt 0 ]; do
    arg="${1}="
    name="${arg%%=*}"
    tag="${arg#*=}"
    tag="${tag%=}"

    if declare -F "install_${name}" > /dev/null; then
        [ -d "$BINDIR" ] || mkdir -p "$BINDIR"
        "install_${name}" "$tag"
    else
        echo >&2 "${0##*/}: invalid tool -- ${name}"
        usage
    fi

    shift
done
