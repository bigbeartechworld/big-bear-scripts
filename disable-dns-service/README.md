## Why?

This is a handy script to disable and stop systemd-resolved service.

## How to use?

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/bigbeartechworld/big-bear-scripts/master/disable-dns-service/disable_dns_service.sh)"
```

## How to troubleshoot?

Check and see if port 53 is taken:

```bash
lsof -i :53
```

OR

```bash
netstat -tulpn | grep ":53 "
```

Disable and stop the systemd-resolved service:

```bash
sudo systemctl disable systemd-resolved.service
```

```bash
sudo systemctl stop systemd-resolved.service
```
