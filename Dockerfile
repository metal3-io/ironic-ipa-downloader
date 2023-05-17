ARG BASE_IMAGE=quay.io/centos/centos:stream9@sha256:06cfbf69d99f47f45f327d18fec086509ca0c74afdb178fb8c5bc45184454cc0

FROM $BASE_IMAGE

RUN dnf upgrade -y && \
    dnf clean all && \
    rm -rf /var/cache/{yum,dnf}/*

COPY ./get-resource.sh /usr/local/bin/get-resource.sh
