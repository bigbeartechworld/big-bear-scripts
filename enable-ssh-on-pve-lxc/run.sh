#!/bin/bash

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Set the root password
echo "Setting up root password..."
passwd root

# Enable SSH root login
echo "Enabling SSH for root..."
sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Restart the SSH service
echo "Restarting SSH service..."
systemctl restart sshd

echo "Done!"
