#!/usr/bin/env bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Function to confirm with the user before proceeding
confirm_action() {
    read -r -p "$1 Are you sure you want to proceed? (y/N): " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Uninstallation canceled."
        exit 1
    fi
}

# Function to uninstall Docker or Podman
uninstall_docker_podman() {
    if command -v docker &> /dev/null; then
        # Uninstall Docker CE
        echo "Uninstalling Docker CE..."
        apt-get remove --purge docker-ce docker-ce-cli containerd.io
        rm -rf /var/lib/docker
        echo "Docker CE has been uninstalled."
    elif command -v podman &> /dev/null; then
        # Uninstall Podman
        echo "Uninstalling Podman..."
        apt-get remove --purge podman
        echo "Podman has been uninstalled."
    else
        echo "Neither Docker CE nor Podman is installed."
    fi
}

# Ask the user if they want to uninstall Docker CE or Podman
read -r -p "Do you want to uninstall Docker CE or Podman? (docker/podman/none): " uninstall_choice
case $uninstall_choice in
    docker|podman)
        confirm_action "You have chosen to uninstall $uninstall_choice. This will remove all related packages and data."
        uninstall_docker_podman
        ;;
    none)
        echo "Skipping uninstallation of Docker CE/Podman."
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

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

# Confirm with the user before removing the Dockge directories
confirm_action "Removing Dockge directories..."

# Remove the Dockge directories
echo "Removing Dockge directories..."
rm -rf /opt/stacks /opt/dockge

echo "Dockge has been uninstalled."
