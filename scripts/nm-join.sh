#!/bin/bash
set -e

# Arguments
TOKEN=$1

# Fetch api server certificate
CERT_FILE=/tmp/nm-${SERVER%:*}.pem
SERVER=$(echo $TOKEN | base64 -d | jq -r .apiconnstring)
openssl s_client -showcerts -connect $SERVER </dev/null 2>/dev/null | openssl x509 -outform PEM > $CERT_FILE

# Launch netclient
podman run -d --privileged --name netclient-$(openssl rand -hex 4) \
    -v $CERT_FILE:/selfsigned.pem \
    -e SSL_CERT_FILE=/selfsigned.pem \
    -e TOKEN=$TOKEN \
    gravitl/netclient:latest
