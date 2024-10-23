#!/usr/bin/env bash

# Path to the configuration file
CONFIG_FILE="/etc/casaos/gateway.ini"

# Check if the configuration file exists
if [[ -f $CONFIG_FILE ]]; then
    # Use grep to find the line with 'port' and use awk to print the value
    PORT=$(grep '^port=' $CONFIG_FILE | awk -F'=' '{print $2}')
    # Get the local IP address
    IP_ADDR=$(hostname -I | awk '{print $1}')
    echo "The local IP address is: $IP_ADDR"
    echo "The port number is: $PORT"
    echo "You can access it in the browser at: http://$IP_ADDR:$PORT"
else
    echo "Error: Configuration file not found."
fi
