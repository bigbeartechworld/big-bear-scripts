#!/bin/bash

# Ask the user for the desired config location
read -p "Enter the location to save the config (default: /DATA/AppData/big-bear-dashy/public/conf.yml): " location

# If the user doesn't provide a location, default to the specified path
if [ -z "$location" ]; then
    location="/DATA/AppData/big-bear-dashy/public/conf.yml"
fi

# Check if the config file already exists
if [ -e "$location" ]; then
    read -p "Warning: $location already exists. Do you want to replace it? (yes/no) " replace
    if [[ "$replace" != "yes" ]]; then
        echo "Operation cancelled."
        exit 1
    fi
fi

# Create the directory (and its parents) if it doesn't exist
mkdir -p "$(dirname "$location")"

# Download the file from the given URL and save it to the specified location
curl -L "https://gist.githubusercontent.com/Lissy93/000f712a5ce98f212817d20bc16bab10/raw/b08f2473610970c96d9bc273af7272173aa93ab1/Example%25201%2520-%2520Getting%2520Started%2520-%2520conf.yml" -o "$location"

# Confirm to the user
echo "Config saved to $location"
