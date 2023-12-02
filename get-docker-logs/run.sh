#!/bin/bash

# Function to combine container info for display
combine_container_info() {
    # Function to combine container information

    # Parameters:
    #   $1: id - The container id
    #   $2: name - The container name
    #   $3: image - The container image

    local id="$1"
    local name="$2"
    local image="$3"

    # Check if name is empty
    if [ -z "$name" ]; then
        echo "$id ($image)"  # Print container id and image if name is empty
    else
        echo "$name"  # Print container name if it is not empty
    fi
}

# Fetch all containers info, including those that are not running
CONTAINERS=()

# Read container information from docker command output
while IFS= read -r line; do
    CONTAINERS+=("$line")
done < <(
    # Get container information from docker ps command
    docker ps -a --format "{{.ID}}|{{.Names}}|{{.Image}}" | while IFS="|" read -r id name image; do
        # Call the combine_container_info function
        combine_container_info "$id" "$name" "$image"
    done
)

# Prompt the user to select a container
echo "Select a container to fetch logs:"

# Loop through the available container options
select CONTAINER_CHOICE in "${CONTAINERS[@]}"; do
    # Extract the container ID/name from the selected option
    CONTAINER_ID_OR_NAME=$(echo $CONTAINER_CHOICE | awk '{print $1}')

    # Fetch and display the logs for the selected container
    docker logs $CONTAINER_ID_OR_NAME

    # Break out of the loop after fetching and displaying the logs
    break
done
