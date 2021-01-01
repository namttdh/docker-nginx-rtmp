ARG NGINX_VERSION=1.19.2
ARG NGINX_RTMP_VERSION=1.2.1
ARG FFMPEG_VERSION=4.3.1
ARG PCRE_VERSION=8.44
ARG ZLIB_VERSION=1.2.11
ARG OPENSSL_VERSION=1.1.1g


##############################
# Build the NGINX-build image.
FROM alpine:3.12 as build-nginx
ARG NGINX_VERSION
ARG NGINX_RTMP_VERSION
ARG FFMPEG_VERSION
ARG PCRE_VERSION
ARG ZLIB_VERSION
ARG OPENSSL_VERSION

# Build dependencies.
RUN apk add \
  gcc libc-dev\
  make \
  findutils \
  mercurial \
  alpine-sdk \
  zlib-dev linux-headers libedit-dev\
  perl perl-dev gd gd-dev geoip geoip-dev libxml2 libxml2-dev libxslt libxslt-dev

WORKDIR tmp

# Get nginx source.
RUN wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
  tar zxf nginx-${NGINX_VERSION}.tar.gz

# Get custom module.
RUN wget https://github.com/arut/nginx-rtmp-module/archive/v${NGINX_RTMP_VERSION}.tar.gz && \
  tar zxf v${NGINX_RTMP_VERSION}.tar.gz

RUN wget https://ftp.pcre.org/pub/pcre/pcre-${PCRE_VERSION}.tar.gz && \
  tar zxf pcre-${PCRE_VERSION}.tar.gz

RUN wget https://www.zlib.net/zlib-${ZLIB_VERSION}.tar.gz && \
  tar zxf zlib-${ZLIB_VERSION}.tar.gz

RUN wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz && \
  tar zxf openssl-${OPENSSL_VERSION}.tar.gz

# Compile nginx with nginx-rtmp module.
RUN cd nginx-${NGINX_VERSION} && \
  ./configure --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --user=nginx \
    --group=nginx \
    --with-select_module \
    --with-poll_module \
    --with-threads \
    --with-file-aio \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_xslt_module=dynamic \
    --with-http_image_filter_module=dynamic \
    --with-http_geoip_module=dynamic \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_auth_request_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_degradation_module \
    --with-http_slice_module \
    --with-http_stub_status_module \
    --with-http_perl_module=dynamic \
    --with-perl_modules_path=/usr/share/perl/5.26.1 \
    --with-perl=/usr/bin/perl \
    --http-log-path=/var/log/nginx/access.log \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --with-mail=dynamic \
    --with-mail_ssl_module \
    --with-stream=dynamic \
    --with-stream_ssl_module \
    --with-stream_realip_module \
    --with-stream_geoip_module=dynamic \
    --with-stream_ssl_preread_module \
    --with-compat \
    --with-pcre=../pcre-${PCRE_VERSION} \
    --with-pcre-jit \
    --with-zlib=../zlib-${ZLIB_VERSION} \
    --with-openssl=../openssl-${OPENSSL_VERSION} \
    --with-openssl-opt=no-nextprotoneg \
    --with-cc-opt=-Wno-error \
    --add-module=../nginx-rtmp-module-${NGINX_RTMP_VERSION} && \
   make && make install

###############################
# Build the FFmpeg-build image.
FROM alpine:3.12 as build-ffmpeg
ARG FFMPEG_VERSION
ARG PREFIX=/usr/local
ARG MAKEFLAGS="-j4"

# FFmpeg build dependencies.
RUN apk add --no-cache --virtual .build-deps \
  build-base \
  coreutils \
  freetype-dev \
  lame-dev \
  libogg-dev \
  libass \
  libass-dev \
  libvpx-dev \
  libvorbis-dev \
  libwebp-dev \
  libtheora-dev \
  openssl-dev \
  opus-dev \
  pkgconf \
  pkgconfig \
  rtmpdump-dev \
  wget \
  x264-dev \
  x265-dev \
  yasm

RUN echo http://dl-cdn.alpinelinux.org/alpine/edge/community >> /etc/apk/repositories
RUN apk add --update fdk-aac-dev

WORKDIR tmp

# Get FFmpeg source.
RUN wget http://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz && \
  tar zxf ffmpeg-${FFMPEG_VERSION}.tar.gz && rm ffmpeg-${FFMPEG_VERSION}.tar.gz

# Compile ffmpeg.
RUN cd ffmpeg-${FFMPEG_VERSION} && \
  ./configure \
  --prefix=${PREFIX} \
  --enable-version3 \
  --enable-gpl \
  --enable-nonfree \
  --enable-small \
  --enable-libmp3lame \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libvpx \
  --enable-libtheora \
  --enable-libvorbis \
  --enable-libopus \
  --enable-libfdk-aac \
  --enable-libass \
  --enable-libwebp \
  --enable-postproc \
  --enable-avresample \
  --enable-libfreetype \
  --enable-openssl \
  --disable-debug \
  --disable-doc \
  --disable-ffplay \
  --extra-libs="-lpthread -lm" && \
  make && make install && make distclean

RUN rm -rf /var/cache/* /tmp/*

##########################
# Build the release image.
FROM alpine:3.12
LABEL MAINTAINER Nam Nguyen <nam@lerni.dev>

# Set default ports.
RUN addgroup -g 101 -S nginx && \
 adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx

COPY --from=build-nginx /etc/nginx /etc/nginx
COPY --from=build-nginx /usr/lib/nginx /usr/lib/nginx
COPY --from=build-nginx /usr/sbin/nginx /usr/sbin/nginx
COPY --from=build-nginx /var/log/nginx /var/log/nginx
COPY --from=build-ffmpeg /usr/local /usr/local
COPY --from=build-ffmpeg /usr/lib/libfdk-aac.so.2 /usr/lib/libfdk-aac.so.2

RUN ln -s /usr/lib/nginx/modules /etc/nginx/modules
RUN mkdir -p /var/cache/nginx/client_temp /var/cache/nginx/fastcgi_temp /var/cache/nginx/proxy_temp /var/cache/nginx/scgi_temp /var/cache/nginx/uwsgi_temp && \
 chmod 700 /var/cache/nginx/* && \
 chown nginx:nginx /var/cache/nginx/* && \
 mkdir /etc/nginx/conf.d && \
 mkdir /etc/nginx/rtmp.d && \
 ln -sf /dev/stdout /var/log/nginx/access.log && \
 ln -sf /dev/stderr /var/log/nginx/error.log && \
 rm /etc/nginx/*.default && \
 mkdir /docker-entrypoint.d

COPY ./docker-entrypoint.sh /
COPY ./docker-entrypoint.d /docker-entrypoint.d

RUN chmod a+x -R ./docker-entrypoint.sh ./docker-entrypoint.d

COPY ./nginx.conf /etc/nginx/nginx.conf
COPY ./conf.d /etc/nginx/conf.d
COPY ./rtmp.d /etc/nginx/rtmp.d
COPY ./metrics /etc/nginx/html

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 80 443 1935

STOPSIGNAL SIGQUIT

CMD ["nginx", "-g", "daemon off;"]
