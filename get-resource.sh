#!/bin/bash -xe
#CACHEURL=http://172.22.0.1/images

# Which image should we use
SNAP=${1:-current-tripleo-rdo}

FILENAME=ironic-python-agent
FILENAME_EXT=.tar
FFILENAME=$FILENAME$FILENAME_EXT

TMPDIR=$(mktemp -d)

mkdir -p /shared/html/images
cd /shared/html/images

# If we have a CACHEURL and nothing has yet been downloaded
# get header info from the cache
ls -l
if [ -n "$CACHEURL" -a ! -e $FFILENAME.headers ] ; then
    curl --fail -O "$CACHEURL/$FFILENAME.headers"
fi

# Download the most recent version of IPA
if [ -e $FFILENAME.headers ] ; then
    ETAG=$(awk '/ETag:/ {print $2}' $FFILENAME.headers | tr -d "\r")
    cd $TMPDIR
    curl --dump-header $FFILENAME.headers -O https://images.rdoproject.org/stein/rdo_trunk/$SNAP/$FFILENAME --header "If-None-Match: $ETAG"
    # curl didn't download anything because we have the ETag already
    # but we don't have it in the images directory
    # Its in the cache, go get it
    ETAG=$(awk '/ETag:/ {print $2}' $FFILENAME.headers | tr -d "\"\r")
    if [ ! -s $FFILENAME -a ! -e /shared/html/images/$FILENAME-$ETAG/$FFILENAME ] ; then
        mv /shared/html/images/$FFILENAME.headers .
        curl -O "$CACHEURL/$FILENAME-$ETAG/$FFILENAME"
    fi
else
    cd $TMPDIR
    curl --dump-header $FFILENAME.headers -O https://images.rdoproject.org/stein/rdo_trunk/$SNAP/$FFILENAME
fi

if [ -s $FFILENAME ] ; then
    tar -xf $FFILENAME

    ETAG=$(awk '/ETag:/ {print $2}' $FFILENAME.headers | tr -d "\"\r")
    cd -
    chmod 755 $TMPDIR
    mv $TMPDIR $FILENAME-$ETAG
    ln -sf $FILENAME-$ETAG/$FFILENAME.headers $FFILENAME.headers
    ln -sf $FILENAME-$ETAG/$FILENAME.initramfs $FILENAME.initramfs
    ln -sf $FILENAME-$ETAG/$FILENAME.kernel $FILENAME.kernel
else
    rm -rf $TMPDIR
fi
