#!/usr/bin/env bash

# This script attempts to find the server's primary IP address.
# It first tries using 'ifconfig' and then falls back to 'ip addr' if 'ifconfig' doesn't produce a result.

# Identify the primary network interface by checking the default route.
primary_interface=$(ip route | grep default | awk '{print $5}')

# Try to retrieve the server's primary IP address using ifconfig.
ifconfig_ip=$(ifconfig $primary_interface | grep -oE 'inet (10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[0-1])\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3})' | awk '{print $2}')

# Check if the result from ifconfig is empty.
# If it is, try to use 'ip addr' to retrieve the IP.
if [ -z "$ifconfig_ip" ]; then
    # Try to retrieve the server's primary IP address using 'ip addr'.
    ip_ip=$(ip addr show $primary_interface | grep -oE 'inet (10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[0-1])\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3})' | awk '{print $2}')

    # Check if the result from 'ip addr' is non-empty.
    # If it is, print the IP. Otherwise, print an error message.
    if [ -n "$ip_ip" ]; then
        echo "Server IP (via ip): $ip_ip"
    else
        echo "Unable to determine server IP"
    fi
else
    # If the result from 'ifconfig' was non-empty, print the IP.
    echo "Server IP (via ifconfig): $ifconfig_ip"
fi
