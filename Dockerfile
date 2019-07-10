FROM docker.io/centos:centos7

RUN yum update -y \
 && yum clean all

COPY ./get-resource.sh /usr/local/bin/get-resource.sh


