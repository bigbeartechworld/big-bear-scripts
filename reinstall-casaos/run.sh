#!/usr/bin/env bash

# Log file
LOGFILE="./casaos_reinstall.log"

# Path to the configuration file
CONFIG_FILE="/etc/casaos/gateway.ini"

# Intro text
intro_text() {
    echo "===================================================" | tee -a $LOGFILE
    echo "|         CasaOS Reinstallation Script           |" | tee -a $LOGFILE
    echo "|-------------------------------------------------|" | tee -a $LOGFILE
    echo "|         Created by BigBearTechWorld            |" | tee -a $LOGFILE
    echo "|-------------------------------------------------|" | tee -a $LOGFILE
    echo "| This script will:                              |" | tee -a $LOGFILE
    echo "| 1. Uninstall CasaOS                            |" | tee -a $LOGFILE
    echo "| 2. Reinstall CasaOS                            |" | tee -a $LOGFILE
    echo "===================================================" | tee -a $LOGFILE
}

# Checking for necessary permissions
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root" | tee -a $LOGFILE
        exit 1
    fi
}

# Checking internet connection
check_internet() {
    if ! ping -c 1 bigbeartechworld.com &> /dev/null; then
        echo "No internet connection. Exiting..." | tee -a $LOGFILE
        exit 1
    fi
}

# Function to uninstall CasaOS
uninstall_casaos() {
    read -p "Do you want to uninstall CasaOS? (y/N): " choice
    choice=${choice:-N}
    if [[ $choice =~ [Yy] ]]; then
        echo "Step [1/2]: Uninstalling CasaOS..." | tee -a $LOGFILE
        casaos-uninstall
        if [[ $? -ne 0 ]]; then
            echo "Error uninstalling CasaOS. Exiting..." | tee -a $LOGFILE
            exit 1
        fi
    else
        echo "Uninstallation cancelled." | tee -a $LOGFILE
        exit 1
    fi
}

# Function to install CasaOS
install_casaos() {
    echo "Step [2/2]: Installing CasaOS..." | tee -a $LOGFILE
    curl -fsSL https://get.casaos.io | sudo bash
    if [[ $? -ne 0 ]]; then
        echo "Error installing CasaOS. Exiting..." | tee -a $LOGFILE
        exit 1
    fi
}

# User feedback
user_feedback() {
    echo "=====================================================" | tee -a $LOGFILE
    echo "|   Reinstallation completed successfully.         |" | tee -a $LOGFILE
    echo "=====================================================" | tee -a $LOGFILE

    # Check if the configuration file exists
    if [[ -f $CONFIG_FILE ]]; then
        # Use grep to find the line with 'port' and use awk to print the value
        PORT=$(grep '^port=' $CONFIG_FILE | awk -F'=' '{print $2}')
        # Get the local IP address
        IP_ADDR=$(hostname -I | awk '{print $1}')
        echo "|                                                   |" | tee -a $LOGFILE
        echo "|   The local IP address is: $IP_ADDR              |" | tee -a $LOGFILE
        echo "|   The port number is:        $PORT               |" | tee -a $LOGFILE
        echo "|   Access in the browser at: http://$IP_ADDR:$PORT|" | tee -a $LOGFILE
        echo "=====================================================" | tee -a $LOGFILE
    else
        echo "|                                                   |" | tee -a $LOGFILE
        echo "|   Error: Configuration file not found.           |" | tee -a $LOGFILE
        echo "=====================================================" | tee -a $LOGFILE
    fi
}

# Main script execution
main() {
    intro_text
    check_permissions
    check_internet
    uninstall_casaos
    install_casaos
    user_feedback
}

# Run the main function
main
