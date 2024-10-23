#!/usr/bin/env bash

# Get the IP address
CURRENT_IP=$(hostname -I | awk '{print $1}')

# Define Pingvin Share installation path
PINGVIN_SHARE_PATH="/opt/pingvin-share"

# Generate a path for a log file to output into for debugging
LOGPATH=$(realpath "pingvin_share_install_$(date +%s).log")

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

info_msg "----------------------------------------------------------------"
info_msg "This script installs a new Pingvin Share instance on a fresh Ubuntu server."
info_msg "- This script does not ensure system security."
info_msg "- If there is an error, please check the log file at: $LOGPATH"
info_msg "----------------------------------------------------------------"

# Function to ensure the script is run with root privileges
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root or with sudo."
        exit
    fi
}

# Function to check DNS resolution
dns_check() {
    if ! nslookup bigbeartechworld.com &> /dev/null; then
        error_out "DNS resolution failed. Please ensure your server's DNS settings are correct."
    fi
}

# Function to check if a command exists
command_exists() {
    type "$1" &> /dev/null
}

# Install necessary tools
install_tools() {
    if ! command_exists git; then
        echo "git not found, installing..."
        apt update
        apt install -y git
    fi

    if ! command_exists npm; then
        echo "npm not found, installing..."
        NODE_MAJOR=16
        apt update
        apt-get install -y ca-certificates curl gnupg
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
        echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
        apt-get update
        apt-get install nodejs -y
    fi

    if ! command_exists pm2; then
        echo "pm2 not found, installing..."
        npm install -g pm2
    fi
}

# Clone the repository and checkout the latest version
setup_repository() {
    # Check if Pingvin Share is already installed
    if [[ -d "$PINGVIN_SHARE_PATH" ]]; then
        echo "Pingvin Share is already installed at $PINGVIN_SHARE_PATH."
        error_out "Pingvin Share is already installed at $PINGVIN_SHARE_PATH."
    fi
    git clone https://github.com/stonith404/pingvin-share $PINGVIN_SHARE_PATH
    cd $PINGVIN_SHARE_PATH
    git fetch --tags && git checkout $(git describe --tags $(git rev-list --tags --max-count=1))
}

# Start the backend
start_backend() {
    cd backend
    npm install
    npm run build
    pm2 start --name="pingvin-share-backend" npm -- run prod
}

# Start the frontend
start_frontend() {
    cd ../frontend
    npm install
    npm run build
    pm2 start --name="pingvin-share-frontend" npm -- run start
}

info_msg "Step [1/7]: Checking for DNS resolution..."
dns_check >> "$LOGPATH" 2>&1

info_msg "Step [2/7]: Checking for root privileges..."
check_root >> "$LOGPATH" 2>&1

info_msg "Step [3/7]: Checking and installing necessary tools..."
install_tools >> "$LOGPATH" 2>&1

info_msg "Step [4/7]: Setting up the repository..."
setup_repository >> "$LOGPATH" 2>&1

info_msg "Step [5/7]: Starting the backend..."
start_backend >> "$LOGPATH" 2>&1

info_msg "Step [6/7]: Starting the frontend..."
start_frontend >> "$LOGPATH" 2>&1

info_msg "[7/7] Done!"

info_msg "----------------------------------------------------------------"
info_msg "Setup finished, your Pingvin Share instance should now be installed!"
info_msg "- Access URL: http://$CURRENT_IP:3000"
info_msg "- Pingvin Share install path: $PINGVIN_SHARE_PATH"
info_msg "- Install script log: $LOGPATH"
info_msg "---------------------------------------------------------------"
