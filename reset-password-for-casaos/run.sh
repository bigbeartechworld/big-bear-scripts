#!/bin/bash

# Prompt user for confirmation
read -p "Do you want to reset your CasaOS username and password? (y/n): " response

if [[ "$response" != "y" ]]; then
    echo "Please try resetting the username and password first."
    exit 1
fi

# Check if user.db exists
if [[ ! -f /var/lib/casaos/db/user.db ]]; then
    echo "user.db does not exist. Exiting."
    exit 1
fi

# Backup user.db
sudo mv /var/lib/casaos/db/user.db /var/lib/casaos/db/user.db.backup

# Restart casaos-user-service
sudo systemctl restart casaos-user-service.service

echo "Commands executed successfully. Visit CasaOS UI again and the welcome screen should present to reset password."
