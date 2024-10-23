#!/usr/bin/env bash
# This script allows the user to reset their CasaOS username and password.

# Function to print headers
print_header() {
    echo "========================================"
    echo "  $1"
    echo "========================================"
}

# Function to check if a service is active
check_service() {
    if ! systemctl is-active --quiet "$1"; then
        echo "Error: $1 service is not active. Please ensure CasaOS is properly installed and running."
        exit 1
    fi
}

# Function to backup the user database
backup_user_db() {
    local backup_file="/var/lib/casaos/db/user.db.backup_$(date +%Y%m%d_%H%M%S)"
    if sudo cp /var/lib/casaos/db/user.db "$backup_file"; then
        echo "User database backed up to $backup_file"
    else
        echo "Error: Failed to backup user database. Aborting."
        exit 1
    fi
}

# Check if script is run with sudo
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run with sudo privileges. Aborting."
   exit 1
fi

# Display Welcome
print_header "BigBearCasaOS Password Reset V2.0"
echo "Here are some links:"
echo "https://community.bigbeartechworld.com"
echo "https://github.com/BigBearTechWorld"
echo ""
echo "If you would like to support me, please consider buying me a tea:"
echo "https://ko-fi.com/bigbeartechworld"
echo ""

# Check if the casaos service is active
check_service "casaos.service"

# Prompt user for confirmation
read -p "Do you want to reset your CasaOS username and password? (y/N): " response

# Check the user's response
if [[ "${response,,}" != "y" ]]; then
    echo "Operation cancelled by user. Exiting."
    exit 0
fi

# For some systems, if user.db is not found
if [[ ! -f /var/lib/casaos/db/user.db ]]; then
    echo "Warning: user.db not found. Attempting alternative method for some systems."

    # Check if the file exists
    if ls /var/lib/casaos/db/user.db &> /dev/null; then
        echo "user.db found. Proceeding with backup and restart."
        sudo mv /var/lib/casaos/db/user.db /var/lib/casaos/db/user.db.backup
        sudo systemctl restart casaos-user-service.service
        echo "CasaOS user service restarted. Please check if the issue is resolved."
    else
        echo "Error: user.db still not found. Please ensure CasaOS is properly installed on your Debian system."
        exit 1
    fi
fi

# Backup user.db
backup_user_db

# Remove the original user.db
if ! sudo rm /var/lib/casaos/db/user.db; then
    echo "Error: Failed to remove original user.db. Aborting."
    exit 1
fi

# Restart the casaos user service to reflect the changes
if sudo systemctl restart casaos-user-service.service; then
    echo "CasaOS user service restarted successfully."
else
    echo "Error: Failed to restart CasaOS user service. Please check the system logs."
    exit 1
fi

# Print a success message to the user
print_header "Success"
echo "Password reset process completed successfully."
echo "Please visit the CasaOS UI. You should see the welcome screen to set up a new username and password."
