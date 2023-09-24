#!/bin/bash
# This script allows the user to reset their CasaOS username and password.

# Check if the casaos.service is active
if ! systemctl is-active --quiet casaos.service; then
    echo "CasaOS service is not active. Exiting."
    exit 1
fi

# Prompt user for confirmation
read -p "Do you want to reset your CasaOS username and password? (y/n): " response

# Check the user's response
if [[ "$response" != "y" ]]; then
    # If the user does not confirm, print a message and exit the script
    echo "Script execution aborted."
    exit 1
fi

# Check if user.db exists
if [[ ! -f /var/lib/casaos/db/user.db ]]; then
    # If the user database doesn't exist, print a message and exit the script
    echo "user.db does not exist. Exiting."
    exit 1
fi

# Backup user.db by moving it to a backup location
sudo mv /var/lib/casaos/db/user.db /var/lib/casaos/db/user.db.backup

# Restart the casaos user service to reflect the changes
sudo systemctl restart casaos-user-service.service

# Print a success message to the user
echo "Commands executed successfully. Visit CasaOS UI again and the welcome screen should present to reset password."
