#!/bin/bash

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Display open files using lsof or netstat
echo "List of processes with port 53 open:"
lsof -i :53 || netstat -tulpn | grep ":53 "

# Disable and stop systemd-resolved service
echo "Disabling and stopping systemd-resolved service..."
systemctl disable systemd-resolved.service
systemctl stop systemd-resolved.service

echo "Systemd-resolved service disabled and stopped."
