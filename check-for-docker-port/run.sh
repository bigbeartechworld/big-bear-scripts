#!/usr/bin/env bash

# Function to check if jq is installed
check_jq_installed() {
  if ! command -v jq &> /dev/null; then
    echo "jq is required but it's not installed. Would you like to install it now? (yes/no)"
    read answer
    if [[ "$answer" == "yes" ]]; then
      if [ -x "$(command -v apt-get)" ]; then
        sudo apt-get update && sudo apt-get install -y jq
      elif [ -x "$(command -v yum)" ]; then
        sudo yum install -y jq
      else
        echo "Package manager not supported. Please install jq manually."
        exit 1
      fi
    else
      echo "jq is not installed. Exiting."
      exit 1
    fi
  fi
}

# Check if jq is installed
check_jq_installed

# Check if a port number is provided as an argument
if [ -z "$1" ]; then
  read -p "Enter the port number to search for: " port
else
  port=$1
fi

# Check if the input is a valid number
if ! [[ "$port" =~ ^[0-9]+$ ]]; then
  echo "Invalid port number. Please enter a valid number."
  exit 1
fi

# Iterate through all containers and check if the specified port is used
echo "Searching for containers using port $port..."
for container in $(sudo docker ps -a -q); do
  if sudo docker inspect $container | jq -e --arg port "$port/tcp" '.[0].NetworkSettings.Ports | has($port)'; then
    status=$(sudo docker inspect -f '{{.State.Status}}' $container)
    echo "Container ID $container is configured to use port $port and is currently $status"
  fi
done

echo "Search completed."
