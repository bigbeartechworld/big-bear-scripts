#!/bin/bash

# Path to the configuration file
CONFIG_FILE="/etc/casaos/gateway.ini"
# Prefix for casaos services
SERVICE_PREFIX="casaos"

# Check if the configuration file exists
if [[ -f $CONFIG_FILE ]]; then
    # Get the port from the configuration file
    PORT=$(grep '^port=' $CONFIG_FILE | awk -F'=' '{print $2}')
    # Get the local IP address
    IP_ADDR=$(hostname -I | awk '{print $1}')
    echo "The local IP address is: $IP_ADDR"
    echo "The port number is: $PORT"
    echo "You can access it in the browser at: http://$IP_ADDR:$PORT"

    # Check UFW status for the port
    UFW_STATUS=$(sudo ufw status | grep "$PORT")

    if [[ $UFW_STATUS == *DENY* ]]; then
        echo "WARNING: The port $PORT is blocked by UFW."
    else
        echo "The port $PORT is not blocked by UFW."
    fi
else
    echo "Error: Configuration file not found."
fi

# Get a list of all casaos services
SERVICES=$(systemctl list-units --type=service | grep "$SERVICE_PREFIX" | awk '{print $1}')

# Check if any services were found
if [[ -z "$SERVICES" ]]; then
    echo "No casaos services found!"
    exit 1
fi

# Flag to track overall health
ALL_SERVICES_OK=true

# Check the status of each service
for service in $SERVICES; do
    # Get the status of the service
    STATUS=$(systemctl is-active "$service")

    if [[ "$STATUS" == "active" ]]; then
        echo "Service $service is running."
    else
        echo "WARNING: Service $service is NOT running!"
        ALL_SERVICES_OK=false
    fi
done

# Check for any errors in the service logs
ERROR_FOUND=false
for service in $SERVICES; do
    # Use journalctl to fetch the last 10 lines of log for the service
    ERRORS=$(sudo journalctl -u $service -n 10 | grep -E 'error|fail|exception')
    if [[ ! -z $ERRORS ]]; then
        ERROR_FOUND=true
        echo -e "Errors in $service logs:"
        echo "$ERRORS"
        echo "-----"
    fi
done

if $ERROR_FOUND; then
    echo -e "Service Logs: Errors Found $CROSS_MARK"
else
    echo -e "Service Logs: No Errors Found $CHECK_MARK"
fi

# Provide an overall health summary
if $ALL_SERVICES_OK; then
    echo "All casaos services are up and running."
else
    echo "Some casaos services are not running. Please check the above output."
fi
