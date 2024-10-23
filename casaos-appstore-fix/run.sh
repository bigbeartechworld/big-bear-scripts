#!/usr/bin/env bash

# URLs for the app stores
NEW_APP_STORE_URL="https://github.com/IceWhaleTech/CasaOS-AppStore/archive/19b9149ce0bd50ffb8c898e283dc441605a3a369.zip"
MAIN_APP_STORE_URL="https://github.com/IceWhaleTech/CasaOS-AppStore/archive/refs/heads/main.zip"

# Function to find and unregister an app store based on its URL
unregisterAppStoreByUrl() {
    local storeUrl=$1
    echo "Searching for the app store with URL: $storeUrl..."

    while IFS=' ' read -r id url _; do
        if [[ $url == *"$storeUrl"* ]]; then
            echo "App store found with ID $id. Unregistering..."
            casaos-cli app-management unregister app-store "$id"
            echo "App store with ID $id unregistered successfully."
            return
        fi
    done < <(casaos-cli app-management list app-stores | grep -v "ID   URL" | awk '{print $1 " " $2}')

    echo "App store with the specified URL not found."
}

# Check if the new app store is registered
output=$(casaos-cli app-management list app-stores)

if echo "$output" | grep -q "$NEW_APP_STORE_URL"; then
    echo "New app store is already registered."
    read -p "Do you want to install the main app store? (y/n): " answer
    if [[ $answer =~ ^[Yy]$ ]]; then
        casaos-cli app-management register app-store "$MAIN_APP_STORE_URL"
        echo "Main app store registered. Waiting for confirmation..."
        sleep 15
        unregisterAppStoreByUrl "$NEW_APP_STORE_URL"
    fi
else
    echo "New app store is not registered."
    read -p "Do you want to install the new app store? (y/n): " answer
    if [[ $answer =~ ^[Yy]$ ]]; then
        casaos-cli app-management register app-store "$NEW_APP_STORE_URL"
        echo "New app store registered. Unregistering the main app store..."
        sleep 15
        unregisterAppStoreByUrl "$MAIN_APP_STORE_URL"
    fi
fi

echo "Operation completed."
