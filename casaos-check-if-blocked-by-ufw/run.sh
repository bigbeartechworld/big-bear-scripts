#!/bin/bash

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

    # Check if UFW is active
    UFW_ACTIVE=$(sudo ufw status | grep "Status: active")

    if [[ ! -z $UFW_ACTIVE ]]; then
        # If UFW is active, check if the port is listed in the UFW status
        UFW_PORT_STATUS=$(sudo ufw status | grep "$PORT")

        # If port is not listed or if it's listed as DENY, it's considered blocked
        if [[ -z $UFW_PORT_STATUS || $UFW_PORT_STATUS == *DENY* ]]; then
            echo "The port $PORT is blocked by UFW."

            # Ask the user if they want to unblock the port
            read -p "Do you want to unblock port $PORT in UFW? (yes/no): " choice
            case "$choice" in
                yes|y|Y|YES)
                    sudo ufw allow $PORT
                    echo "Port $PORT has been unblocked in UFW."
                    ;;
                *)
                    echo "Port remains blocked."
                    ;;
            esac
        else
            echo "The port $PORT is not blocked by UFW."
        fi
    else
        echo "UFW is not active."
    fi

else
    echo "Error: Configuration file not found."
fi
