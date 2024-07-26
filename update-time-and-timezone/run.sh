#!/bin/bash

echo "---------------------"
echo "Big Bear Update Time and Timezone Script"
echo "---------------------"
echo "Made by BigBearTechWorld"
echo "---------------------"
echo "Like the script? Consider supporting my work at: https://ko-fi.com/bigbeartechworld"
echo "---------------------"

# Function to get current date and time
get_current_date_time() {
    echo "$(date '+%Y-%m-%d %H:%M:%S')"
}

# Function to change date and time
change_date_time() {
    echo "Changing date and time..."
    sudo date --set "$(date '+%Y-%m-%d')"
    sudo date --set "$(date '+%H:%M:%S')"
    echo "Date and time changed successfully."
}

# Function to set timezone
set_timezone() {
    echo "Setting timezone..."
    current_timezone=$(timedatectl | grep "Time zone" | awk '{print $3}')
    echo "Current timezone is: $current_timezone"

    echo "Setting system timezone to: $current_timezone"
    sudo timedatectl set-timezone $current_timezone
    echo "Timezone set successfully."
}

# Main script execution
echo "Starting script to fix date, time, and timezone issues..."

# Get current date and time
system_date_time=$(get_current_date_time)
echo "Current system date and time is: $system_date_time"

# Prompt user if the date and time is not correct
read -p "Is the current date and time correct? (y/n): " is_correct

if [ "$is_correct" != "y" ]; then
    # Change date and time
    change_date_time

    # Set timezone
    set_timezone
else
    echo "Date and time is correct, no changes made."
fi

echo "Script execution completed. Please check for updates from the GUI or reboot if necessary."
