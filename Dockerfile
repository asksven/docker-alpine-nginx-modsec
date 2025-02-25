ARG NGINX_VER=1.23.3

FROM nginx:${NGINX_VER}-alpine as build_modsecurity

ARG GEO_DB_RELEASE=2023-03
ARG MODSEC_TAG=v3.0.8
ARG OWASP_TAG=v3.3.4

ARG CLAMD_SERVER=127.0.0.1
ARG CLAMD_PORT=3310
ARG CLAMD_DEBUG_LOG=off

WORKDIR /opt

# Install dependencies; includes dependencies required for compile-time options:
# curl, libxml, pcre, and lmdb and Modsec
RUN echo "Installing Dependencies" && \
    apk add --no-cache --virtual general-dependencies \
    autoconf \
    automake \
    byacc \
    curl-dev \
    flex \
    g++ \
    gcc \
    geoip-dev \
    git \
    libc-dev \
    libmaxminddb-dev \
    libstdc++ \
    libtool \
    libxml2-dev \
    linux-headers \
    lmdb-dev \
    make \
    openssl-dev \
    pcre-dev \
    yajl-dev \
    zlib-dev


# Clone and compile modsecurity. Binary will be located in /usr/local/modsecurity
RUN echo "Installing ModSec Library" && \
    git clone -b ${MODSEC_TAG} --depth 1 https://github.com/SpiderLabs/ModSecurity && \
    git -C /opt/ModSecurity submodule update --init --recursive && \
    (cd "/opt/ModSecurity" && \
        ./build.sh && \
        ./configure --with-lmdb && \
        make && \
        make install \
    ) && \
    rm -fr /opt/ModSecurity \
        /usr/local/modsecurity/lib/libmodsecurity.a \
        /usr/local/modsecurity/lib/libmodsecurity.la

# Clone Modsec Nginx Connector, GeoIP, ModSec OWASP Rules, and download/extract nginx and GeoIP databases
RUN echo 'Cloning Modsec Nginx Connector, GeoIP, ModSec OWASP Rules, and download/extract nginx and GeoIP databases' && \
    git clone -b master --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git && \
    git clone -b master --depth 1 https://github.com/leev/ngx_http_geoip2_module.git && \
    git clone -b ${OWASP_TAG} --depth 1 https://github.com/coreruleset/coreruleset.git /usr/local/owasp-modsecurity-crs && \
    wget -O - https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz | tar -xz && \
    mkdir -p /etc/nginx/geoip && \
    wget -O - https://download.db-ip.com/free/dbip-city-lite-${GEO_DB_RELEASE}.mmdb.gz | gzip -d > /etc/nginx/geoip/dbip-city-lite.mmdb && \
    wget -O - https://download.db-ip.com/free/dbip-country-lite-${GEO_DB_RELEASE}.mmdb.gz | gzip -d > /etc/nginx/geoip/dbip-country-lite.mmdb

# Install GeoIP2 and ModSecurity Nginx modules
RUN echo 'Installing Nginx Modules' && \
    (cd "/opt/nginx-$NGINX_VERSION" && \
        ./configure --with-compat \
            --add-dynamic-module=../ModSecurity-nginx \
            --add-dynamic-module=../ngx_http_geoip2_module && \
        make modules \
    ) && \
    cp /opt/nginx-$NGINX_VERSION/objs/ngx_http_modsecurity_module.so \
        /opt/nginx-$NGINX_VERSION/objs/ngx_http_geoip2_module.so \
        /usr/lib/nginx/modules/ && \
    rm -fr /opt/* && \
    apk del general-dependencies


FROM nginx:${NGINX_VER}-alpine

LABEL maintainer="Andrew Kimball"

# Copy nginx, owasp-modsecurity-crs, and modsecurity from the build image
COPY --from=build_modsecurity /etc/nginx/ /etc/nginx/
COPY --from=build_modsecurity /usr/local/modsecurity /usr/local/modsecurity
COPY --from=build_modsecurity /usr/local/owasp-modsecurity-crs /usr/local/owasp-modsecurity-crs
COPY --from=build_modsecurity /usr/lib/nginx/modules/ /usr/lib/nginx/modules/

# Copy local config files into the image
COPY errors /usr/share/nginx/errors
COPY conf/nginx/ /etc/nginx/
COPY conf/modsec/ /etc/nginx/modsec/
COPY conf/owasp/ /usr/local/owasp-modsecurity-crs/
COPY clamd.conf /etc/clamav/
COPY clamdscan.pl /usr/local/owasp-modsecurity-crs/util/av-scanning/
#COPY entrypoint.sh /

RUN apk add --no-cache \
    curl-dev \
    libmaxminddb-dev \
    libstdc++ \
    libxml2-dev \
    lmdb-dev \
    tzdata \
    yajl \
    clamav-clamdscan \
    perl && \
    chown -R nginx:nginx /usr/share/nginx

#     clamav \
#     clamav-libunrar && \

WORKDIR /usr/share/nginx/html

EXPOSE 80 443

#ENTRYPOINT [ "/entrypoint.sh" ]
