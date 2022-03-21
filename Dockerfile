FROM quay.io/centos/centos:stream9

RUN dnf upgrade -y && \
    dnf clean all && \
    rm -rf /var/cache/{yum,dnf}/*

COPY ./get-resource.sh /usr/local/bin/get-resource.sh
