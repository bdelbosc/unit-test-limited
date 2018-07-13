#
# Java 1.8 & Maven Dockerfile adapted from
#
# https://github.com/jamesdbloom/docker_java8_maven
#

FROM openjdk:8-jdk

ARG MAVEN_VERSION=3.5.4
ARG USER_HOME_DIR="/root"
ARG SHA=ce50b1c91364cb77efe3776f756a6d92b76d9038b0a0782f7d53acf1e997a14d
ARG BASE_URL=https://apache.osuosl.org/maven/maven-3/${MAVEN_VERSION}/binaries

# maintainer details
MAINTAINER Benoit Delbosc "bdelbosc@gmail.com"

# update packages and install maven
RUN  \
  export DEBIAN_FRONTEND=noninteractive \
  && sed -i 's/# \(.*multiverse$\)/\1/g' /etc/apt/sources.list \
  && apt-get update \
  && apt-get -y upgrade \
  && apt-get install -y vim wget curl git less tree \
  && mkdir -p /usr/share/maven /usr/share/maven/ref \
  && curl -fsSL -o /tmp/apache-maven.tar.gz ${BASE_URL}/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
  && echo "${SHA}  /tmp/apache-maven.tar.gz" | sha256sum -c - \
  && tar -xzf /tmp/apache-maven.tar.gz -C /usr/share/maven --strip-components=1 \
  && rm -f /tmp/apache-maven.tar.gz \
  && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn


ENV MAVEN_HOME /usr/share/maven
ENV MAVEN_CONFIG "$USER_HOME_DIR/.m2"

# attach volumes
VOLUME /volume/git
VOLUME /root/.m2
VOLUME /volume/slow

WORKDIR /volume/git

# run terminal
CMD ["/bin/bash"]

