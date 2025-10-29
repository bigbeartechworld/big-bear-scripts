#!/usr/bin/env bash

# Define a message for branding purposes
MESSAGE="Made by BigBearTechWorld"

# Function to print a decorative line
print_decorative_line() {
    # Prints a line of dashes to the console
    printf "%s\n" "------------------------------------------------------"
}

# Print the introduction message with decorations
echo
print_decorative_line
echo "Setup Invoice Ninja for CasaOS Step 1"
print_decorative_line
echo
echo "$MESSAGE"
echo
print_decorative_line
echo
echo "If this is useful, please consider supporting my work at: https://ko-fi.com/bigbeartechworld"
echo
print_decorative_line

# Define base directory for the AppData
BASE_DIR="/DATA/AppData/big-bear-invoice-ninja/data"

# Define the URLs for the files
URLS=(
    "https://raw.githubusercontent.com/bigbeartechworld/big-bear-universal-apps/refs/heads/main/apps/invoice-ninja/data/init/init.sh"
    "https://raw.githubusercontent.com/bigbeartechworld/big-bear-universal-apps/refs/heads/main/apps/invoice-ninja/data/nginx/invoice-ninja.conf"
    "https://raw.githubusercontent.com/bigbeartechworld/big-bear-universal-apps/refs/heads/main/apps/invoice-ninja/data/php/php-cli.ini"
    "https://raw.githubusercontent.com/bigbeartechworld/big-bear-universal-apps/refs/heads/main/apps/invoice-ninja/data/php/php.ini"
)

# Define the local paths where the files will be saved
PATHS=(
    "$BASE_DIR/init/init.sh"
    "$BASE_DIR/nginx/invoice-ninja.conf"
    "$BASE_DIR/php/php-cli.ini"
    "$BASE_DIR/php/php.ini"
)

# Create necessary directories
mkdir -p "$BASE_DIR/init"
mkdir -p "$BASE_DIR/nginx"
mkdir -p "$BASE_DIR/php"
mkdir -p "$BASE_DIR/public"
mkdir -p "$BASE_DIR/storage"
mkdir -p "$BASE_DIR/mysql"

# Download and place each file
for i in "${!URLS[@]}"; do
    echo "Downloading ${URLS[i]}..."
    if curl -L "${URLS[i]}" -o "${PATHS[i]}" --fail --silent --show-error; then
        if [ -f "${PATHS[i]}" ]; then
            chmod +x "${PATHS[i]}" # Make file executable
            echo "Successfully saved to ${PATHS[i]}"
        else
            echo "Error: ${PATHS[i]} is not a file. It might be a directory."
        fi
    else
        echo "Error downloading ${URLS[i]}"
    fi
done

echo "All files have been downloaded and placed in the bind paths."

echo "Setup complete."

# Verification step
echo
print_decorative_line
echo "Verifying downloaded files:"
print_decorative_line

for path in "${PATHS[@]}"; do
    if [ -f "$path" ]; then
        echo "✅ $path exists and is a file."
    elif [ -d "$path" ]; then
        echo "❌ Error: $path is a directory, not a file."
    else
        echo "❌ Error: $path does not exist."
    fi
done

print_decorative_line
echo "Verification complete."
print_decorative_line
