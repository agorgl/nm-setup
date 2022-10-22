#!/bin/bash

# Constants
NETMAKER_DIR=/var/lib/netmaker
SYSTEMD_UNIT_DIR=/etc/systemd/system

# Gather applicable containers
containers=$(podman ps --format '{{ .Names }}' | grep 'netmaker-\|netclient-')

# For each container
for container in $containers; do
    # Generate container service file if not exists
    unit_file=$SYSTEMD_UNIT_DIR/$container.service
    [ ! -f $unit_file ] && podman generate systemd -n $container > $unit_file

    # Reload unit files
    systemctl daemon-reload

    # Enable and start service
    systemctl enable --now $container
done

# Get route sync script
curl -sfL --create-dirs -O --output-dir $NETMAKER_DIR https://raw.githubusercontent.com/agorgl/nm-setup/master/scripts/nm-routes.sh
chmod a+x $NETMAKER_DIR/nm-routes.sh

# Generate service and timer unit files for route syncing
[ ! -f $SYSTEMD_UNIT_DIR/netmaker-routes.service ] && cat << EOF > $SYSTEMD_UNIT_DIR/netmaker-routes.service
[Unit]
Description=Synchronize container routes
Wants=network.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=$NETMAKER_DIR/nm-routes.sh
EOF

[ ! -f $SYSTEMD_UNIT_DIR/netmaker-routes.timer ] && cat << EOF > $SYSTEMD_UNIT_DIR/netmaker-routes.timer
[Unit]
Description=Periodic route synchronization

[Timer]
OnCalendar=*:*:00/30
AccuracySec=1sec
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Reload unit files
systemctl daemon-reload

# Enable and start timer
systemctl enable --now netmaker-routes.timer
