#!/bin/bash

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Display open files using lsof or netstat
echo "List of processes with port 53 open:"
lsof -i :53 || netstat -tulpn | grep ":53 "

# Ask user for confirmation
read -p "This script will display processes using port 53 and then disable systemd-resolved service. Do you want to proceed? (y/n): " choice
if [[ ! "$choice" =~ [yY] ]]; then
    echo "Script execution aborted."
    exit 0
fi

# Disable and stop systemd-resolved service
echo "Disabling and stopping systemd-resolved service..."
systemctl disable systemd-resolved.service
systemctl stop systemd-resolved.service

echo "Systemd-resolved service disabled and stopped."

# Check if port 53 is clear
echo "Checking if port 53 is clear..."
port_53_status=$(lsof -i :53 | wc -l)
if [ "$port_53_status" -eq 0 ]; then
    echo "Port 53 is clear."
else
    echo "Port 53 is still in use."
fi
