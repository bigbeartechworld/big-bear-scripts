#!/usr/bin/env bash

# Function to list available USB devices with paths and names
list_usb_devices() {
    # Create an array to store devices and their paths
    devices=()
    device_paths=()

    echo "Available USB devices with names and paths:"
    echo

    # Get the list of USB devices
    while IFS= read -r line; do
        # Extract bus and device number
        bus=$(echo "$line" | awk '{print $2}')
        device=$(echo "$line" | awk '{print $4}' | sed 's/://')

        # Use udevadm to find the corresponding sysfs path
        sysfs_path=$(udevadm info --query=path --name=/dev/bus/usb/$bus/$device 2>/dev/null)
        # Extract the device path using the port information
        device_path=$(echo "$sysfs_path" | grep -oE '[0-9]+-[0-9]+(.[0-9]+)*')

        # Debugging: Print extracted information
        echo "Debug: Bus=$bus, Device=$device, Sysfs Path=$sysfs_path, Device Path=$device_path"

        # If device path exists, add to the array
        if [ -n "$device_path" ]; then
            devices+=("$line Path: $device_path")
            device_paths+=("$device_path")
        fi
    done < <(lsusb)
    echo

    # Check if devices were found
    if [ ${#devices[@]} -eq 0 ]; then
        echo "No USB devices found."
        exit 1
    fi

    echo "Select the USB device to restart by number:"
    echo

    # Display menu and handle user selection
    select choice in "${devices[@]}"; do
        if [ -n "$choice" ]; then
            DEVICE_PATH="${device_paths[$REPLY-1]}"
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
}

# Function to restart the USB device
restart_usb() {
    local device_path=$1
    echo "Unbinding USB device at path $device_path..."
    echo -n "$device_path" > /sys/bus/usb/drivers/usb/unbind

    # Sleep for a short duration to ensure the unbind completes
    sleep 1

    echo "Rebinding USB device at path $device_path..."
    echo -n "$device_path" > /sys/bus/usb/drivers/usb/bind

    echo "USB device restart complete."
}

# Main script
if [ $# -gt 0 ]; then
    # If arguments are passed, use them to restart the device
    for arg in "$@"; do
        echo "Restarting USB device at path $arg..."
        restart_usb "$arg"
    done
else
    # If no arguments, use interactive selection
    list_usb_devices

    # Confirm with the user before restarting the USB device
    echo
    read -p "Are you sure you want to restart the USB device at path ${DEVICE_PATH}? (y/n) " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        restart_usb "$DEVICE_PATH"
    else
        echo "Operation cancelled."
    fi
fi
