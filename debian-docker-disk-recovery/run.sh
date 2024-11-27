#!/bin/bash

# Debian Docker Disk Recovery Tool v1.0.0
# Run with sudo permissions
# Support: https://ko-fi.com/bigbeartechworld

# Set text colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print header
print_header() {
    echo "================================================"
    echo -e "${GREEN}Debian Docker Disk Recovery Tool v1.0.0${NC}"
    echo -e "${YELLOW}Support: https://ko-fi.com/bigbeartechworld${NC}"
    echo "================================================"
    echo "Here are some links:"
    echo -e "${GREEN}https://community.bigbeartechworld.com${NC}"
    echo -e "${GREEN}https://github.com/BigBearTechWorld${NC}"
    echo "================================================"
    echo
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

# Function to check available space in root partition
check_space() {
    local available_space=$(df / | awk 'NR==2 {print $4}')
    echo $available_space
}

# Function to display human-readable disk usage
show_disk_usage() {
    echo "Current disk usage:"
    df -h /
}

# Function to ask user for confirmation
confirm_action() {
    read -p "$1 (y/n): " response
    case "$response" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# Function to try starting Docker
try_start_docker() {
    echo "Attempting to start Docker..."
    if systemctl start docker; then
        echo "Success! Docker has been started."
        systemctl status docker
        echo -e "\nRecommended next steps:"
        echo "1. Run our Docker cleanup script to free up more space:"
        echo "   bash -c \"\$(wget -qLO - https://raw.githubusercontent.com/bigbeartechworld/big-bear-scripts/master/docker-cleanup/run.sh)\""
        echo "2. Or manually run these commands:"
        echo "   - 'docker system prune' to remove unused data"
        echo "   - 'docker volume prune' to remove unused volumes"
        echo "3. Monitor disk space with 'df -h'"
        return 0
    fi
    return 1
}

# Function to install Docker
install_docker() {
    # Check if Docker is installed via Snap
    if command -v snap >/dev/null && snap list docker &> /dev/null; then
        echo "Docker is installed via Snap."
        if confirm_action "Do you want to uninstall the Snap version of Docker?"; then
            echo "Uninstalling Docker from Snap..."
            snap remove docker
        else
            echo "Skipping Docker uninstallation from Snap."
            return 1
        fi
    fi

    # Update package database
    echo "Updating package database..."
    apt-get update

    # Install prerequisites
    echo "Installing prerequisites..."
    apt-get install -y \
         apt-transport-https \
         ca-certificates \
         curl \
         gnupg \
         lsb-release

    # Add Docker's official GPG key
    echo "Adding Docker's official GPG key..."
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # Set up the stable repository
    echo "Setting up Docker repository..."
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    echo "Installing Docker Engine..."
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io

    # Verify Docker installation
    echo "Verifying Docker installation..."
    docker run hello-world

    # Ask if the user wants to install Docker Compose
    if confirm_action "Do you want to install Docker Compose?"; then
        echo "Installing Docker Compose..."
        curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        echo "Docker Compose installed successfully."
    else
        echo "Skipping Docker Compose installation."
    fi

    echo "Docker installation completed successfully!"
    return 0
}

# Function to cleanup Docker resources
cleanup_docker() {
    # Initialize counters
    local CONTAINERS_REMOVED=0
    local IMAGES_REMOVED=0
    local VOLUMES_REMOVED=0
    local NETWORKS_REMOVED=0

    echo "Starting Docker cleanup process..."
    
    # Cleanup containers
    echo "Current Docker Containers:"
    docker ps -a
    if confirm_action "Would you like to remove all stopped containers?"; then
        CONTAINERS_REMOVED=$(docker container prune -f | grep -oP '(?<=Deleted Containers: )\d+' || echo "0")
        echo "Stopped containers removed."
    fi

    # Cleanup images
    echo "Current Docker Images:"
    docker images
    if confirm_action "Would you like to remove unused Docker images?"; then
        IMAGES_REMOVED=$(docker image prune -a -f | grep -oP '(?<=Total reclaimed space: )\S+' || echo "0B")
        echo "Unused images removed."
    fi

    # Cleanup volumes
    echo "Current Docker Volumes:"
    docker volume ls
    if confirm_action "Would you like to remove unused Docker volumes?"; then
        VOLUMES_REMOVED=$(docker volume prune -f | grep -oP '(?<=Total reclaimed space: )\S+' || echo "0B")
        echo "Unused volumes removed."
    fi

    # Cleanup networks
    echo "Current Docker Networks:"
    docker network ls
    if confirm_action "Would you like to remove unused Docker networks?"; then
        NETWORKS_REMOVED=$(docker network prune -f | grep -oP '(?<=Deleted Networks: )\d+' || echo "0")
        echo "Unused networks removed."
    fi

    # Print cleanup statistics
    echo "---------------------"
    echo "Docker Cleanup Statistics"
    echo "---------------------"
    echo "Containers removed: $CONTAINERS_REMOVED"
    echo "Images removed: $IMAGES_REMOVED"
    echo "Volumes removed: $VOLUMES_REMOVED"
    echo "Networks removed: $NETWORKS_REMOVED"
    echo "---------------------"
}

print_header
echo "Starting interactive disk space recovery for Docker..."
show_disk_usage

# Try to start Docker first to see if it works
if try_start_docker; then
    exit 0
fi

# Step 1: Clear journal logs
if confirm_action "Would you like to clear system journal logs?"; then
    echo "Clearing system journal logs..."
    journalctl --vacuum-time=1d
    show_disk_usage
    if try_start_docker; then
        exit 0
    fi
fi

# Step 2: Clean package manager cache
if confirm_action "Would you like to clean package manager cache?"; then
    echo "Cleaning package manager cache..."
    apt-get clean
    apt-get autoremove -y
    show_disk_usage
    if try_start_docker; then
        exit 0
    fi
fi

# Step 3: Clean up old Docker logs
if confirm_action "Would you like to clean up Docker container logs?"; then
    echo "Cleaning up Docker container logs..."
    find /var/lib/docker/containers/ -type f -name "*.log" -exec truncate -s 0 {} \;
    show_disk_usage
    if try_start_docker; then
        exit 0
    fi
fi

# Step 4: Remove old container logs one by one
if confirm_action "Would you like to review and clean individual container logs?"; then
    for container_dir in /var/lib/docker/containers/*; do
        if [ -d "$container_dir" ]; then
            container_id=$(basename "$container_dir")
            log_size=$(du -h "$container_dir"/*-json.log 2>/dev/null | cut -f1)
            if [ ! -z "$log_size" ]; then
                if confirm_action "Container $container_id has log size $log_size. Clear it?"; then
                    truncate -s 0 "$container_dir"/*-json.log
                    show_disk_usage
                    if try_start_docker; then
                        exit 0
                    fi
                fi
            fi
        fi
    done
fi

echo "Docker still cannot start. You might need to:"
echo "1. Check Docker logs: journalctl -u docker"
echo "2. Consider more aggressive cleanup options"
echo "3. Add more disk space to the system"

# Try Docker cleanup if it's running
if systemctl is-active docker >/dev/null 2>&1; then
    if confirm_action "Would you like to perform Docker cleanup?"; then
        cleanup_docker
    fi
fi

# Ask if user wants to reinstall Docker
if confirm_action "Would you like to reinstall Docker?"; then
    echo "Proceeding with Docker installation..."
    if install_docker; then
        echo "Docker has been successfully reinstalled!"
    else
        echo "Docker installation was not completed. Please check the errors above."
    fi
fi
