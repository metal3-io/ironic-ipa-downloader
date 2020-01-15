FROM docker.io/centos:centos8

RUN dnf update -y && \
    dnf clean all && \
    rm -rf /var/cache/{yum,dnf}/*

COPY ./get-resource.sh /usr/local/bin/get-resource.sh
