#!/usr/bin/env bash

# Ask the user for the desired config location
read -p "Enter the location to save the config (default: /DATA/AppData/unifi-network-application/db/init-mongo.js): " location

# If the user doesn't provide a location, default to the specified path
if [ -z "$location" ]; then
    location="/DATA/AppData/unifi-network-application/db/init-mongo.js"
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
if ! curl -L "https://raw.githubusercontent.com/bigbeartechworld/big-bear-video-assets/main/how-to-install-unifi-network-application-on-portainer/init-mongo.js" -o "$location"; then
    echo "Error downloading the file. Check your Internet connection or the URL."
    exit 1
fi

# Confirm to the user
echo "Config saved to $location"
