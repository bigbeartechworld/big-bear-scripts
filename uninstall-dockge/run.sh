#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Stop and remove the Dockge containers
if command -v docker &> /dev/null; then
    # Using Docker CE
    echo "Stopping and removing Dockge containers with Docker CE..."
    docker compose -f /opt/dockge/compose.yaml -p dockge down
elif command -v podman &> /dev/null; then
    # Using Podman
    echo "Stopping and removing Dockge containers with Podman..."
    podman-compose -f /opt/dockge/compose.yaml down
else
    echo "Neither Docker CE nor Podman is installed. Nothing to uninstall."
    exit 1
fi

# Remove the Dockge directories
echo "Removing Dockge directories..."
rm -rf /opt/stacks /opt/dockge

echo "Dockge has been uninstalled."
