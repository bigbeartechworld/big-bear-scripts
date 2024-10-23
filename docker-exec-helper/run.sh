#!/usr/bin/env bash

# List all running containers
containers=$(docker ps --format "{{.Names}}")
IFS=$'\n' read -rd '' -a containerArray <<< "$containers"

echo "Select a Docker container to exec into:"
counter=1
for container in "${containerArray[@]}"; do
    echo "$counter. $container"
    let counter++
done

# Get user's choice
read -p "Enter the number of the container: " choice
selectedContainer="${containerArray[$choice-1]}"

# Check if user wants additional arguments
read -p "Do you want to provide additional arguments? (e.g., -u www-data) [y/N]: " additionalArgsChoice
additionalArgs=""
if [[ $additionalArgsChoice == "y" || $additionalArgsChoice == "Y" ]]; then
    read -p "Enter the additional arguments: " additionalArgs
fi

# Docker exec into the chosen container
docker exec -it $additionalArgs $selectedContainer /bin/bash
