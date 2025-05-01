#!/usr/bin/env bash

# Function to get LAN IP addresses, prioritizing non-loopback and non-docker interfaces
Get_IPs() {
    # Try ip command first (more reliable)
    if command -v ip >/dev/null 2>&1; then
        # Get all IPv4 addresses, exclude loopback (127.0.0.0/8) and docker interfaces
        ip -4 addr show | grep -v "inet 127\." | grep -v "docker" | grep -v "br-" | grep -v "veth" | grep "inet" | awk '{print $2}' | cut -d/ -f1
    # Fall back to ifconfig if ip command is not available
    elif command -v ifconfig >/dev/null 2>&1; then
        # Get all IPv4 addresses, exclude loopback (127.0.0.0/8) and docker interfaces
        ifconfig | grep -v "inet 127\." | grep -v "docker" | grep -v "br-" | grep -v "veth" | grep "inet" | awk '{print $2}' | cut -d: -f2
    # Last resort, try hostname -I but filter out loopback addresses
    else
        hostname -I | tr ' ' '\n' | grep -v "^127\." | head -n 1
    fi
}

# Get the first valid LAN IP address
lan_ip=$(Get_IPs | head -n 1)

# If no valid IP was found, exit with error
if [ -z "$lan_ip" ]; then
    echo "Error: Could not determine LAN IP address."
    exit 1
fi

echo "Using LAN IP: $lan_ip"

# Backup the original config.php file
cp /DATA/AppData/big-bear-nextcloud/html/config/config.php /DATA/AppData/big-bear-nextcloud/html/config/config.php.bak

# Add the LAN IP to the config.php file
awk -v ip="$lan_ip" '/0 => '\''localhost'\''/{print; print "    1 => '\''" ip "'\'',"; next}1' /DATA/AppData/big-bear-nextcloud/html/config/config.php.bak > /DATA/AppData/big-bear-nextcloud/html/config/config.php

# Get the path to the docker-compose.yml file
COMPOSE_FILE="/var/lib/casaos/apps/big-bear-nextcloud/docker-compose.yml"

# Apply changes using casaos-cli
casaos-cli app-management apply "big-bear-nextcloud" --file="$COMPOSE_FILE"
