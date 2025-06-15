#!/usr/bin/env bash

# Enable strict error handling
set -euo pipefail

# Trap errors and provide clean exit
trap 'echo "Aborting..."; exit 1' ERR

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
echo "Big Bear Portainer Password Reset Script v1.0"
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

# Function to check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        echo "Error: Docker is not running or not accessible."
        echo "Please make sure Docker is installed and running."
        exit 1
    fi
}

# Function to find Portainer container
find_portainer_container() {
    local container_name
    
    # Check common Portainer container names
    for name in "portainer" "portainer_portainer" "portainer-ce"; do
        if docker ps -a --format '{{.Names}}' | grep -q "^${name}$"; then
            echo "$name"
            return 0
        fi
    done
    
    # Check for any container with portainer in the name
    container_name=$(docker ps -a --format '{{.Names}}' | grep -i portainer | head -n 1)
    if [ -n "$container_name" ]; then
        echo "$container_name"
        return 0
    fi
    
    return 1
}

# Function to find Portainer data volume
find_portainer_volume() {
    local container_name="$1"
    local volume_name
    
    # Get the volume mount for the data directory
    volume_name=$(docker inspect "$container_name" --format '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Name}}{{end}}{{end}}' 2>/dev/null)
    
    if [ -n "$volume_name" ]; then
        echo "$volume_name"
        return 0
    fi
    
    # Check for common volume names
    for vol in "portainer_data" "portainer_portainer_data" "portainer-data"; do
        if docker volume ls --format '{{.Name}}' | grep -q "^${vol}$"; then
            echo "$vol"
            return 0
        fi
    done
    
    return 1
}

# Function to detect deployment type
detect_deployment_type() {
    local container_name="$1"
    
    # Check if it's running as a service
    if docker service ls --format '{{.Name}}' | grep -q portainer; then
        echo "service"
        return 0
    fi
    
    # Check if it's part of a stack
    if docker inspect "$container_name" --format '{{index .Config.Labels "com.docker.stack.namespace"}}' 2>/dev/null | grep -q .; then
        echo "stack"
        return 0
    fi
    
    # Default to container
    echo "container"
}

# Check if Docker is running
echo "Checking Docker status..."
check_docker
echo "✓ Docker is running"

# Find Portainer container
echo "Looking for Portainer container..."
portainer_container=$(find_portainer_container)
if [ $? -ne 0 ]; then
    echo "Error: No Portainer container found."
    echo "Please make sure Portainer is installed and running."
    exit 1
fi
echo "✓ Found Portainer container: $portainer_container"

# Find Portainer data volume
echo "Looking for Portainer data volume..."
portainer_volume=$(find_portainer_volume "$portainer_container")
if [ $? -ne 0 ]; then
    echo "Error: Could not find Portainer data volume."
    echo "Please make sure Portainer is properly configured with a data volume."
    exit 1
fi
echo "✓ Found Portainer data volume: $portainer_volume"

# Detect deployment type
deployment_type=$(detect_deployment_type "$portainer_container")
echo "✓ Detected deployment type: $deployment_type"

echo
echo "This script will reset the password for the Portainer administrator account."
echo "Container: $portainer_container"
echo "Data Volume: $portainer_volume"
echo "Deployment Type: $deployment_type"
echo
echo "WARNING: This will temporarily stop your Portainer instance!"
echo
read -p "Do you want to proceed with the password reset? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Password reset cancelled."
    exit 1
fi

echo
print_decorative_line
echo "Starting password reset process..."
print_decorative_line

# Stop Portainer based on deployment type
case $deployment_type in
    "service")
        echo "Scaling down Portainer service..."
        service_name=$(docker service ls --format '{{.Name}}' | grep portainer | head -n 1)
        docker service scale "${service_name}=0"
        check_command "Failed to scale down Portainer service"
        echo "✓ Portainer service scaled down"
        ;;
    "stack")
        echo "Stopping Portainer container..."
        docker stop "$portainer_container"
        check_command "Failed to stop Portainer container"
        echo "✓ Portainer container stopped"
        ;;
    *)
        echo "Stopping Portainer container..."
        docker stop "$portainer_container"
        check_command "Failed to stop Portainer container"
        echo "✓ Portainer container stopped"
        ;;
esac

# Run the password reset helper
echo "Running Portainer password reset helper..."
echo "This may take a few moments..."

# Capture the output from the helper container
reset_output=$(docker run --rm -v "${portainer_volume}:/data" portainer/helper-reset-password 2>&1)
reset_exit_code=$?

if [ $reset_exit_code -ne 0 ]; then
    echo "Error: Password reset helper failed"
    echo "Output: $reset_output"
    
    # Try to restart Portainer
    echo "Attempting to restart Portainer..."
    case $deployment_type in
        "service")
            docker service scale "${service_name}=1"
            ;;
        *)
            docker start "$portainer_container"
            ;;
    esac
    exit 1
fi

echo "✓ Password reset helper completed successfully"

# Extract the new password from the output
new_password=$(echo "$reset_output" | grep -o "Use the following password to login: .*" | sed 's/Use the following password to login: //')

# Validate the extracted password
if [ -z "$new_password" ]; then
    echo "Error: Failed to extract new password from helper output"
    echo "Helper output: $reset_output"
    
    # Try to restart Portainer before exiting
    echo "Attempting to restart Portainer..."
    case $deployment_type in
        "service")
            docker service scale "${service_name}=1"
            ;;
        *)
            docker start "$portainer_container"
            ;;
    esac
    exit 1
fi

# Validate password complexity (minimum 8 characters, alphanumeric and special characters)
if ! [[ "$new_password" =~ ^[A-Za-z0-9\!\@\#\$\%\^\&\*\(\)\_\+\-\=\[\]\{\}\|\\\:\;\"\'\<\>\,\.\?\/\~\`]{8,64}$ ]]; then
    echo "Error: Generated password does not meet expected complexity requirements"
    echo "Password should be 8-64 characters containing letters, numbers, and special characters"
    echo "Generated password: $new_password"
    
    # Try to restart Portainer before exiting
    echo "Attempting to restart Portainer..."
    case $deployment_type in
        "service")
            docker service scale "${service_name}=1"
            ;;
        *)
            docker start "$portainer_container"
            ;;
    esac
    exit 1
fi

echo "✓ Password validation passed"

# Start Portainer based on deployment type
case $deployment_type in
    "service")
        echo "Scaling up Portainer service..."
        docker service scale "${service_name}=1"
        check_command "Failed to scale up Portainer service"
        echo "✓ Portainer service scaled up"
        ;;
    *)
        echo "Starting Portainer container..."
        docker start "$portainer_container"
        check_command "Failed to start Portainer container"
        echo "✓ Portainer container started"
        ;;
esac

# Wait a moment for Portainer to start
echo "Waiting for Portainer to start..."
sleep 5

# Display results
echo
print_decorative_line
echo "PASSWORD RESET COMPLETED SUCCESSFULLY!"
print_decorative_line
echo
echo "Username: admin"
echo "New Password: $new_password"
echo
echo "IMPORTANT: Please save this password in a secure location!"
echo "You can now log in to Portainer using the credentials above."
echo
print_decorative_line
echo "Portainer should be accessible at your usual URL."
echo "If you're using HTTPS, it may take a moment for the service to be fully ready."
print_decorative_line
echo
echo "Thank you for using BigBearTechWorld scripts!"
echo "Support my work at: https://ko-fi.com/bigbeartechworld"
echo 