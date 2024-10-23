#!/usr/bin/env bash

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

# Function to check and ensure NTP is running using ntpd
check_ntpd() {
    echo "Checking NTP (ntpd) status..."
    ntpd_status=$(systemctl is-active ntp)

    if [ "$ntpd_status" != "active" ]; then
        echo "NTP (ntpd) is not active. Installing and starting ntpd..."
        sudo apt-get update
        sudo apt-get install -y ntp
        sudo systemctl enable ntp
        sudo systemctl start ntp

        # Re-check the status
        ntpd_status=$(systemctl is-active ntp)
        if [ "$ntpd_status" == "active" ]; then
            echo "NTP (ntpd) has been successfully started and enabled."
        else
            echo "Failed to start and enable NTP (ntpd). Please check your system configuration."
        fi
    else
        echo "NTP (ntpd) is already active."
    fi
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

    # Check and ensure NTP is running
    check_ntpd
else
    echo "Date and time is correct, no changes made."
fi

echo "Script execution completed."
