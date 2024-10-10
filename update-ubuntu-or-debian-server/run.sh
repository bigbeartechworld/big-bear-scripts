#!/bin/bash

# Define a message for branding purposes
MESSAGE="Made by BigBearTechWorld"

# Set up logging
LOG_FILE="/var/log/big-bear-update-ubuntu-server.log"

# Function for logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to print a decorative line
print_decorative_line() {
    printf "%s\n" "------------------------------------------------------"
}

# Print the introduction message with decorations
echo
print_decorative_line
echo "Update Ubuntu/Debian Server Script"
print_decorative_line
echo
echo "$MESSAGE"
echo
print_decorative_line
echo
echo "If this is useful, please consider supporting my work at: https://ko-fi.com/bigbeartechworld"
echo
print_decorative_line

# Check if --unattended flag is passed
if [[ "$1" == "--unattended" ]]; then
    unattended=true
else
    unattended=false
fi

# Function to prompt the user
prompt_user() {
    if [ "$unattended" = true ]; then
        return 0  # Automatically proceed in unattended mode
    fi

    echo "$1 (y/n): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0  # Proceed
    else
        return 1  # Skip
    fi
}

# Check OS compatibility
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        log "This script is intended for Ubuntu or Debian. Detected OS: $ID"
        exit 1
    fi
else
    log "Unable to determine OS. This script is intended for Ubuntu or Debian."
    exit 1
fi

# Function to check disk space
check_disk_space() {
    df -h / | awk 'NR==2 {print $5}' | sed 's/%//'
}

# Function to check and hold back problematic packages
check_problematic_packages() {
    problematic_packages=("package1" "package2") # Add known problematic packages here
    for package in "${problematic_packages[@]}"; do
        if dpkg -l | grep -q "^ii  $package "; then
            log "Holding back potentially problematic package: $package"
            sudo apt-mark hold "$package"
        fi
    done
}

# Explain the script's function if not running in unattended mode
if [ "$unattended" = false ]; then
    log "This script will help you update and maintain your Ubuntu/Debian server."
    log "You will be prompted to confirm each step before proceeding."
    log "To run this script in unattended mode without prompts, run it with the --unattended option."
fi

initial_space=$(check_disk_space)
log "Initial disk space used: $initial_space%"

updated_package_list=false
upgraded_packages=false
full_upgrade_done=false
removed_unnecessary=false
cache_cleaned=false

# Step 1: Update the package list
if prompt_user "Do you want to update the package list?"; then
    log "Updating package list..."
    if ! sudo apt update; then
        log "ERROR: Failed to update package list"
        exit 1
    fi
    log "Package list updated successfully"
    updated_package_list=true
else
    log "Skipping package list update."
fi

# Step 2: Upgrade installed packages
if prompt_user "Do you want to upgrade installed packages?"; then
    log "Upgrading installed packages..."
    if ! sudo apt upgrade -y; then
        log "ERROR: Failed to upgrade packages"
        exit 1
    fi
    log "Installed packages upgraded successfully"
    upgraded_packages=true
else
    log "Skipping installed package upgrade."
fi

# Step 3: Perform full upgrade
if prompt_user "Do you want to perform a full upgrade?"; then
    log "Performing a full upgrade..."
    if ! sudo apt full-upgrade -y; then
        log "ERROR: Failed to perform full upgrade"
        exit 1
    fi
    log "Full upgrade completed successfully"
    full_upgrade_done=true
else
    log "Skipping full upgrade."
fi

# Step 4: Remove unnecessary packages
if prompt_user "Do you want to remove unnecessary packages?"; then
    log "Removing unnecessary packages..."
    if ! sudo apt autoremove -y; then
        log "ERROR: Failed to remove unnecessary packages"
        exit 1
    fi
    log "Unnecessary packages removed successfully"
    removed_unnecessary=true
else
    log "Skipping unnecessary package removal."
fi

# Step 5: Clean up package files
if prompt_user "Do you want to clean up cached package files?"; then
    log "Cleaning up cached package files..."
    if ! sudo apt clean; then
        log "ERROR: Failed to clean cached package files"
        exit 1
    fi
    log "Cached package files cleaned successfully"
    cache_cleaned=true
else
    log "Skipping cache cleanup."
fi

# Check problematic packages
check_problematic_packages

# Print summary
print_summary() {
    log "Update Summary:"
    log "- Package list updated: $updated_package_list"
    log "- Packages upgraded: $upgraded_packages"
    log "- Full upgrade performed: $full_upgrade_done"
    log "- Unnecessary packages removed: $removed_unnecessary"
    log "- Cache cleaned: $cache_cleaned"
    log "- Disk space freed: $((initial_space - $(check_disk_space)))%"
}

print_summary

# Check if reboot is required
check_reboot_required() {
    if [ -f /var/run/reboot-required ]; then
        log "A system reboot is required to complete the update process."
        if prompt_user "Do you want to reboot now?"; then
            sudo reboot
        else
            log "Please remember to reboot your system as soon as possible."
        fi
    fi
}

check_reboot_required

log "Script execution completed."
