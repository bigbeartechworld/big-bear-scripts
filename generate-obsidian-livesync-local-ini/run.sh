#!/bin/bash

# Ask the user for the desired config location
read -p "Enter the location to save the config (default: /DATA/AppData/big-bear-obsidian-livesync/data/local.ini): " location

# If the user doesn't provide a location, default to the specified path
if [ -z "$location" ]; then
    dir_location="/DATA/AppData/big-bear-obsidian-livesync/data"
    file_path="$dir_location/local.ini"
fi

# Check if the config file already exists
if [ -e "$file_path" ]; then
    read -p "Warning: $file_path already exists. Do you want to replace it? (yes/no) " replace
    if [[ "$replace" != "yes" ]]; then
        echo "Operation cancelled."
        exit 1
    fi
fi

# Create the directory (and its parents) if it doesn't exist
mkdir -p "$(dirname "$dir_location")"

# Download the file from the given URL and save it to the specified location
curl -L "https://raw.githubusercontent.com/bigbeartechworld/big-bear-casaos/master/Apps/obsidian-livesync/local.ini" -o "$file_path"

# Confirm to the user
echo "Config saved to $file_path"
