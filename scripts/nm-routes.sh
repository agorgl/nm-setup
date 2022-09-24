#!/bin/bash

# Constants
ROUTING_TABLE=5050

# Get container name, ip and routes
container=$(podman ps --format '{{ .Names }}' | grep 'netmaker-\|netclient-' | head -n 1)
container_ip=$(podman inspect $container -f '{{ .NetworkSettings.IPAddress }}')
routes=$(podman exec $container ip route | grep nm- | awk '{print $1}' | grep '/')

# Add them to custom routing table
ip route flush table $ROUTING_TABLE
printf "%s\n" $routes | xargs -I {} ip route replace {} via $container_ip table $ROUTING_TABLE

# Add rule to custom routing table
ip rule list | awk '/lookup/ {print $NF}' | grep $ROUTING_TABLE | xargs ip rule del table
ip rule add from all table $ROUTING_TABLE
