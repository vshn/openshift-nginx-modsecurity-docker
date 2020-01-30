
# Build the base modsecurity library and the nginx connector
FROM centos/s2i-core-centos7 as build

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
    make -j4 && \
    make install && \
    cd ..

# When updating the nginx version here you will also
# need to update the FROM centos/nginx-114-centos7 tag
ENV NAME=nginx \
    NGINX_VERSION=1.14 \
    NGINX_SHORT_VER=114

# Install the SC provided nginx so we can check the upstream version
RUN yum install -y yum-utils wget gettext hostname && \
    yum install -y centos-release-scl-rh && \
    yum install -y --setopt=tsflags=nodocs rh-nginx${NGINX_SHORT_VER}-nginx

RUN git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git

RUN version=$(echo `/opt/rh/rh-nginx${NGINX_SHORT_VER}/root/usr/sbin/nginx -v 2>&1` | cut -d '/' -f 2) && \
    wget http://nginx.org/download/nginx-$version.tar.gz && \
    tar -xvzf nginx-$version.tar.gz && \
    cd nginx-$version && \
    ./configure --with-compat --add-dynamic-module=../ModSecurity-nginx && \
    make modules && \
    mkdir -p /etc/nginx/modules && \
    cp objs/ngx_http_modsecurity_module.so /etc/nginx/modules

RUN yum -y clean all --enablerepo='*'

# Final image
FROM centos/nginx-114-centos7
COPY --from=build /etc/nginx/modules/ngx_http_modsecurity_module.so /etc/nginx/modules/ngx_http_modsecurity_module.so

# forward request and error logs to docker log collector
RUN  ln -sf /dev/stdout /var/log/nginx/access.log  && \
    ln -sf /dev/stderr /var/log/nginx/error.log

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
