#!/usr/bin/env bash

# Function to install Edge Appstore
installEdgeAppstore() {
    # Register the big-bear-casaos Appstore
    casaos-cli app-management register app-store https://github.com/bigbeartechworld/big-bear-casaos/archive/refs/heads/master.zip

    # Unregister the Official CasaOS Appstore
    casaos-cli app-management unregister app-store 0

    # Register the Edge Appstore
    casaos-cli app-management register app-store https://github.com/WisdomSky/CasaOS-AppStore-Edge/archive/refs/heads/main.zip
}

# Function to revert to the Official Appstore
revertToOfficialAppstore() {
    # Get the ID of the Edge Appstore
    edge_appstore_id=$(casaos-cli app-management list app-stores | grep -i "edge" | awk '{print $1}')

    # Check if Edge Appstore ID was found
    if [ -z "$edge_appstore_id" ]; then
        echo "Error: Could not find CasaOS Edge Appstore ID."
        exit 1
    fi

    # Unregister the Edge Appstore
    casaos-cli app-management unregister app-store "$edge_appstore_id"

    # Register the Official CasaOS Appstore
    casaos-cli app-management register app-store https://github.com/IceWhaleTech/CasaOS-AppStore/archive/refs/heads/main.zip
}

# Check if Edge Appstore is already installed
isEdgeInstalled=$(casaos-cli app-management list app-stores | grep -i "edge")

if [ -z "$isEdgeInstalled" ]; then
    # Edge Appstore is not installed
    installEdgeAppstore
else
    # Edge Appstore is already installed
    read -p "Do you want to revert to the Official CasaOS Appstore? (y/n): " choice
    case "$choice" in
        y|Y ) revertToOfficialAppstore ;;
        n|N ) echo "Keeping the Edge Appstore." ;;
        * ) echo "Invalid choice. Exiting." ;;
    esac
fi

echo "Done."
