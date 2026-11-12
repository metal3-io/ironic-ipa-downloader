#!/bin/bash
#CACHEURL=http://172.22.0.1/images

set -eux

# Check and set http(s)_proxy. Required for cURL to use a proxy
export http_proxy="${http_proxy:-${HTTP_PROXY:-}}"
export https_proxy="${https_proxy:-${HTTPS_PROXY:-}}"
export no_proxy="${no_proxy:-${NO_PROXY:-}}"

# configurable variables
SHARED_DIR="${SHARED_DIR:-/shared}"
REQUIRE_SHA256="${REQUIRE_SHA256:-true}"
case "${REQUIRE_SHA256}" in
    true | false) ;;
    *)
        echo "REQUIRE_SHA256 must be true or false, got: '${REQUIRE_SHA256}'" >&2
        exit 2
        ;;
esac

# Transfer resilience. A stalled or pathologically slow archive must fail fast
# and visibly rather than hang the init container for hours: curl aborts when the
# average transfer speed stays below CURL_SPEED_LIMIT bytes/s for CURL_SPEED_TIME
# seconds, then retries CURL_RETRY times before giving up. Set CURL_SPEED_LIMIT=0
# to disable the speed floor.
CURL_CONNECT_TIMEOUT="${CURL_CONNECT_TIMEOUT:-30}"
CURL_SPEED_LIMIT="${CURL_SPEED_LIMIT:-102400}"
CURL_SPEED_TIME="${CURL_SPEED_TIME:-120}"
CURL_RETRY="${CURL_RETRY:-3}"
CURL_RETRY_DELAY="${CURL_RETRY_DELAY:-5}"

# Validate the tunables before handing them to curl: they come from the
# container environment and are interpolated into a command line.
require_non_negative_int() {
    local name="$1"
    local value="$2"

    case "${value}" in
        '' | *[!0-9]*)
            echo "${name} must be a non-negative integer, got: '${value}'" >&2
            exit 2
            ;;
    esac
}

require_non_negative_int CURL_CONNECT_TIMEOUT "${CURL_CONNECT_TIMEOUT}"
require_non_negative_int CURL_SPEED_LIMIT "${CURL_SPEED_LIMIT}"
require_non_negative_int CURL_SPEED_TIME "${CURL_SPEED_TIME}"
require_non_negative_int CURL_RETRY "${CURL_RETRY}"
require_non_negative_int CURL_RETRY_DELAY "${CURL_RETRY_DELAY}"

curl_with_flags() {
    set -- --connect-timeout "${CURL_CONNECT_TIMEOUT}" \
        --retry "${CURL_RETRY}" \
        --retry-delay "${CURL_RETRY_DELAY}" \
        --retry-connrefused \
        "$@"

    if [ "${CURL_SPEED_LIMIT}" -gt 0 ]; then
        set -- --speed-limit "${CURL_SPEED_LIMIT}" \
            --speed-time "${CURL_SPEED_TIME}" \
            "$@"
    fi

    if [ "${CURL_VERBOSE:-}" = true ]; then
        set -- --verbose "$@"
    fi
    if  [ "${CURL_INSECURE:-}" = true ]; then
        set -- --insecure --proxy-insecure "$@"
    fi
    if [ -n "${WEBSERVER_CACERT_FILE:-}" ]; then
        if [ ! -f "${WEBSERVER_CACERT_FILE}" ] || [ ! -r "${WEBSERVER_CACERT_FILE}" ]; then
            echo "WEBSERVER_CACERT_FILE must point to a readable CA bundle file: ${WEBSERVER_CACERT_FILE}" >&2
            return 2
        fi
        set -- --cacert "${WEBSERVER_CACERT_FILE}" --proxy-cacert "${WEBSERVER_CACERT_FILE}" "$@"
    fi
    curl "$@"
}

EXTENSIONS=${EXTENSIONS:-".tar.gz .tar.gz.sha256"}

get_filename_without_extension() {
	local filename=$1
	local filename_without_extension="${filename%.*.*}"

	for ex in ${EXTENSIONS}; do
		bname=$(basename "${filename}" "${ex}")
		if [ "${filename:${#bname}}" = "${ex}" ]; then
			filename_without_extension="${bname}"
			break
		fi
	done

	echo -n "${filename_without_extension}"
}

# Which image should we use
IPA_BASEURI="${IPA_BASEURI:-https://tarballs.opendev.org/openstack/ironic-python-agent/dib}"
IPA_BRANCH="$(echo "${IPA_BRANCH:-master}" | tr / -)"
IPA_FLAVOR="${IPA_FLAVOR:-centos9}"
IPA_ARCH="${IPA_ARCH:-}"

FILENAME="${IPA_FILENAME:-ipa-${IPA_FLAVOR}-${IPA_BRANCH}.tar.gz}"
SHA256_FILENAME="${FILENAME}.sha256"
FILENAME_NO_EXT=$(get_filename_without_extension "${FILENAME}")
DESTNAME="ironic-python-agent${IPA_ARCH:+_${IPA_ARCH}}"

mkdir -p "${SHARED_DIR}"/html/images "${SHARED_DIR}"/tmp
cd "${SHARED_DIR}"/html/images

TMPDIR="$(mktemp -d -p "${SHARED_DIR}"/tmp)"

cleanup_tmpdir() {
    if [ -n "${TMPDIR:-}" ] && [ -d "${TMPDIR}" ]; then
        rm -rf -- "${TMPDIR}"
    fi
}

trap cleanup_tmpdir EXIT

# If we have a CACHEURL and nothing has yet been downloaded
# get header info from the cache

if [ -n "${CACHEURL:-}" ] && [ ! -e "${FILENAME}.headers" ]; then
    curl_with_flags -g --fail -O "${CACHEURL}/${FILENAME}.headers" || true
fi

# Download the most recent version of IPA
if [ -r "${DESTNAME}.headers" ] ; then
    ETAG="$(awk '/ETag:/ {etag=$2} END {print etag}' "${DESTNAME}.headers" | tr -d "\r")"
    cd "${TMPDIR}"
    curl_with_flags -g --fail --dump-header "${FILENAME}.headers" \
        -O "${IPA_BASEURI}/${FILENAME}" \
        --header "If-None-Match: ${ETAG}" || cp "${SHARED_DIR}/html/images/${FILENAME}.headers" .

    # curl didn't download anything because we have the ETag already
    # but we don't have it in the images directory
    # Its in the cache, go get it
    # NOTE: --dump-header appends the headers of every response in the
    # invocation, so a retried download leaves more than one ETag in the file.
    # Keep only the last one, which belongs to the response we actually used.
    ETAG="$(awk '/ETag:/ {etag=$2} END {print etag}' "${FILENAME}.headers" | tr -d "\"\r")"
    if [ -n "${CACHEURL:-}" ] && [ ! -s "${FILENAME}" ] &&
       [ ! -e "${SHARED_DIR}/html/images/${FILENAME}-${ETAG}/${FILENAME}" ]; then
        mv "${SHARED_DIR}/html/images/${FILENAME}.headers" .
        curl_with_flags -g --fail -O "${CACHEURL}/${FILENAME}-${ETAG}/${FILENAME}"
    fi
else
    cd "${TMPDIR}"
    curl_with_flags -g --fail --dump-header "${FILENAME}.headers" -O "${IPA_BASEURI}/${FILENAME}"
fi

if [ -s "${FILENAME}" ]; then
    if curl_with_flags -g --fail -O "${IPA_BASEURI}/${SHA256_FILENAME}"; then
        # Archives publish either "hash  filename" or a bare hash; field 1 is the hash either way.
        awk -v f="${FILENAME}" '{print $1 "  " f; exit}' "${SHA256_FILENAME}" | sha256sum --check -
    else
        if [ "${REQUIRE_SHA256}" = true ]; then
            echo "ERROR: ${SHA256_FILENAME} not available at ${IPA_BASEURI}; refusing an unverified archive" >&2
            echo "Set REQUIRE_SHA256=false only for a mirror you trust explicitly." >&2
            exit 1
        fi
        echo "WARNING: ${SHA256_FILENAME} not available at ${IPA_BASEURI}, skipping verification" >&2
    fi

    tar -xaf "${FILENAME}"

    ETAG="$(awk '/ETag:/ {etag=$2} END {print etag}' "${FILENAME}.headers" | tr -d "\"\r")"
    cd -
    chmod 755 "${TMPDIR}"
    mv "${TMPDIR}" "${FILENAME}-${ETAG}"
    ln -sf "${FILENAME}-${ETAG}/${FILENAME}.headers" "${DESTNAME}.headers"
    ln -sf "${FILENAME}-${ETAG}/${FILENAME_NO_EXT}.initramfs" "${DESTNAME}.initramfs"
    ln -sf "${FILENAME}-${ETAG}/${FILENAME_NO_EXT}.kernel" "${DESTNAME}.kernel"
fi
