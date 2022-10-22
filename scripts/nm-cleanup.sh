#!/bin/bash
set -e

# Arguments
REMOVE_STATE=false
while [ "$1" != "" ]; do
    case $1 in
        -a|--all)
            REMOVE_STATE=true
    esac
    shift
done

# Directory containing volume data
[ "${EUID:-$(id -u)}" -eq 0 ] \
    && NMDIR=/var/lib/netmaker \
    || NMDIR=$HOME/.local/share/netmaker

# Remove systemd units
units=$(systemctl list-unit-files --all | grep 'netmaker-\|netclient-' | awk '{print $1}')
for unit in $units; do
    echo "Disabling and stopping $unit ..."
    systemctl disable --now $unit

    echo "Removing $unit"
    unit_path=$(systemctl show -P FragmentPath $unit)
    rm $unit_path
done
systemctl daemon-reload

# Remove previous pod if exists
echo "Removing netmaker pod ..."
podman pod exists netmaker && podman pod rm -f netmaker

if [ $REMOVE_STATE = true ]; then
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
fi
