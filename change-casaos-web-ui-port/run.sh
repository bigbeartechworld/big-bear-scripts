#!/bin/bash

# Ask the user for the new port number
read -p "Enter the new port number for CasaOS: " new_port

# Check if the input is a valid number
if ! [[ "$new_port" =~ ^[0-9]+$ ]]; then
    echo "Error: Please enter a valid port number."
    exit 1
fi

# Backup the original configuration file
cp /etc/casaos/gateway.ini /etc/casaos/gateway.ini.bak

# Change the port number in the configuration file
sed -i "s/^port=[0-9]\+/port=$new_port/" /etc/casaos/gateway.ini

# Restart the CasaOS Gateway service
systemctl restart casaos-gateway.service

echo "Port changed and CasaOS Gateway service restarted successfully."
