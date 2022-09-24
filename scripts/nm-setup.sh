#!/bin/bash
set -e

# Arguments
DOMAIN=$1
SERVER_PORT=${2:-8081}
BROKER_PORT=${3:-8883}
DASHBOARD_PORT=${4:-8080}

# Directory containing volume data
[ "${EUID:-$(id -u)}" -eq 0 ] \
    && NMDIR=/var/lib/netmaker \
    || NMDIR=$HOME/.local/share/netmaker

# Create state directory if not exists
[ ! -d $NMDIR ] && mkdir -p $NMDIR

# Create empty pod
echo "Creating netmaker pod ..."
podman pod create -n netmaker \
    -p $SERVER_PORT:8443 \
    -p $BROKER_PORT:8883 \
    -p $DASHBOARD_PORT:8080 \
    -p 51821-51830:51821-51830/udp

#
# Server
#

# Launch server
echo "Creating netmaker-server container ..."
podman run -d --pod netmaker --name netmaker-server \
    -v netmaker-data:/root/data \
    -v netmaker-certs:/etc/netmaker \
    -e SERVER_NAME=broker.$DOMAIN \
    -e SERVER_API_CONN_STRING=api.$DOMAIN:$SERVER_PORT \
    -e MASTER_KEY=TODO_REPLACE_MASTER_KEY \
    -e DATABASE=sqlite \
    -e NODE_ID=netmaker-server \
    -e MQ_HOST=localhost \
    -e MQ_PORT=$BROKER_PORT \
    -e TELEMETRY=off \
    -e VERBOSITY="3" \
    --cap-add NET_ADMIN \
    --cap-add NET_RAW \
    --cap-add SYS_MODULE \
    --sysctl net.ipv4.ip_forward=1 \
    --sysctl net.ipv4.conf.all.src_valid_mark=1 \
    --sysctl net.ipv6.conf.all.disable_ipv6=0 \
    --sysctl net.ipv6.conf.all.forwarding=1 \
    --restart unless-stopped \
    gravitl/netmaker:latest

#
# Broker
#

# Prepare broker configuration
[ ! -f $NMDIR/mosquitto.conf ] && cat << EOF > $NMDIR/mosquitto.conf
per_listener_settings true

listener 8883
allow_anonymous false
require_certificate true
use_identity_as_username true
cafile /mosquitto/certs/root.pem
certfile /mosquitto/certs/server.pem
keyfile /mosquitto/certs/server.key

listener 1883
allow_anonymous true
EOF

# Launch broker
echo "Creating netmaker-mq container ..."
podman run -d --pod netmaker --name netmaker-mq \
    -v $NMDIR/mosquitto.conf:/mosquitto/config/mosquitto.conf \
    -v netmaker-mq-data:/mosquitto/data \
    -v netmaker-mq-logs:/mosquitto/log \
    -v netmaker-certs:/mosquitto/certs \
    --restart unless-stopped \
    eclipse-mosquitto:2.0-openssl

#
# UI
#

# Launch ui
echo "Creating netmaker-ui container ..."
podman run -d --pod netmaker --name netmaker-ui \
    -e BACKEND_URL=https://api.$DOMAIN:$SERVER_PORT \
    --restart unless-stopped \
    gravitl/netmaker-ui:latest

#
# Reverse Proxy
#

# Prepare reverse proxy certificates
if [ ! -f $NMDIR/selfsigned.key ]; then
    echo "Creating netmaker-proxy tls certificates ..."
    openssl req -x509 \
        -newkey rsa:4096 -sha256 \
        -days 3650 -nodes \
        -keyout $NMDIR/selfsigned.key \
        -out $NMDIR/selfsigned.crt \
        -subj "/CN=$DOMAIN" \
        -addext "subjectAltName=DNS:$DOMAIN,DNS:*.$DOMAIN"
fi

# Prepare reverse proxy configuration
[ ! -f $NMDIR/nginx.conf ] && cat << EOF > $NMDIR/nginx.conf
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log    /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    server {
        listen       8443 ssl;
        server_name api.$DOMAIN;

        #access_log  /var/log/nginx/host.access.log  main;

        ssl_certificate /etc/nginx/ssl/selfsigned.crt;
        ssl_certificate_key /etc/nginx/ssl/selfsigned.key;

        location / {
            proxy_pass   http://127.0.0.1:8081;
        }

        #error_page  404              /404.html;

        # Redirect server error pages to the static page /50x.html
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /usr/share/nginx/html;
        }
    }

    server {
        listen       8080 ssl;
        server_name dashboard.$DOMAIN;

        #access_log  /var/log/nginx/host.access.log  main;

        ssl_certificate /etc/nginx/ssl/selfsigned.crt;
        ssl_certificate_key /etc/nginx/ssl/selfsigned.key;

        location / {
            proxy_pass   http://127.0.0.1:80;
        }

        #error_page  404              /404.html;

        # Redirect server error pages to the static page /50x.html
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /usr/share/nginx/html;
        }
    }
}
EOF

# Launch reverse proxy
echo "Creating netmaker-proxy container ..."
podman run -d --pod netmaker --name netmaker-proxy \
    -v $NMDIR/nginx.conf:/etc/nginx/nginx.conf:ro \
    -v $NMDIR/selfsigned.key:/etc/nginx/ssl/selfsigned.key \
    -v $NMDIR/selfsigned.crt:/etc/nginx/ssl/selfsigned.crt \
    --restart unless-stopped \
    nginx
