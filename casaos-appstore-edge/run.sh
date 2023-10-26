#!/bin/bash

# Function to install Edge Appstore
install_edge_appstore() {
    # Unregister the Official CasaOS Appstore
    echo "Unregistering CasaOS Edge Appstore..."
    casaos-cli app-management unregister app-store 0

    # Register the Edge Appstore
    echo "Installing CasaOS Edge Appstore..."
    casaos-cli app-management register app-store https://casaos-appstore.paodayag.dev/edge.zip
    echo "CasaOS Edge Appstore installed."
}

# Function to revert to the Official Appstore
revert_to_official_appstore() {
    edge_appstore_id=$(casaos-cli app-management list app-stores | grep -i "edge" | awk '{print $1}')

    if [ -z "$edge_appstore_id" ]; then
        echo "Error: Could not find CasaOS Edge Appstore ID."
        exit 1
    fi

    echo "Unregistering CasaOS Edge Appstore with ID: $edge_appstore_id..."
    casaos-cli app-management unregister app-store "$edge_appstore_id"

    echo "Registering the Official CasaOS Appstore..."
    casaos-cli app-management register app-store https://github.com/IceWhaleTech/CasaOS-AppStore/archive/refs/heads/main.zip
    echo "Switched back to the Official CasaOS Appstore."
}

# Check if Edge Appstore is already installed
is_edge_installed=$(casaos-cli app-management list app-stores | grep -i "edge")

if [ -z "$is_edge_installed" ]; then
    # Edge Appstore is not installed
    install_edge_appstore
else
    # Edge Appstore is already installed
    echo "CasaOS Edge Appstore is already installed."
    read -p "Do you want to revert to the Official CasaOS Appstore? (y/n): " choice
    case "$choice" in
        y|Y ) revert_to_official_appstore ;;
        n|N ) echo "Keeping the Edge Appstore." ;;
        * ) echo "Invalid choice. Exiting." ;;
    esac
fi

echo "Done."
