FROM alpine:3.14 as guacbuilder

ARG GUACD_VERSION=1.3.0

RUN echo "**** install build deps ****" && \
    apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing \
    ossp-uuid-dev=1.6.2-r1 && \
    apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/v3.13/community \
    freerdp-dev=2.2.0-r0 ffmpeg-dev=4.3.1-r4 && \
    apk add --no-cache \
    cairo-dev libjpeg-turbo-dev libpng-dev \
    openssl-dev  pango-dev pulseaudio-dev \
    libssh2-dev libvncserver-dev libvorbis-dev \	
    libwebp-dev libwebsockets-dev perl \
    cunit-dev autoconf automake \
    alpine-sdk

RUN set -x && \
    echo "**** compile guacamole server ****" && \
    mkdir /buildout && \
    mkdir /tmp/guac && \
    cd /tmp/guac && \
    wget \
    http://apache.org/dyn/closer.cgi?action=download\&filename=guacamole/${GUACD_VERSION}/source/guacamole-server-${GUACD_VERSION}.tar.gz \
    -O guac.tar.gz && \
    tar -xf guac.tar.gz && \
    cd guacamole-server-${GUACD_VERSION} && \
    ./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --mandir=/usr/share/man \
    --localstatedir=/var \
    --disable-static \
    --with-libavcodec \
    --with-libavutil \
    --with-libswscale \
    --with-ssl \
    --without-winsock \
    --with-vorbis \
    --with-pulse \
    --with-pango \
    --with-terminal \
    --with-vnc \
    --with-rdp \
    --with-ssh \
    --without-telnet \
    --with-webp \
    --with-websockets && \
    make && \
    make DESTDIR=/buildout install

FROM alpine:3.14

# Copy build outputs
COPY --from=guacbuilder /buildout /

ARG TARGETARCH
ENV GUAC_VER=1.3.0 \
    OVERLAY_VERSION="v2.2.0.3" \
    GUACAMOLE_HOME=/app/guacamole \
    PGDATA=/config/postgres \
    POSTGRES_USER=guacamole \
    POSTGRES_DB=guacamole_db \
    TOMCAT_MAJOR=9 \
    TOMCAT_VERSION=9.0.54 \
    CATALINA_HOME=/opt/tomcat

# Apply the s6-overlay
RUN apk add curl \
    && if [[ "${TARGETARCH}" = "arm64" ]]; then export ARCH="aarch64" ; else ARCH="${TARGETARCH}"; fi \
    && curl -SL -o /tmp/s6-overlay-${ARCH}-installer "https://github.com/just-containers/s6-overlay/releases/download/${OVERLAY_VERSION}/s6-overlay-${ARCH}-installer" \
    && chmod +x /tmp/s6-overlay-${ARCH}-installer \
    && /tmp/s6-overlay-${ARCH}-installer / \
    && rm /tmp/s6-overlay-${ARCH}-installer 

RUN echo "**** install packages ****" && \
    apk update && apk upgrade && apk add --no-cache \
    cairo font-terminus-nerd \
    glib libcrypto1.1 libjpeg-turbo libpng libpulse libssh2 \
    libssl1.1 libvncserver libwebp libwebsockets \
    pango postgresql openjdk11-jre tzdata && \
    apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing \
    ossp-uuid=1.6.2-r1 && \
    apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/v3.13/community \
    freerdp-libs=2.2.0-r0 ffmpeg-libs=4.3.1-r4

# Install tomcat
RUN set -x \
    && mkdir -p ${GUACAMOLE_HOME} \
    ${GUACAMOLE_HOME}/lib \
    ${GUACAMOLE_HOME}/extensions \
    && curl -jksSL -o /tmp/apache-tomcat.tar.gz http://archive.apache.org/dist/tomcat/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz \
    && tar -xzf /tmp/apache-tomcat.tar.gz -C /opt \
    && ln -s /opt/apache-tomcat-${TOMCAT_VERSION} ${CATALINA_HOME} \
    && rm -rf ${CATALINA_HOME}/webapps/* 

WORKDIR ${GUACAMOLE_HOME}

# Install guacamole-client and postgres auth adapter
RUN set -x \
    && curl -SLo ${CATALINA_HOME}/webapps/guacamole.war "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VER}/binary/guacamole-${GUAC_VER}.war" \
    && curl -SLo ${GUACAMOLE_HOME}/lib/postgresql-42.1.4.jar "https://jdbc.postgresql.org/download/postgresql-42.1.4.jar" \
    && curl -SLO "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VER}/binary/guacamole-auth-jdbc-${GUAC_VER}.tar.gz" \
    && tar -xzf guacamole-auth-jdbc-${GUAC_VER}.tar.gz \
    && cp -R guacamole-auth-jdbc-${GUAC_VER}/postgresql/guacamole-auth-jdbc-postgresql-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions/ \
    && cp -R guacamole-auth-jdbc-${GUAC_VER}/postgresql/schema ${GUACAMOLE_HOME}/ \
    && rm -rf guacamole-auth-jdbc-${GUAC_VER} guacamole-auth-jdbc-${GUAC_VER}.tar.gz 

# Add optional extensions
RUN set -xe \
    && mkdir ${GUACAMOLE_HOME}/extensions-available \
    && for i in auth-ldap auth-duo auth-header auth-cas auth-openid auth-quickconnect auth-totp; do \
    echo "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VER}/binary/guacamole-${i}-${GUAC_VER}.tar.gz" \
    && curl -SLO "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUAC_VER}/binary/guacamole-${i}-${GUAC_VER}.tar.gz" \
    && tar -xzf guacamole-${i}-${GUAC_VER}.tar.gz \
    && cp guacamole-${i}-${GUAC_VER}/guacamole-${i}-${GUAC_VER}.jar ${GUACAMOLE_HOME}/extensions-available/ \
    && rm -rf guacamole-${i}-${GUAC_VER} guacamole-${i}-${GUAC_VER}.tar.gz \
    ;done

# Cleanup
RUN apk del curl \
    && rm -rf /tmp/* /var/lib/apt/lists/*

ENV PATH=${CATALINA_HOME}/bin:$PATH
ENV GUACAMOLE_HOME=/config/guacamole
ENV TZ=Europe/Berlin

WORKDIR /config

COPY root /

EXPOSE 8080

ENTRYPOINT [ "/init" ]