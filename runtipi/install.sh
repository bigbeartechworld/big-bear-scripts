#!/bin/bash

echo "This script installs a new Runtipi instance on a fresh Ubuntu server."
echo "This script does not ensure system security."
echo ""

# Get the IP address
CURRENT_IP=$(hostname -I | awk '{print $1}')

# Define Runtipi installation path
RUNTIPI_PATH="/root/runtipi"

# Generate a path for a log file to output into for debugging
LOGPATH=$(realpath "runtipi_install_$(date +%s).log")

# Install dependencies
function run_install_dependencies() {
    sudo apt-get update
    sudo apt-get install -y curl || error_out "Failed to install dependencies."
}

# Install Runtipi
function run_install_runtipi() {
    # Download the script first
    curl -L -o runtipi_install.sh https://setup.runtipi.io
    # Execute the script
    bash runtipi_install.sh || error_out "Failed to install Runtipi."
}

# Create the systemd service file
function run_create_service_file() {
    cat <<EOL | sudo tee /etc/systemd/system/tipi.service
[Unit]
Description=tipi
Requires=docker.service multi-user.target
After=docker.service network-online.target dhcpd.service

[Service]
Restart=always
RemainAfterExit=yes
WorkingDirectory=$RUNTIPI_PATH
ExecStart=$RUNTIPI_PATH/scripts/start.sh
ExecStop=$RUNTIPI_PATH/scripts/stop.sh

[Install]
WantedBy=multi-user.target
EOL
}

# Reload the systemd daemon
function run_reload_systemd() {
    sudo systemctl daemon-reload
}

# Enable the tipi service
function run_enable_service() {
    sudo systemctl enable tipi
}

# Display the status of the tipi service
function run_status_service() {
    sudo systemctl status tipi
}

# Echo out an error message to the command line and exit the program
# Also logs the message to the log file
function error_out() {
  echo "ERROR: $1" | tee -a "$LOGPATH" 1>&2
  exit 1
}

# Echo out an information message to both the command line and log file
function info_msg() {
  echo "$1" | tee -a "$LOGPATH"
}

info_msg "1/7 Installing dependencies..."
run_install_dependencies >> "$LOGPATH" 2>&1

info_msg "[2/7] Installing Runtipi... (This may take several minutes)"
run_install_runtipi >> "$LOGPATH" 2>&1

info_msg "[3/7] Creating the systemd service file..."
run_create_service_file >> "$LOGPATH" 2>&1

info_msg "[4/7] Reloading the systemd daemon..."
run_reload_systemd >> "$LOGPATH" 2>&1

info_msg "[5/7] Enabling the tipi service..."
run_enable_service >> "$LOGPATH" 2>&1

info_msg "[6/7] Displaying the status of the tipi service..."
run_status_service >> "$LOGPATH" 2>&1

info_msg "[7/7] Done!"

info_msg "----------------------------------------------------------------"
info_msg "Setup finished, your Runtipi instance should now be installed!"
info_msg "- Access URL: http://$CURRENT_IP/"
info_msg "- Runtipi install path: $RUNTIPI_PATH"
info_msg "- Install script log: $LOGPATH"
info_msg "---------------------------------------------------------------"
