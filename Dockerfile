FROM ubuntu:22.04

RUN apt-get update && apt-get install -y gnupg gnupg1 gnupg2 curl vsftpd jq

RUN echo "deb https://packages.cloud.google.com/apt gcsfuse-jammy main" > /etc/apt/sources.list.d/gcsfuse.list
RUN cat /etc/apt/sources.list.d/gcsfuse.list
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

RUN apt-get update && apt-get install -y gcsfuse

COPY vsftpd.conf /etc
COPY main.sh /

ENTRYPOINT /main.sh