#!/usr/bin/env bash

# Enable strict error handling
set -euo pipefail

# Function to handle errors with detailed diagnostic information
# This function is called automatically when any command fails (via ERR trap)
handle_error() {
    local line_number="$1"
    local exit_code="$2"
    echo "ERROR: Script failed at line $line_number with exit status $exit_code"
    echo "Command that failed: $(sed -n "${line_number}p" "$0")"
    echo "Aborting..."
    exit "$exit_code"
}

# Trap errors and provide detailed error context
# ${LINENO} captures the line number where the error occurred
# $? captures the exit code of the failed command
trap 'handle_error ${LINENO} $?' ERR

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

# Function to handle command errors with custom messages
# This is for expected/handled errors with user-friendly messages
handle_command_error() {
    echo "Error: $1"
    exit 1
}

# Function to check if Docker is running
check_docker() {
    # Attempt to get Docker info; redirect output to suppress normal messages
    if ! docker info >/dev/null 2>&1; then
        echo "Error: Docker is not running or not accessible."
        echo "Please make sure Docker is installed and running."
        exit 1
    fi
}

# Function to find Portainer container
find_portainer_container() {
    local container_name
    
    # Check common Portainer container names first
    for name in "portainer" "portainer_portainer" "portainer-ce"; do
        # Use exact match with grep anchors (^$) to avoid partial matches
        if docker ps -a --format '{{.Names}}' | grep -q "^${name}$"; then
            echo "$name"
            return 0
        fi
    done
    
    # Fallback: Check for any container with portainer in the name (case-insensitive)
    container_name=$(docker ps -a --format '{{.Names}}' | grep -i portainer | head -n 1)
    if [ -n "$container_name" ]; then
        echo "$container_name"
        return 0
    fi
    
    # Return 1 (failure) if no Portainer container found
    return 1
}

# Function to find Portainer data volume or bind mount
find_portainer_volume() {
    local container_name="$1"
    local volume_info
    
    # Get mount information for the /data directory from container inspection
    # This complex format string extracts mount type and source/name
    volume_info=$(docker inspect "$container_name" --format '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Type}}:{{if eq .Type "volume"}}{{.Name}}{{else}}{{.Source}}{{end}}{{end}}{{end}}' 2>/dev/null)
    
    if [ -n "$volume_info" ]; then
        echo "$volume_info"
        return 0
    fi
    
    # Fallback: Check for common volume names if inspection fails
    for vol in "portainer_data" "portainer_portainer_data" "portainer-data"; do
        if docker volume ls --format '{{.Name}}' | grep -q "^${vol}$"; then
            echo "volume:$vol"
            return 0
        fi
    done
    
    return 1
}

# Function to find stack service name
find_stack_service() {
    local container_name="$1"
    local stack_namespace
    
    # Get the stack namespace from container labels
    stack_namespace=$(docker inspect "$container_name" --format '{{index .Config.Labels "com.docker.stack.namespace"}}' 2>/dev/null)
    
    if [ -n "$stack_namespace" ]; then
        # Find the service in the stack that matches portainer
        docker service ls --format '{{.Name}}' --filter "label=com.docker.stack.namespace=$stack_namespace" | grep portainer | head -n 1
    fi
}

# Function to detect deployment type (container, service, or stack)
detect_deployment_type() {
    local container_name="$1"
    
    # Check if it's part of a Docker stack first (highest priority)
    if docker inspect "$container_name" --format '{{index .Config.Labels "com.docker.stack.namespace"}}' 2>/dev/null | grep -q .; then
        echo "stack"
        return 0
    fi
    
    # Check if it's running as a Docker service
    if docker service ls --format '{{.Name}}' | grep -q portainer; then
        echo "service"
        return 0
    fi
    
    # Default to regular container deployment
    echo "container"
}

# === MAIN SCRIPT EXECUTION STARTS HERE ===

# Check if Docker is running
echo "Checking Docker status..."
check_docker
echo "✓ Docker is running"

# Find Portainer container
echo "Looking for Portainer container..."
if ! portainer_container=$(find_portainer_container); then
    echo "Error: No Portainer container found."
    echo "Please make sure Portainer is installed and running."
    exit 1
fi
echo "✓ Found Portainer container: $portainer_container"

# Find Portainer data volume or bind mount
echo "Looking for Portainer data volume or bind mount..."
if ! portainer_volume_info=$(find_portainer_volume "$portainer_container"); then
    echo "Error: Could not find Portainer data volume or bind mount."
    echo "Please make sure Portainer is properly configured with a data volume or bind mount."
    exit 1
fi

# Parse volume information into type and path
# Format is either "volume:volume_name" or "bind:/host/path"
volume_type=$(echo "$portainer_volume_info" | cut -d: -f1)
volume_path=$(echo "$portainer_volume_info" | cut -d: -f2-)

if [ "$volume_type" = "volume" ]; then
    echo "✓ Found Portainer data volume: $volume_path"
    portainer_volume="$volume_path"
else
    echo "✓ Found Portainer bind mount: $volume_path"
    portainer_volume="$volume_path"
fi

# Detect deployment type to determine how to stop/start Portainer
deployment_type=$(detect_deployment_type "$portainer_container")
echo "✓ Detected deployment type: $deployment_type"

# Display confirmation prompt with all gathered information
echo
echo "This script will reset the password for the Portainer administrator account."
echo "Container: $portainer_container"
if [ "$volume_type" = "volume" ]; then
    echo "Data Volume: $portainer_volume"
else
    echo "Bind Mount: $portainer_volume"
fi
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
# Different deployment types require different stop methods
case $deployment_type in
    "service")
        echo "Scaling down Portainer service..."
        # Find the service name and scale it to 0 replicas
        service_name=$(docker service ls --format '{{.Name}}' | grep portainer | head -n 1)
        docker service scale "${service_name}=0" || handle_command_error "Failed to scale down Portainer service"
        echo "✓ Portainer service scaled down"
        ;;
    "stack")
        echo "Scaling down Portainer stack service..."
        # Find the specific service within the stack
        stack_service_name=$(find_stack_service "$portainer_container")
        if [ -z "$stack_service_name" ]; then
            echo "Error: Could not find Portainer service in stack"
            exit 1
        fi
        docker service scale "${stack_service_name}=0" || handle_command_error "Failed to scale down Portainer stack service"
        echo "✓ Portainer stack service scaled down"
        ;;
    *)
        # Default case: regular container deployment
        echo "Stopping Portainer container..."
        docker stop "$portainer_container" || handle_command_error "Failed to stop Portainer container"
        echo "✓ Portainer container stopped"
        ;;
esac

# Run the password reset helper
echo "Running Portainer password reset helper..."
echo "This may take a few moments..."

# Capture the output from the helper container
# Temporarily disable set -e to capture exit code properly
# The helper container needs access to Portainer's data volume
set +e
reset_output=$(docker run --rm -v "${portainer_volume}:/data" portainer/helper-reset-password 2>&1)
reset_exit_code=$?
set -e

# Check if the password reset helper succeeded
if [ $reset_exit_code -ne 0 ]; then
    echo "Error: Password reset helper failed"
    echo "Output: $reset_output"
    
    # Try to restart Portainer before exiting
    echo "Attempting to restart Portainer..."
    case $deployment_type in
        "service")
            docker service scale "${service_name}=1"
            ;;
        "stack")
            docker service scale "${stack_service_name}=1"
            ;;
        *)
            docker start "$portainer_container"
            ;;
    esac
    exit 1
fi

echo "✓ Password reset helper completed successfully"

# Extract the new password from the helper output
# The helper outputs the password in a specific format
new_password=$(echo "$reset_output" | grep -o "Use the following password to login: .*" | sed 's/Use the following password to login: //')

# Validate that we successfully extracted a password
if [ -z "$new_password" ]; then
    echo "Error: Failed to extract new password from helper output"
    echo "Helper output: $reset_output"
    
    # Try to restart Portainer before exiting
    echo "Attempting to restart Portainer..."
    case $deployment_type in
        "service")
            docker service scale "${service_name}=1"
            ;;
        "stack")
            docker service scale "${stack_service_name}=1"
            ;;
        *)
            docker start "$portainer_container"
            ;;
    esac
    exit 1
fi

# Validate password complexity (security check)
# Ensure the generated password meets expected complexity requirements
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
        "stack")
            docker service scale "${stack_service_name}=1"
            ;;
        *)
            docker start "$portainer_container"
            ;;
    esac
    exit 1
fi

echo "✓ Password validation passed"

# Start Portainer based on deployment type
# Use the same method we used to stop it
case $deployment_type in
    "service")
        echo "Scaling up Portainer service..."
        # Scale service back to 1 replica
        docker service scale "${service_name}=1" || handle_command_error "Failed to scale up Portainer service"
        echo "✓ Portainer service scaled up"
        ;;
    "stack")
        echo "Scaling up Portainer stack service..."
        # Scale stack service back to 1 replica
        docker service scale "${stack_service_name}=1" || handle_command_error "Failed to scale up Portainer stack service"
        echo "✓ Portainer stack service scaled up"
        ;;
    *)
        # Start regular container
        echo "Starting Portainer container..."
        docker start "$portainer_container" || handle_command_error "Failed to start Portainer container"
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