#!/bin/bash

MESSAGE="Made by BigBearTechWorld"

# Function to print a decorative line
print_decorative_line() {
    printf "%s\n" "------------------------------------------------------"
}

# Print the introduction message with decorations
echo
print_decorative_line
echo "Portainer CE Update Script"
print_decorative_line
echo
echo "$MESSAGE"
echo
print_decorative_line
echo
echo "If this is useful, please consider supporting my work at: https://ko-fi.com/bigbeartechworld"
echo
print_decorative_line

# Function to check if a command succeeded
check_command() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

# Function to get current Portainer version
get_current_version() {
    local version

    # Check if Portainer container is running
    if docker ps --format '{{.Names}}' | grep -q '^portainer$'; then
        # Try to get version from running container
        version=$(docker exec portainer portainer --version 2>/dev/null | awk '{print $2}')

        # If that fails, try to get version from container labels
        if [ -z "$version" ] || [ "$version" = "runtime" ]; then
            version=$(docker inspect -f '{{index .Config.Labels "org.opencontainers.image.version"}}' portainer 2>/dev/null)
        fi

        # If still empty, get the image tag
        if [ -z "$version" ]; then
            version=$(docker inspect -f '{{.Config.Image}}' portainer | awk -F: '{print $2}')
            [ -z "$version" ] && version="latest"
        fi
    else
        # Check if Portainer container exists but is not running
        if docker ps -a --format '{{.Names}}' | grep -q '^portainer$'; then
            version=$(docker inspect -f '{{index .Config.Labels "org.opencontainers.image.version"}}' portainer 2>/dev/null)
            [ -z "$version" ] && version="Unknown (container exists but is not running)"
        else
            # Check if Portainer image exists
            if docker images portainer/portainer-ce -q | grep -q .; then
                version="Unknown (image exists)"
            fi
        fi
    fi

    # If still empty, assume not installed
    if [ -z "$version" ]; then
        echo "Not installed"
    else
        echo "$version"
    fi
}

# Get current Portainer version
current_version=$(get_current_version)

# Fetch the latest available version
latest_version=$(curl -s https://api.github.com/repos/portainer/portainer/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
check_command "Failed to fetch the latest Portainer version"

echo "Current Portainer version: $current_version"
echo "Latest Portainer version: $latest_version"
echo
echo "This script will perform the following actions:"
echo "1. Stop and remove the current Portainer container (if running)"
echo "2. Remove the existing Portainer image"
echo "3. Pull the latest Portainer image"
echo "4. Create and start a new Portainer container"
echo
read -p "Do you want to proceed with the update? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Update cancelled."
    exit 1
fi

# Stop and remove the current Portainer container if it exists
if docker ps -a --format '{{.Names}}' | grep -q '^portainer$'; then
    echo "Stopping and removing the current Portainer container..."
    docker stop portainer
    check_command "Failed to stop Portainer container"
    docker rm portainer
    check_command "Failed to remove Portainer container"
else
    echo "No existing Portainer container found. Proceeding with update."
fi

# Remove the existing Portainer image if it exists
if docker images portainer/portainer-ce -q | grep -q .; then
    echo "Removing the existing Portainer image..."
    docker rmi portainer/portainer-ce
    check_command "Failed to remove Portainer image"
else
    echo "No existing Portainer image found. Proceeding with update."
fi

# Pull the latest Portainer image
echo "Pulling the latest Portainer image..."
docker pull portainer/portainer-ce:$latest_version
check_command "Failed to pull latest Portainer image"

# Create and start a new Portainer container
echo "Creating and starting a new Portainer container..."
docker run -d \
    -p 8000:8000 \
    -p 9443:9443 \
    --name portainer \
    --restart always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:$latest_version
check_command "Failed to create and start new Portainer container"

echo "Portainer has been updated and restarted successfully."

# Verify the new version
new_version=$(get_current_version)
echo "New Portainer version: $new_version"
