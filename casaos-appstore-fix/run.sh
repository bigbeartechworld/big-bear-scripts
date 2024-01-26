#!/bin/bash

# Register the new app store
echo "Registering the new app store..."
casaos-cli app-management register app-store https://github.com/IceWhaleTech/CasaOS-AppStore/archive/19b9149ce0bd50ffb8c898e283dc441605a3a369.zip

# Initial delay for the registration process
echo "Waiting for the new app store to register..."
sleep 30

# Function to find and unregister the main app store based on its URL
unregisterMainAppStore() {
    echo "Searching for the main app store..."

    # Get the list of app stores, search for the URL, and extract the ID
    while IFS=' ' read -r id url _; do
        if [[ $url == *"https://github.com/IceWhaleTech/CasaOS-AppStore/archive/refs/heads/main.zip"* ]]; then
            echo "Main app store found with ID $id. Unregistering..."
            casaos-cli app-management unregister app-store "$id"
            echo "Main app store with ID $id unregistered successfully."
            return
        fi
    done < <(casaos-cli app-management list app-stores | grep -v "ID   URL" | awk '{print $1 " " $2}')

    echo "Main app store not found."
}

# Function to check if the new app store has been registered
checkAndUnregister() {
    while true; do
        # List the current app stores to check if the new one has been registered
        output=$(casaos-cli app-management list app-stores)

        echo "$output"

        # Check if the new app store is listed
        if echo "$output" | grep -q "19b9149ce0bd50ffb8c898e283dc441605a3a369"; then
            echo "New app store registered successfully."

            # Unregister the old app store
            echo "Unregistering the old app store..."
            unregisterMainAppStore
            break
        else
            echo "New app store not yet registered, waiting..."
            sleep 15
        fi
    done
}

# Call the function to check and unregister the old app store
checkAndUnregister

echo "App store fix completed."
