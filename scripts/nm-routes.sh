#!/bin/bash

# Constants
ROUTING_TABLE=5050

# Gather applicable containers
containers=$(podman ps --format '{{ .Names }}' | grep 'netmaker-server\|netclient-')

# For each container
all_routes=""
for container in $containers; do
    # Get container ip and routes
    container_ip=$(podman inspect $container -f '{{ .NetworkSettings.IPAddress }}')
    container_routes=$(podman exec $container ip route | grep nm- | awk '{print $1}' | grep '/' | xargs printf "%s:$container_ip\n")
    all_routes+=$container_routes

    # Get existing routes
    routes=$(ip route show table $ROUTING_TABLE | awk '{print $1 ":" $3}')

    # Calculate new routes
    new_routes=$(comm -23 <(printf "%s\n" $container_routes | sort) <(printf "%s\n" $routes | sort))

    # Add them to custom routing table
    for r in $new_routes; do
        route=${r/:/ via }
        echo "Adding new route $route"
        ip route add $route table $ROUTING_TABLE
    done
done

# Calculate old routes
routes=$(ip route show table $ROUTING_TABLE | awk '{print $1 ":" $3}')
old_routes=$(comm -13 <(printf "%s\n" $all_routes | sort | uniq) <(printf "%s\n" $routes | sort))

# Remove old routes from custom routing table
for r in $old_routes; do
    route=${r/:/ via }
    echo "Removing old route $route"
    ip route del $route table $ROUTING_TABLE
done

# Add rule to custom routing table
if [ -z "$(ip rule list | awk '/lookup/ {print $NF}' | grep $ROUTING_TABLE)" ]; then
    echo "Adding table $ROUTING_TABLE to routing policy database"
    ip rule add from all table $ROUTING_TABLE
fi
