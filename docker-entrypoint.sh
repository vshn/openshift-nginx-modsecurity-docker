#!/bin/sh

function middle_proxy_setup {
cat | envsubst '${ROUTER_PROXY_IN_HTTP_PORT} ${ROUTER_PROXY_OUT_HTTP_PORT}' \
> ${NGINX_CONFIGURATION_PATH}/middle_proxy.conf  << _EOF_
server {
    listen ${ROUTER_PROXY_IN_HTTP_PORT};
    location /nginx-health {
        return 200 "healthy\n";
    }
        location / {
        proxy_pass http://127.0.0.1:${ROUTER_PROXY_OUT_HTTP_PORT}/;
    }
}
_EOF_
}

. /opt/app-root/etc/scl_enable
[[ -n "${ROUTER_PROXY_IN_HTTP_PORT}" ]] && middle_proxy_setup
exec "$@"
