#!/bin/bash
#CACHEURL=http://172.22.0.1/images

set -eux

# Check and set http(s)_proxy. Required for cURL to use a proxy
export http_proxy="${http_proxy:-${HTTP_PROXY:-}}"
export https_proxy="${https_proxy:-${HTTPS_PROXY:-}}"
export no_proxy="${no_proxy:-${NO_PROXY:-}}"

# configurable variables
SHARED_DIR="${SHARED_DIR:-/shared}"

curl_with_flags() {
    if [ "${CURL_VERBOSE:-}" = true ]; then
        set -- --verbose "$@"
    fi
    if  [ "${CURL_INSECURE:-}" = true ]; then
        set -- --insecure "$@"
    fi
    curl "$@"
}

# Which image should we use
IPA_BASEURI="${IPA_BASEURI:-https://tarballs.opendev.org/openstack/ironic-python-agent/dib}"
IPA_BRANCH="$(echo "${IPA_BRANCH:-master}" | tr / -)"
IPA_FLAVOR="${IPA_FLAVOR:-centos9}"

FILENAME="${IPA_FILENAME:-ipa-${IPA_FLAVOR}-${IPA_BRANCH}.tar.gz}"
FILENAME_NO_EXT="${FILENAME%.*.*}"
DESTNAME="ironic-python-agent"

mkdir -p "${SHARED_DIR}"/html/images "${SHARED_DIR}"/tmp
cd "${SHARED_DIR}"/html/images

TMPDIR="$(mktemp -d -p "${SHARED_DIR}"/tmp)"

# If we have a CACHEURL and nothing has yet been downloaded
# get header info from the cache

if [ -n "${CACHEURL:-}" ] && [ ! -e "${FILENAME}.headers" ]; then
    curl_with_flags -g --fail -O "${CACHEURL}/${FILENAME}.headers" || true
fi

# Download the most recent version of IPA
if [ -r "${DESTNAME}.headers" ] ; then
    ETAG="$(awk '/ETag:/ {print $2}' "${DESTNAME}.headers" | tr -d "\r")"
    cd "${TMPDIR}"
    curl_with_flags -g --dump-header "${FILENAME}.headers" \
        -O "${IPA_BASEURI}/${FILENAME}" \
        --header "If-None-Match: ${ETAG}" || cp "${SHARED_DIR}/html/images/${FILENAME}.headers" .

    # curl didn't download anything because we have the ETag already
    # but we don't have it in the images directory
    # Its in the cache, go get it
    ETAG="$(awk '/ETag:/ {print $2}' "${FILENAME}.headers" | tr -d "\"\r")"
    if [ ! -s "${FILENAME}" ] && [ ! -e "${SHARED_DIR}/html/images/${FILENAME_NO_EXT}-${ETAG}/${FILENAME}" ]; then
        mv "${SHARED_DIR}/html/images/${FILENAME}.headers" .
        curl_with_flags -g -O "${CACHEURL}/${FILENAME_NO_EXT}-${ETAG}/${FILENAME}"
    fi
else
    cd "${TMPDIR}"
    curl_with_flags -g --dump-header "${FILENAME}.headers" -O "${IPA_BASEURI}/${FILENAME}"
fi

if [ -s "${FILENAME}" ]; then
    tar -xaf "${FILENAME}"

    ETAG="$(awk '/ETag:/ {print $2}' "${FILENAME}.headers" | tr -d "\"\r")"
    cd -
    chmod 755 "${TMPDIR}"
    mv "${TMPDIR}" "${FILENAME}-${ETAG}"
    ln -sf "${FILENAME}-${ETAG}/${FILENAME}.headers" "${DESTNAME}.headers"
    ln -sf "${FILENAME}-${ETAG}/${FILENAME_NO_EXT}.initramfs" "${DESTNAME}.initramfs"
    ln -sf "${FILENAME}-${ETAG}/${FILENAME_NO_EXT}.kernel" "${DESTNAME}.kernel"
else
    rm -rf "${TMPDIR}"
fi
