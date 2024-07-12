#!/bin/bash

# Check if URL is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <url> [destination_directory]"
    exit 1
fi

URL=$1
FILENAME=$(basename "$URL")
DEFAULT_DESTINATION="/DATA/AppData/big-bear-kiwix-serve/zim"
DESTINATION=${2:-$DEFAULT_DESTINATION}

# Download the file to the home directory
wget -P ~/ "$URL"

# Check if the download was successful
if [ $? -ne 0 ]; then
    echo "Download failed!"
    exit 1
fi

# Create the destination directory if it doesn't exist
mkdir -p "$DESTINATION"

# Move the file to the desired directory
mv ~/"$FILENAME" "$DESTINATION"

# Check if the move was successful
if [ $? -ne 0 ]; then
    echo "Move failed!"
    exit 1
fi

echo "Download and move completed successfully!"
echo "File moved to $DESTINATION"
