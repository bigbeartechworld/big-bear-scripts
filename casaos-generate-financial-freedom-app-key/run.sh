#!/bin/bash

# Access the Docker container and run the command
key=$(docker exec big-bear-financial-freedom php artisan key:generate --show)

# Check if the key was successfully retrieved
if [ -z "$key" ]; then
    echo "Failed to retrieve key."
    exit 1
fi

# File to be modified
file_path="/var/lib/casaos/apps/big-bear-financial-freedom/docker-compose.yml"

# Backup the original file (optional but recommended)
cp "$file_path" "${file_path}.bak"

# Use sed to replace the string
sed -i "s/base64:1234567890abcdefghijklmnopqrstuvwxyz/${key}/g" "$file_path"

# Reload the container with CasaOS CLI
casaos-cli app-management apply "big-bear-financial-freedom" --file="$file_path"

echo "Key replaced and container reloaded successfully."
