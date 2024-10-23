#!/usr/bin/env bash

# Default URL of the file to download
default_url="https://raw.githubusercontent.com/codex-team/codex.docs/main/docs-config.yaml"

# Ask the user for the URL
read -p "Enter the URL (default: $default_url): " url

# If the user did not enter a URL, use the default URL
if [ -z "$url" ]; then
  url="$default_url"
fi

# Default local path where the file should be copied
default_dest="/DATA/AppData/big-bear-codex-docs/codex-docs-config.local.yaml"

# Ask the user for the destination path
read -p "Enter the destination path (default: $default_dest): " dest

# If the user did not enter a path, use the default path
if [ -z "$dest" ]; then
  dest="$default_dest"
fi

# Create the directory if it does not exist
dir=$(dirname "$dest")
mkdir -p "$dir"

# Use curl to download the file from the URL and save it to the destination path
curl -o "$dest" "$url"

# Check if the operation was successful
if [ $? -eq 0 ]; then
  echo "File copied successfully to $dest"
else
  echo "File copy failed"
fi
