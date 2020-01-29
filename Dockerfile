
FROM centos/s2i-core-centos7 as build

# Build the base modsecurity library
## Install the packages required to build libmodsecurity
RUN INSTALL_PKGS="gcc-c++ flex bison yajl yajl-devel curl-devel curl GeoIP-devel \
    doxygen zlib-devel pcre-devel autoconf automake git curl make libxml2-devel \
    pkgconfig libtool httpd-devel redhat-rpm-config" && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS

RUN git clone --depth 1 https://github.com/SpiderLabs/ModSecurity
RUN cd ModSecurity && \
    git submodule init && \
    git submodule update && \
    ./build.sh && \
    ./configure --prefix=/usr && \
    make && \
    make install && \
    cd ..

ENV NAME=nginx \
    NGINX_VERSION=1.14 \
    NGINX_SHORT_VER=114

# Install the SC provided nginx so we can check the upstream version
RUN yum install -y yum-utils wget gettext hostname && \
    yum install -y centos-release-scl-rh && \
    yum install -y --setopt=tsflags=nodocs rh-nginx${NGINX_SHORT_VER}-nginx

RUN git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git

RUN mkdir -p /etc/nginx/modules
RUN version=$(echo `/opt/rh/rh-nginx114/root/usr/sbin/nginx -v 2>&1` | cut -d '/' -f 2) && \
    wget http://nginx.org/download/nginx-$version.tar.gz && \
    tar -xvzf nginx-$version.tar.gz && \
    cd nginx-$version && \
    ./configure --with-compat --add-dynamic-module=../ModSecurity-nginx && \
    make modules && \
    cp objs/ngx_http_modsecurity_module.so /etc/nginx/modules

RUN yum -y clean all --enablerepo='*'

# Final image
FROM centos/nginx-114-centos7
COPY --from=build /etc/nginx/modules/ngx_http_modsecurity_module.so /etc/nginx/modules
CMD ["nginx", "-g", "daemon off;"]
