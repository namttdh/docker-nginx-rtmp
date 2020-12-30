ARG NGINX_VERSION=1.18.0
ARG NGINX_RTMP_VERSION=1.2.1
ARG FFMPEG_VERSION=4.3.1
ARG PCRE_VERSION=8.44
ARG ZLIB_VERSION=1.2.11
ARG OPENSSL_VERSION=1.1.1g


##############################
# Build the NGINX-build image.
FROM alpine:3.12 as build-nginx

# Build dependencies.
RUN apk add --no-cache --virtual .build-deps \
  gcc \
  libc-dev \
  make \
  openssl-dev \
  pcre-dev \
  zlib-dev \
  linux-headers \
  libxslt-dev \
  gd-dev \
  geoip-dev \
  perl-dev \
  libedit-dev \
  mercurial \
  bash \
  alpine-sdk \
  findutils

WORKDIR tmp

# Get nginx source.
RUN wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
  tar zxf nginx-${NGINX_VERSION}.tar.gz 

# Get custom module.
RUN wget https://github.com/arut/nginx-rtmp-module/archive/v${NGINX_RTMP_VERSION}.tar.gz && \
  tar zxf v${NGINX_RTMP_VERSION}.tar.gz

RUN wget https://ftp.pcre.org/pub/pcre/pcre-${PCRE_VERSION}.tar.gz \ 
  tar zxf pcre-${PCRE_VERSION}.tar.gz

RUN wget https://www.zlib.net/zlib-${PCRE_VERSION}.tar.gz \ 
  tar zxf zlib-${PCRE_VERSION}.tar.gz

RUN wget https://www.openssl.org/source/openssl-${PCRE_VERSION}.tar.gz \
  tar zxf openssl-${PCRE_VERSION}.tar.gz

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
   --with-zlib=../zlib-${PCRE_VERSION} \
   --with-openssl=../openssl-${PCRE_VERSION} \
   --with-openssl-opt=no-nextprotoneg \
   --add-module=../nginx-rtmp-module

###############################
# Build the FFmpeg-build image.
FROM alpine:3.12 as build-ffmpeg
ARG FFMPEG_VERSION
ARG PREFIX=/usr/local
ARG MAKEFLAGS="-j4"

# FFmpeg build dependencies.
RUN build-base \
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
RUN cd /ffmpeg-${FFMPEG_VERSION} && \
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
  make && make install

##########################
# Build the release image.
FROM alpine:3.12
LABEL MAINTAINER Nam Nguyen <nam@lerni.dev>

# Set default ports.
ENV HTTP_PORT 80
ENV HTTPS_PORT 443
ENV RTMP_PORT 1935

RUN apk add --no-cache --virtual .build-deps \
  gcc \
  libc-dev \
  make \
  openssl-dev \
  pcre-dev \
  zlib-dev \
  linux-headers \
  libxslt-dev \
  gd-dev \
  geoip-dev \
  perl-dev \
  libedit-dev \
  mercurial \
  bash \
  alpine-sdk \
  findutils

COPY --from=build-nginx /usr/lib/nginx /usr/lib/nginx
COPY --from=build-nginx /etc/nginx /etc/nginx
COPY --from=build-ffmpeg /usr/local /usr/local
COPY --from=build-ffmpeg /usr/lib/libfdk-aac.so.2 /usr/lib/libfdk-aac.so.2

## Add NGINX path, config and static files.
#ENV PATH "${PATH}:/usr/local/nginx/sbin"
#ADD nginx.conf /etc/nginx/nginx.conf.template
#RUN mkdir -p /opt/data && mkdir /www
#ADD static /www/static
#
#EXPOSE 1935
#EXPOSE 80
#
#CMD envsubst "$(env | sed -e 's/=.*//' -e 's/^/\$/g')" < \
#  /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf && \
#  nginx
