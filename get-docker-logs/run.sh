#!/bin/bash

# Function to combine container info for display
combine_container_info() {
    local id="$1"
    local name="$2"
    local image="$3"

    if [ -z "$name" ]; then
        echo "$id ($image)"
    else
        echo "$name"
    fi
}

# Fetch all containers info, including those that are not running
CONTAINERS=()
while IFS= read -r line; do
    CONTAINERS+=("$line")
done < <(docker ps -a --format "{{.ID}}|{{.Names}}|{{.Image}}" | while IFS="|" read -r id name image; do
    combine_container_info "$id" "$name" "$image"
done)

# Prompt the user to select a container
echo "Select a container to fetch logs:"
select CONTAINER_CHOICE in "${CONTAINERS[@]}"; do
    # Extract the container ID/name from the selected option
    CONTAINER_ID_OR_NAME=$(echo $CONTAINER_CHOICE | awk '{print $1}')

    # Fetch and display the logs for the selected container
    docker logs $CONTAINER_ID_OR_NAME
    break
done
