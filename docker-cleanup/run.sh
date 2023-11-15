#!/bin/bash

echo "---------------------"
echo "Big Bear Docker Cleanup Script"
echo "---------------------"
echo "Made by BigBearTechWorld"
echo "---------------------"
echo "Like the script? Consider supporting my work at: https://ko-fi.com/bigbeartechworld"
echo "---------------------"

# Function to delete Docker containers
cleanup_containers() {
    echo "Current Docker Containers:"
    docker ps -a
    read -p "Do you want to remove all stopped containers? (y/n): " answer
    if [[ "$answer" == "y" ]]; then
        docker container prune -f
        echo "Stopped containers removed."
    fi
}

# Function to delete Docker images
cleanup_images() {
    echo "Current Docker Images:"
    docker images
    read -p "Do you want to remove unused Docker images? (y/n): " answer
    if [[ "$answer" == "y" ]]; then
        docker image prune -a -f
        echo "Unused images removed."
    fi
}

# Function to delete Docker volumes
cleanup_volumes() {
    echo "Current Docker Volumes:"
    docker volume ls
    read -p "Do you want to remove unused Docker volumes? (y/n): " answer
    if [[ "$answer" == "y" ]]; then
        docker volume prune -f
        echo "Unused volumes removed."
    fi
}

# Function to delete Docker networks
cleanup_networks() {
    echo "Current Docker Networks:"
    docker network ls
    read -p "Do you want to remove unused Docker networks? (y/n): " answer
    if [[ "$answer" == "y" ]]; then
        docker network prune -f
        echo "Unused networks removed."
    fi
}

# Execute cleanup functions
cleanup_containers
cleanup_images
cleanup_volumes
cleanup_networks

echo "Docker cleanup completed."
