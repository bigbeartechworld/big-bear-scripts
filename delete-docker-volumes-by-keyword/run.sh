#!/bin/bash

# List all Docker volumes
echo "Here are all the available Docker volumes:"
docker volume ls --format '{{.Name}}'

# Provide a blank line for better readability
echo ""

# Prompt the user to enter a word associated with the volumes they want to remove
echo "Enter the keyword associated with the Docker volumes you want to remove:"
read word

# Use the word to filter and remove Docker volumes
docker volume ls --format '{{.Name}}' | grep "$word" | awk '{print $1}' | xargs -r docker volume rm

echo "Volumes associated with '$word' have been removed."
