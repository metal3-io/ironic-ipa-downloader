ARG BASE_IMAGE=quay.io/centos/centos:stream9

FROM $BASE_IMAGE

RUN dnf upgrade -y && \
    dnf clean all && \
    rm -rf /var/cache/{yum,dnf}/*

COPY ./get-resource.sh /usr/local/bin/get-resource.sh

ENTRYPOINT /usr/local/bin/get-resource.sh
