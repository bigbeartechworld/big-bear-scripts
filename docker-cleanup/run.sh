#!/usr/bin/env bash

set -e

# Initialize variables
VERBOSE=false
DRY_RUN=false

# Initialize counters
CONTAINERS_REMOVED=0
IMAGES_REMOVED=0
VOLUMES_REMOVED=0
NETWORKS_REMOVED=0

# Function to print verbose messages
print_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo "$1"
    fi
}

# Check if Docker is installed and running. If not, print an error message and exit.
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Docker is not installed. Please install Docker and try again."
        exit 1
    fi

    if ! docker info &> /dev/null; then
        echo "Docker daemon is not running. Please start Docker and try again."
        exit 1
    fi
}

# Delete stopped Docker containers.
cleanup_containers() {
    echo "Current Docker Containers:"
    docker ps -a
    if [ "$DRY_RUN" = false ]; then
        read -p "Do you want to remove all stopped containers? (y/n): " answer
        if [[ "$answer" == "y" ]]; then
            CONTAINERS_REMOVED=$(docker container prune -f | grep -oP '(?<=Deleted Containers: )\d+' || echo "0")
            echo "Stopped containers removed."
        fi
    else
        echo "[DRY RUN] Would remove stopped containers."
    fi
}

# Delete unused Docker images.
cleanup_images() {
    echo "Current Docker Images:"
    docker images
    if [ "$DRY_RUN" = false ]; then
        read -p "Do you want to remove unused Docker images? (y/n): " answer
        if [[ "$answer" == "y" ]]; then
            IMAGES_REMOVED=$(docker image prune -a -f | grep -oP '(?<=Total reclaimed space: )\S+' || echo "0B")
            echo "Unused images removed."
        fi
    else
        echo "[DRY RUN] Would remove unused Docker images."
    fi
}

# Delete unused Docker volumes.
cleanup_volumes() {
    echo "Current Docker Volumes:"
    docker volume ls
    if [ "$DRY_RUN" = false ]; then
        read -p "Do you want to remove unused Docker volumes? (y/n): " answer
        if [[ "$answer" == "y" ]]; then
            VOLUMES_REMOVED=$(docker volume prune -f | grep -oP '(?<=Total reclaimed space: )\S+' || echo "0B")
            echo "Unused volumes removed."
        fi
    else
        echo "[DRY RUN] Would remove unused Docker volumes."
    fi
}

# Delete unused Docker networks.
cleanup_networks() {
    echo "Current Docker Networks:"
    docker network ls
    if [ "$DRY_RUN" = false ]; then
        read -p "Do you want to remove unused Docker networks? (y/n): " answer
        if [[ "$answer" == "y" ]]; then
            NETWORKS_REMOVED=$(docker network prune -f | grep -oP '(?<=Deleted Networks: )\d+' || echo "0")
            echo "Unused networks removed."
        fi
    else
        echo "[DRY RUN] Would remove unused Docker networks."
    fi
}

# Print a summary of the results from the cleanup process.
print_stats() {
    echo "---------------------"
    echo "Big Bear Docker Cleanup Statistics"
    echo "---------------------"
    echo "Containers removed: $CONTAINERS_REMOVED"
    echo "Images removed: $IMAGES_REMOVED"
    echo "Volumes removed: $VOLUMES_REMOVED"
    echo "Networks removed: $NETWORKS_REMOVED"
    echo "---------------------"
}

# Print the help message for the script
print_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -v, --verbose  Enable verbose mode"
    echo "  -d, --dry-run  Perform a dry run (don't actually remove resources)"
    echo "  -h, --help     Display this help message"
}

# Main entry point for the script.
main() {
    echo "---------------------"
    echo "Big Bear Docker Cleanup Script V2"
    echo "---------------------"
    echo "Made by BigBearTechWorld"
    echo "---------------------"
    echo "Like the script? Consider supporting my work at: https://ko-fi.com/bigbeartechworld"
    echo "---------------------"
    check_docker

    if [ "$DRY_RUN" = false ]; then
        read -p "This will remove Docker resources. Are you sure you want to proceed? (y/n): " confirm
        if [[ "$confirm" != "y" ]]; then
            echo "Operation cancelled."
            exit 0
        fi
    fi

    cleanup_containers
    cleanup_images
    cleanup_volumes
    cleanup_networks

    echo "Docker cleanup completed."
    print_stats
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -v|--verbose) VERBOSE=true ;;
        -d|--dry-run) DRY_RUN=true ;;
        -h|--help) print_help; exit 0 ;;
        *) echo "Unknown parameter passed: $1"; print_help; exit 1 ;;
    esac
    shift
done

# Run the main function
main
