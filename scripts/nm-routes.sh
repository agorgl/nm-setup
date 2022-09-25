#!/bin/bash

# Constants
ROUTING_TABLE=5050

# Gather applicable containers
containers=$(podman ps --format '{{ .Names }}' | grep 'netmaker-server\|netclient-')

# For each container
for container in $containers; do
    # Get container ip and routes
    echo "Adding routes for container $container"
    container_ip=$(podman inspect $container -f '{{ .NetworkSettings.IPAddress }}')
    routes=$(podman exec $container ip route | grep nm- | awk '{print $1}' | grep '/')

    # Add them to custom routing table
    echo "Adding routes for networks $(echo $routes) via container ip $container_ip in table $ROUTING_TABLE"
    ip route flush table $ROUTING_TABLE
    printf "%s\n" $routes | xargs -I {} ip route replace {} via $container_ip table $ROUTING_TABLE

    # Add rule to custom routing table
    echo "Adding table $ROUTING_TABLE to routing policy database"
    ip rule list | awk '/lookup/ {print $NF}' | grep $ROUTING_TABLE | xargs ip rule del table
    ip rule add from all table $ROUTING_TABLE
done
