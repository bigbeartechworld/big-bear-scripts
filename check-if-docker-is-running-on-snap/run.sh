#!/bin/bash

# Function to ask for user confirmation
confirm() {
    while true; do
        read -rp "$1 [y/n]: " yn
        case $yn in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Check if Docker is installed via Snap
if snap list docker &> /dev/null; then
    echo "Docker is installed via Snap."
    if confirm "Do you want to uninstall the Snap version of Docker?"; then
        echo "Uninstalling Docker from Snap..."
        sudo snap remove docker
    else
        echo "Skipping Docker uninstallation from Snap."
    fi
else
    echo "Docker is not installed via Snap, or Snap is not installed."
fi
