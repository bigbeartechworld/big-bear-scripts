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

# Function to get the last three Portainer versions
get_last_three_versions() {
    curl -s https://api.github.com/repos/portainer/portainer/releases | grep -m 3 '"tag_name":' | awk -F'"' '{print $4}'
}

# Function to remove existing Portainer images
remove_existing_images() {
    echo "Checking for existing Portainer images..."
    existing_images=$(docker images portainer/portainer-ce -q)
    if [ -n "$existing_images" ]; then
        echo "Removing existing Portainer images..."
        docker rmi $existing_images
        check_command "Failed to remove existing Portainer images"
    else
        echo "No existing Portainer images found. Proceeding with installation."
    fi
}

# Get current Portainer version
current_version=$(get_current_version)

# Get the last three versions
mapfile -t versions < <(get_last_three_versions)

echo "Current Portainer version: $current_version"
echo "Available versions:"
for i in "${!versions[@]}"; do
    echo "$((i+1)). ${versions[i]}"
done
echo "4. Latest (${versions[0]})"

# Ask user to choose a version
# Start an infinite loop to ensure we get a valid input
while true; do
    # Prompt the user to choose a version and store the input in 'choice'
    read -p "Which version would you like to install? (1-4, default is 4): " choice

    # If 'choice' is empty, set it to 4 (latest version)
    # ${choice:-4} means "use the value of 'choice' if it's set, otherwise use 4"
    choice=${choice:-4}

    # Check if the input is a number between 1 and 4
    # =~ is for regex matching, ^[1-4]$ matches any single digit from 1 to 4
    if [[ "$choice" =~ ^[1-4]$ ]]; then
        # If the choice is 4 (latest version)
        if [ "$choice" -eq 4 ]; then
            # Set version_to_install to the first (newest) version in the array
            version_to_install=${versions[0]}
        else
            # Set version_to_install to the chosen version
            # We subtract 1 from choice because array indexing starts at 0
            version_to_install=${versions[$((choice-1))]}
        fi
        # Exit the loop as we have a valid choice
        break
    else
        echo "Invalid choice. Please enter a number between 1 and 4."
    fi
done

echo "You have chosen to install Portainer version: $version_to_install"
echo
echo "This script will perform the following actions:"
echo "1. Stop and remove the current Portainer container (if running)"
echo "2. Remove any existing Portainer images"
echo "3. Pull Portainer image version $version_to_install"
echo "4. Create and start a new Portainer container with version $version_to_install"
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
    echo "No existing Portainer container found. Proceeding with installation."
fi

# Remove existing Portainer images
remove_existing_images

# Pull the selected Portainer image
echo "Pulling Portainer image version $version_to_install..."
docker pull portainer/portainer-ce:$version_to_install
check_command "Failed to pull Portainer image"

# Create and start a new Portainer container
echo "Creating and starting a new Portainer container..."
docker run -d \
    -p 8000:8000 \
    -p 9443:9443 \
    --name portainer \
    --restart always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:$version_to_install
check_command "Failed to create and start new Portainer container"

echo "Portainer has been updated to version $version_to_install and restarted successfully."

# Verify the new version
new_version=$(get_current_version)
echo "New Portainer version: $new_version"
