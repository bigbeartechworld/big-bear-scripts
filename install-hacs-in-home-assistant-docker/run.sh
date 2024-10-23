#!/usr/bin/env bash

# Check if Docker is installed by attempting to run the 'docker' command.
# If Docker is not found, print an error message and exit the script.
if ! command -v docker &> /dev/null; then
    echo "Docker could not be found. Please install Docker first."
    exit 1
fi

# Get a list of all running Docker containers.
# The format "{{.Names}}" specifies that we only want the names of the containers.
# 'mapfile -t CONTAINERS' reads the input into an array named CONTAINERS.
mapfile -t CONTAINERS < <(docker ps --format "{{.Names}}")

# Check if there are any running containers. If not, print an error message and exit.
if [ ${#CONTAINERS[@]} -eq 0 ]; then
    echo "No running containers found."
    exit 1
fi

# Display a prompt for the user to select a Docker container.
# Loop through the CONTAINERS array and print each container with a number prefix.
echo "Please select a Docker container to run the HACS download script in:"
for i in "${!CONTAINERS[@]}"; do
    echo "$((i+1))) ${CONTAINERS[$i]}"
done

# Prompt the user to enter the number of the container they wish to select.
read -p "Enter the number of the container: " USER_CHOICE

# Decrement USER_CHOICE by 1 because array indices start at 0 but we showed the user a list starting at 1.
((USER_CHOICE--))

# Validate the user's selection. If the choice is outside the range of available containers, print an error and exit.
if [ "$USER_CHOICE" -lt 0 ] || [ "$USER_CHOICE" -ge "${#CONTAINERS[@]}" ]; then
    echo "Invalid selection."
    exit 1
fi

# Retrieve the name of the selected container from the CONTAINERS array.
CONTAINER_NAME=${CONTAINERS[$USER_CHOICE]}

# Execute the HACS download script inside the selected Docker container.
# We use 'docker exec' to run commands inside the container.
# The '-it' flags attach us interactively to the container.
# 'bash -c' is used to run the subsequent string as a command in bash inside the container.
docker exec -it $CONTAINER_NAME bash -c "wget -O - https://get.hacs.xyz | bash -"

# Print a confirmation message that the script has been executed in the selected container.
echo "HACS download script has been executed inside the '$CONTAINER_NAME' container."
