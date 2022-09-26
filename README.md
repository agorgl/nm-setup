# nm-setup

Helper scripts to deploy a netmaker infrastructure in podman containers  

## Usage

Setup netmaker server for DOMAIN with exposed ports defined in OPTIONS (optional, see nm-setup.sh for defaults):
```
curl -sfL https://raw.githubusercontent.com/agorgl/nm-setup/master/scripts/nm-setup.sh | sudo bash -s - <DOMAIN> <OPTIONS>
```

Join a netmaker network with access TOKEN:
```
curl -sfL https://raw.githubusercontent.com/agorgl/nm-setup/master/scripts/nm-join.sh | sudo bash -s - <TOKEN>
```

Sync routes from containers to host:
```
curl -sfL https://raw.githubusercontent.com/agorgl/nm-setup/master/scripts/nm-routes.sh | sudo bash -s -
```

Persist autostart of containers along with route syncing:
```
curl -sfL https://raw.githubusercontent.com/agorgl/nm-setup/master/scripts/nm-persist.sh | sudo bash -s -
```
