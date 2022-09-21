#!/bin/bash
set -e

# Directory containing volume data
NMDIR=$HOME/.local/share/netmaker

# Remove previous pod if exists
echo "Removing netmaker pod ..."
podman pod exists netmaker && podman pod rm -f netmaker

# Remove volumes
echo "Removing netmaker volumes ..."
podman volume rm -f \
    netmaker-data \
    netmaker-certs \
    netmaker-mq-data \
    netmaker-mq-logs

# Remove state directory
echo "Removing netmaker directory ..."
rm -rf $NMDIR
