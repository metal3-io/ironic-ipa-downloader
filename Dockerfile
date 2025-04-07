ARG BASE_IMAGE=quay.io/centos/centos:stream9

FROM $BASE_IMAGE

# image.version is set during image build by automation
LABEL org.opencontainers.image.authors="metal3-dev@googlegroups.com"
LABEL org.opencontainers.image.description="Container image to download Ironic Python Agent (IPA) as part of Metal³"
LABEL org.opencontainers.image.documentation="https://book.metal3.io/ironic/ironic-container-images"
LABEL org.opencontainers.image.licenses="Apache License 2.0"
LABEL org.opencontainers.image.title="Metal3 Ironic Python Agent Downloader"
LABEL org.opencontainers.image.url="https://github.com/metal3-io/ironic-ipa-downloader"
LABEL org.opencontainers.image.vendor="Metal3-io"

RUN dnf upgrade -y && \
    dnf clean all && \
    rm -rf /var/cache/{yum,dnf}/*

COPY ./get-resource.sh /usr/local/bin/get-resource.sh

ENTRYPOINT /usr/local/bin/get-resource.sh
