#!/bin/bash

# Define a message for branding purposes
MESSAGE="Made by BigBearTechWorld"

# Function to print a decorative line
print_decorative_line() {
    # Prints a line of dashes to the console
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
    # Check if the last command executed successfully (exit status 0)
    if [ $? -ne 0 ]; then
        # Print an error message if the command failed
        echo "Error: $1"
        # Exit the script with a status of 1 to indicate an error
        exit 1
    fi
}

# Function to get the current Portainer version
get_current_version() {
    local version

    # Check if the Portainer container is running
    if docker ps --format '{{.Names}}' | grep -q '^portainer$'; then
        # Try to get the version from the running container using the 'portainer --version' command
        version=$(docker exec portainer portainer --version 2>/dev/null | awk '{print $2}')

        # If that fails, try to get the version from the container's labels
        if [ -z "$version" ] || [ "$version" = "runtime" ]; then
            version=$(docker inspect -f '{{index .Config.Labels "org.opencontainers.image.version"}}' portainer 2>/dev/null)
        fi

        # If still empty, get the version from the image tag
        if [ -z "$version" ]; then
            version=$(docker inspect -f '{{.Config.Image}}' portainer | awk -F: '{print $2}')
            [ -z "$version" ] && version="latest" # Default to "latest" if no specific tag is found
        fi
    else
        # Check if the Portainer container exists but is not running
        if docker ps -a --format '{{.Names}}' | grep -q '^portainer$'; then
            version=$(docker inspect -f '{{index .Config.Labels "org.opencontainers.image.version"}}' portainer 2>/dev/null)
            # Set version as unknown if the container exists but isn't running
            [ -z "$version" ] && version="Unknown (container exists but is not running)"
        else
            # Check if the Portainer image exists on the system
            if docker images portainer/portainer-ce -q | grep -q .; then
                # Set version as unknown if only the image exists
                version="Unknown (image exists)"
            fi
        fi
    fi

    # If no version information is found, assume Portainer is not installed
    if [ -z "$version" ]; then
        echo "Not installed"
    else
        echo "$version" # Print the found version
    fi
}

# Get the current Portainer version
current_version=$(get_current_version)

# Fetch the latest available version of Portainer from GitHub API
latest_version=$(curl -s https://api.github.com/repos/portainer/portainer/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
# Check if the command to fetch the latest version was successful
check_command "Failed to fetch the latest Portainer version"

# Print the current and latest versions
echo "Current Portainer version: $current_version"
echo "Latest Portainer version: $latest_version"
echo
echo "This script will perform the following actions:"
echo "1. Stop and remove the current Portainer container (if running)"
echo "2. Remove the existing Portainer image"
echo "3. Pull the latest Portainer image"
echo "4. Create and start a new Portainer container"
echo

# Prompt the user to confirm whether to proceed with the update
read -p "Do you want to proceed with the update? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Update cancelled."
    exit 1
fi

# Stop and remove the current Portainer container if it exists
if docker ps -a --format '{{.Names}}' | grep -q '^portainer$'; then
    echo "Stopping and removing the current Portainer container..."
    docker stop portainer # Stop the running Portainer container
    check_command "Failed to stop Portainer container"
    docker rm portainer # Remove the stopped Portainer container
    check_command "Failed to remove Portainer container"
else
    echo "No existing Portainer container found. Proceeding with update."
fi

# Check if there are any existing Docker images for Portainer
if docker images portainer/portainer-ce -q | grep -q .; then
    # If an image exists, print a message indicating its removal
    echo "Removing the existing Portainer image..."
    # Remove the existing Portainer image
    docker rmi portainer/portainer-ce
    # Check if the removal command was successful and print an error message if it failed
    check_command "Failed to remove Portainer image"
else
    # If no image exists, print a message indicating that there is no image to remove
    echo "No existing Portainer image found. Proceeding with update."
fi

# Pull the latest Portainer image from the repository
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

# Verify the new version of Portainer
new_version=$(get_current_version)
echo "New Portainer version: $new_version"
