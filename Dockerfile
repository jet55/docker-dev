FROM frolvlad/alpine-oraclejdk8

ENV DOCKER_COMPOSE_VERSION=1.18.0 \
    DOCKER_CHANNEL=stable \
    DOCKER_VERSION=17.12.0-ce \
    MAVEN_VERSION=3.5.2 \
    SHA=707b1f6e390a65bde4af4cdaf2a24d45fc19a6ded00fff02e91626e3e42ceaff \
    MAVEN_HOME=/usr/share/maven \
    MAVEN_CONFIG="/root/.m2"

#### Docker

COPY modprobe.sh /usr/local/bin/modprobe
COPY docker-entrypoint.sh /usr/local/bin/

RUN     chmod +x /usr/local/bin/modprobe /usr/local/bin/docker-entrypoint.sh; \
        apk add --no-cache ca-certificates; \
        \
# set up nsswitch.conf for Go's "netgo" implementation (which Docker explicitly uses)
# - https://github.com/docker/docker-ce/blob/v17.09.0-ce/components/engine/hack/make.sh#L149
# - https://github.com/golang/go/blob/go1.9.1/src/net/conf.go#L194-L275
# - docker run --rm debian:stretch grep '^hosts:' /etc/nsswitch.conf
        if [ ! -f /etc/nsswitch.conf ] ; then echo 'hosts: files dns' > /etc/nsswitch.conf ; fi; \
        \
# TODO ENV DOCKER_SHA256
# https://github.com/docker/docker-ce/blob/5b073ee2cf564edee5adca05eee574142f7627bb/components/packaging/static/hash_files !!
# (no SHA file artifacts on download.docker.com yet as of 2017-06-07 though)
        \
        set -ex; \
# why we use "curl" instead of "wget":
# + wget -O docker.tgz https://download.docker.com/linux/static/stable/x86_64/docker-17.03.1-ce.tgz
# Connecting to download.docker.com (54.230.87.253:443)
# wget: error getting response: Connection reset by peer
        apk add --no-cache --virtual .fetch-deps \
                curl \
                tar \
        ; \
        \
# this "case" statement is generated via "update.sh"
        apkArch="$(apk --print-arch)"; \
        case "$apkArch" in \
                x86_64) dockerArch='x86_64' ;; \
                aarch64) dockerArch='aarch64' ;; \
                ppc64le) dockerArch='ppc64le' ;; \
                s390x) dockerArch='s390x' ;; \
                *) echo >&2 "error: unsupported architecture ($apkArch)"; exit 1 ;;\
        esac; \
        \
        if ! curl -fL -o docker.tgz "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${dockerArch}/docker-${DOCKER_VERSION}.tgz"; then \
                echo >&2 "error: failed to download 'docker-${DOCKER_VERSION}' from '${DOCKER_CHANNEL}' for '${dockerArch}'"; \
                exit 1; \
        fi; \
        \
        tar --extract \
                --file docker.tgz \
                --strip-components 1 \
                --directory /usr/local/bin/ \
        ; \
        rm docker.tgz; \
        \
        apk del .fetch-deps; \
        \
        dockerd -v; \
        docker -v; \
        \
#### Maven
        apk add --no-cache curl tar bash; \
        mkdir -p /usr/share/maven /usr/share/maven/ref \
                && curl -fsSL -o /tmp/apache-maven.tar.gz https://apache.osuosl.org/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz \
                && echo "$SHA  /tmp/apache-maven.tar.gz" | sha256sum -c - \
                && tar -xzf /tmp/apache-maven.tar.gz -C /usr/share/maven --strip-components=1 \
                && rm -f /tmp/apache-maven.tar.gz \
                && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn; \
        \
#### Compose
        curl -L https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose \
                && chmod +x /usr/local/bin/docker-compose

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["sh"]
