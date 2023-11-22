#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Check if Docker CE 20+ is installed
DOCKER_INSTALLED=false
if command -v docker &> /dev/null; then
    DOCKER_INSTALLED=true
fi

# Check if Podman is installed
PODMAN_INSTALLED=false
if command -v podman &> /dev/null; then
    PODMAN_INSTALLED=true
fi

# Check if either Docker CE or Podman is installed, and give the user the option to install if not
# Check if neither Docker CE nor Podman is installed
if [ "$DOCKER_INSTALLED" = false ] && [ "$PODMAN_INSTALLED" = false ]; then
    echo "Neither Docker CE nor Podman is installed."

    # Prompt user to install Docker CE
    read -p "Do you want to install Docker CE (y/n)? " INSTALL_DOCKER

    # If user chooses to install Docker CE
    if [ "$INSTALL_DOCKER" = "y" ] || [ "$INSTALL_DOCKER" = "Y" ]; then
        # Install Docker CE
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        systemctl start docker
        systemctl enable docker
        DOCKER_INSTALLED=true
    else
        # Prompt user to install Podman
        read -p "Do you want to install Podman (y/n)? " INSTALL_PODMAN

        # If user chooses to install Podman
        if [ "$INSTALL_PODMAN" = "y" ] || [ "$INSTALL_PODMAN" = "Y" ]; then
            # Install Podman
            apt-get update
            apt-get install -y podman
            PODMAN_INSTALLED=true
        else
            echo "Please install Docker CE or Podman manually to proceed."
            exit 1
        fi
    fi
fi

# Set the Dockge directory path
DOCKGE_DIR="/opt/dockge"

# Check if the Dockge directory exists
if [ -d "$DOCKGE_DIR" ]; then
    # Prompt the user to update Dockge
    read -p "Dockge is already installed. Do you want to update it (y/n)? " UPDATE_DOCKGE

    # If the user wants to update Dockge
    if [ "$UPDATE_DOCKGE" = "y" ] || [ "$UPDATE_DOCKGE" = "Y" ]; then
        # Change to Dockge directory
        cd "$DOCKGE_DIR"

        # Pull the latest Docker images
        docker compose pull

        # Start Dockge
        docker compose up -d

        # Print a success message
        echo "Dockge has been updated."

        # Exit with status code 0 (success)
        exit 0
    fi
fi

# If Dockge is not installed or not updated, continue with the installation

# Set default values
STACKS_DIR="/opt/stacks"
PORT="5001"

# Create directories if they don't exist
mkdir -p "$STACKS_DIR" "$DOCKGE_DIR"

# Download the compose.yaml file from the specified URL and save it to the given directory
curl https://raw.githubusercontent.com/louislam/dockge/master/compose.yaml --output "$DOCKGE_DIR/compose.yaml"

# Start Dockge based on the installed container runtime
# Check if Docker is installed
if [ "$DOCKER_INSTALLED" = true ]; then
    # Using Docker CE
    echo "Starting Dockge with Docker CE..."
    docker compose -f "$DOCKGE_DIR/compose.yaml" -p dockge up -d
elif [ "$PODMAN_INSTALLED" = true ]; then
    # Using Podman
    echo "Starting Dockge with Podman..."
    podman-compose -f "$DOCKGE_DIR/compose.yaml" up -d
else
    # Neither Docker CE nor Podman is installed
    echo "Neither Docker CE nor Podman is installed. Cannot proceed."
    exit 1
fi

# Get the local IP address of the host
LAN_IP=$(hostname -I | awk '{print $1}')

# Print the URL where Dockge is now running
echo "Dockge is now running on http://$LAN_IP:$PORT"
