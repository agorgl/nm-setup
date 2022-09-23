#!/bin/bash
set -e

# Arguments
TOKEN=$1

# Fetch api server certificate
CERT_FILE=/tmp/nm-${SERVER%:*}.pem
SERVER=$(echo $TOKEN | base64 -d | jq -r .apiconnstring)
openssl s_client -showcerts -connect $SERVER </dev/null 2>/dev/null | openssl x509 -outform PEM > $CERT_FILE

# Launch netclient
podman run -d --name netclient-$(openssl rand -hex 4) \
    -v $CERT_FILE:/selfsigned.pem \
    -e SSL_CERT_FILE=/selfsigned.pem \
    -e TOKEN=$TOKEN \
    --cap-add NET_ADMIN \
    --cap-add NET_RAW \
    --cap-add SYS_MODULE \
    --sysctl net.ipv4.ip_forward=1 \
    --sysctl net.ipv4.conf.all.src_valid_mark=1 \
    --sysctl net.ipv6.conf.all.disable_ipv6=0 \
    --sysctl net.ipv6.conf.all.forwarding=1 \
    gravitl/netclient:latest
