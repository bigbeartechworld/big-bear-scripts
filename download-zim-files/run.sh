#!/bin/bash

MESSAGE="Made by BigBearTechWorld"

# Function to print a decorative line
print_decorative_line() {
    printf "%s\n" "------------------------------------------------------"
}

# Print the introduction message with decorations
echo
print_decorative_line
echo "Big Bear Download ZIM Files Script"
print_decorative_line
echo
echo "$MESSAGE"
echo
print_decorative_line
echo
echo "If this is useful, please consider supporting my work at: https://ko-fi.com/bigbeartechworld"
echo
print_decorative_line

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

# Get the path to the docker-compose.yml file
COMPOSE_FILE="/var/lib/casaos/apps/big-bear-kiwix-serve/docker-compose.yml"

# Apply changes using casaos-cli
casaos-cli app-management apply "big-bear-kiwix-serve" --file="$COMPOSE_FILE"

echo "Applying changes to big-bear-kiwix-serve..."

echo "Script execution completed."
