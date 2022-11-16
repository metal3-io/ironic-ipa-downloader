#!/bin/bash
#CACHEURL=http://172.22.0.1/images

set -eux

# Check and set http(s)_proxy. Required for cURL to use a proxy
export http_proxy="${http_proxy:-${HTTP_PROXY:-}}"
export https_proxy="${https_proxy:-${HTTPS_PROXY:-}}"
export no_proxy="${no_proxy:-${NO_PROXY:-}}"

# configurable variables
SHARED_DIR="${SHARED_DIR:-/shared}"
CURL_OUTPUT=""
if [ "${CURL_VERBOSE:-}" = true ]; then
    CURL_OUTPUT="--verbose"
fi

# Which image should we use
SNAP="${1:-current-tripleo}"
IPA_BASEURI="${IPA_BASEURI:-https://images.rdoproject.org/centos9/master/rdo_trunk/${SNAP}}"

FILENAME="ironic-python-agent"
FILENAME_EXT=".tar"
FFILENAME="${FILENAME}${FILENAME_EXT}"

mkdir -p "${SHARED_DIR}"/html/images "${SHARED_DIR}"/tmp
cd "${SHARED_DIR}"/html/images

TMPDIR="$(mktemp -d -p "${SHARED_DIR}"/tmp)"

# If we have a CACHEURL and nothing has yet been downloaded
# get header info from the cache

if [ -n "${CACHEURL:-}" ] && [ ! -e "${FFILENAME}.headers" ]; then
    curl -g ${CURL_OUTPUT} --fail -O "${CACHEURL}/${FFILENAME}.headers" || true
fi

# Download the most recent version of IPA
if [ -r "${FFILENAME}.headers" ] ; then
    ETAG="$(awk '/ETag:/ {print $2}' ${FFILENAME}.headers | tr -d "\r")"
    cd "${TMPDIR}"
    curl -g ${CURL_OUTPUT} --dump-header "${FFILENAME}.headers" \
        -O "${IPA_BASEURI}/${FFILENAME}" \
        --header "If-None-Match: ${ETAG}" || cp "${SHARED_DIR}/html/images/${FFILENAME}.headers" .

    # curl didn't download anything because we have the ETag already
    # but we don't have it in the images directory
    # Its in the cache, go get it
    ETAG="$(awk '/ETag:/ {print $2}' ${FFILENAME}.headers | tr -d "\"\r")"
    if [ ! -s ${FFILENAME} ] && [ ! -e "${SHARED_DIR}/html/images/${FILENAME}-${ETAG}/${FFILENAME}" ]; then
        mv "${SHARED_DIR}/html/images/${FFILENAME}.headers" .
        curl -g ${CURL_OUTPUT} -O "${CACHEURL}/${FILENAME}-${ETAG}/${FFILENAME}"
    fi
else
    cd "${TMPDIR}"
    curl -g ${CURL_OUTPUT} --dump-header "${FFILENAME}.headers" -O "${IPA_BASEURI}/${FFILENAME}"
fi

if [ -s "${FFILENAME}" ]; then
    tar -xf "${FFILENAME}"

    ETAG="$(awk '/ETag:/ {print $2}' "${FFILENAME}.headers" | tr -d "\"\r")"
    cd -
    chmod 755 "${TMPDIR}"
    mv "${TMPDIR}" "${FILENAME}-${ETAG}"
    ln -sf "${FILENAME}-${ETAG}/${FFILENAME}.headers" "${FFILENAME}.headers"
    ln -sf "${FILENAME}-${ETAG}/${FILENAME}.initramfs" "${FILENAME}.initramfs"
    ln -sf "${FILENAME}-${ETAG}/${FILENAME}.kernel" "${FILENAME}.kernel"
else
    rm -rf "${TMPDIR}"
fi
