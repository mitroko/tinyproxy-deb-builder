FROM ubuntu:16.04

COPY build.sh /root/
RUN /root/build.sh
