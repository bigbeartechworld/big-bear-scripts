#!/usr/bin/env bash

# BigBear CasaOS Docker Client Version Fix
# Script to fix Docker client version 1.43 is too old error for CasaOS
# This script downgrades Docker to a version compatible with CasaOS
#
# GitHub: https://github.com/BigBearTechWorld
# Community: https://community.bigbeartechworld.com
# Support: https://ko-fi.com/bigbeartechworld
#

# Don't use set -e because we have intentional error handling
set -o pipefail

# Initialize SUDO variable early
if [ "$EUID" -eq 0 ]; then
  SUDO=""
else
  SUDO="sudo"
fi

echo "=========================================="
echo "BigBear CasaOS Docker Version Fix Script 1.6.1"
echo "=========================================="
echo ""
echo "Here are some links:"
echo "https://community.bigbeartechworld.com"
echo "https://github.com/BigBearTechWorld"
echo ""
echo "If you would like to support me, please consider buying me a tea:"
echo "https://ko-fi.com/bigbeartechworld"
echo ""
echo "=========================================="
echo ""

# Compatible Docker versions for CasaOS
# Using Docker 28.x series which supports API 1.47/1.48
# Docker 28.x is one version behind the latest (29.0.x / API 1.52)
# This provides modern features while maintaining stability
# DOCKER_VERSION will be resolved at runtime to find latest available 28.x.x
# Using containerd.io 1.7.28-1 to avoid CVE-2025-52881 AppArmor issues in LXC/Proxmox
# Version 1.7.28-2 and newer cause "permission denied" errors on sysctl in nested containers
readonly CONTAINERD_VERSION="1.7.28-1"

# Function to display current versions
display_versions() {
  echo "Current Docker versions:"
  if command -v docker &>/dev/null; then
    $SUDO docker version 2>&1 || echo "Unable to get full version info due to API mismatch"
    echo ""
    
    # Also show installed package versions for clarity
    echo "Installed Docker packages:"
    dpkg -l | grep -E "docker-ce|containerd.io" | awk '{print $2, $3}' 2>/dev/null || echo "Unable to query package versions"
    echo ""
  else
    echo "Docker command not found"
    echo ""
  fi
}

# Function to check if running as root or with sudo
check_sudo() {
  if [ "$EUID" -eq 0 ]; then
    SUDO=""
  else
    SUDO="sudo"
  fi
}

# Function to detect the OS
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION_CODENAME=${VERSION_CODENAME:-$(lsb_release -cs 2>/dev/null)}
  else
    echo "Cannot detect OS. This script supports Debian/Ubuntu-based systems."
    exit 1
  fi
  echo "Detected OS: $OS ${VERSION_CODENAME}"
  echo ""
}

# Function to check if Docker 28.x is available for this OS version
check_docker_availability() {
  echo "Checking Docker 28.x availability for $OS $VERSION_CODENAME..."
  
  # List of OS versions known to NOT have Docker 28.x packages
  # For these, we'll keep the latest available Docker with API override
  local unsupported_versions=(
    # Note: All currently supported distros should have Docker 28.x available
    # This list is kept for future compatibility
  )
  
  # Known supported versions (have Docker 28.x available):
  # - Ubuntu 20.04 (focal)
  # - Ubuntu 22.04 (jammy)
  # - Ubuntu 24.04 (noble)
  # - Ubuntu 24.10 (oracular)
  # - Debian 11 (bullseye)
  # - Debian 12 (bookworm)
  # - Debian 13 (trixie)
  
  local current_os="${OS}:${VERSION_CODENAME}"
  
  for unsupported in "${unsupported_versions[@]}"; do
    if [ "$current_os" = "$unsupported" ]; then
      echo ""
      echo "=========================================="
      echo "Newer Distribution Detected"
      echo "=========================================="
      echo ""
      echo "Your system: $OS $VERSION_CODENAME"
      echo ""
      echo "Docker 28.0.x is NOT available for your OS version."
      echo "The Docker repository for $VERSION_CODENAME only provides Docker 29.x or newer."
      echo ""
      echo "This script will use the Docker API override method instead:"
      echo "  • Sets DOCKER_MIN_API_VERSION=1.24 environment variable"
      echo "  • Allows newer Docker versions (29.x) to work with CasaOS"
      echo "  • Does not require downgrading Docker"
      echo ""
      echo "This is a safe alternative that maintains compatibility with CasaOS."
      echo ""
      
      # Return a special status code to indicate we should use the override method
      return 2
    fi
  done
  
  echo "✓ Docker 28.x should be available for your OS version"
  echo ""
  return 0
}

# Function to check for and remove Snap Docker installation
check_and_remove_snap_docker() {
  echo "Checking for Docker installed via Snap..."
  
  # Check if snap is installed
  if ! command -v snap &>/dev/null; then
    echo "Snap is not installed on this system"
    echo ""
    return 0
  fi
  
  # Check if Docker is installed via snap
  if snap list docker &>/dev/null; then
    echo ""
    echo "=========================================="
    echo "WARNING: Docker installed via Snap detected!"
    echo "=========================================="
    echo ""
    echo "Docker installed via Snap will conflict with the apt-based installation."
    echo "The Snap version must be removed for this script to work properly."
    echo ""
    
    # Check if docker command is from snap
    if command -v docker &>/dev/null; then
      docker_path=$(which docker)
      if [[ "$docker_path" == *"snap"* ]]; then
        echo "Current docker command is from Snap: $docker_path"
        echo ""
      fi
    fi
    
    echo "Removing Docker Snap package..."
    if $SUDO snap remove --purge docker; then
      # Wait a moment for snap to fully clean up
      sleep 2
      
      # Verify removal succeeded
      if snap list docker &>/dev/null; then
        echo "⚠ WARNING: Snap Docker still appears to be installed after removal attempt"
        echo ""
        return 1
      fi
      
      echo "✓ Snap Docker removed successfully"
      echo ""
      return 0
    else
      echo "⚠ WARNING: Failed to remove Snap Docker"
      echo ""
      return 1
    fi
  else
    echo "No Docker Snap package found"
    echo ""
    return 0
  fi
}

# Function to check for multiple Docker binaries
check_docker_binary_locations() {
  echo "Checking for Docker binary locations..."
  
  # Find all docker binaries
  local docker_binaries=$(which -a docker 2>/dev/null || true)
  
  if [ -z "$docker_binaries" ]; then
    echo "No docker binary found in PATH"
    echo ""
    return 0
  fi
  
  # Count how many we found
  local count=$(echo "$docker_binaries" | wc -l)
  
  if [ "$count" -gt 1 ]; then
    echo ""
    echo "=========================================="
    echo "WARNING: Multiple Docker binaries found!"
    echo "=========================================="
    echo ""
    echo "$docker_binaries"
    echo ""
    echo "This may cause version conflicts."
    echo "After installation, verify which binary is being used with: which docker"
    echo ""
  else
    echo "Docker binary location: $docker_binaries"
    echo ""
  fi
  
  return 0
}

# Function to check if CasaOS is installed
check_casaos() {
  if command -v casaos &>/dev/null; then
    echo "CasaOS is installed: $(casaos -v 2>/dev/null || echo 'version unknown')"
    return 0
  else
    echo "CasaOS not detected."
    return 1
  fi
}

# Function to detect if running in LXC/Proxmox container
check_lxc_environment() {
  if [ -f /proc/1/environ ]; then
    if grep -qa "container=lxc" /proc/1/environ 2>/dev/null; then
      return 0
    fi
  fi
  
  # Alternative check: systemd-detect-virt
  if command -v systemd-detect-virt &>/dev/null; then
    if systemd-detect-virt -c | grep -q "lxc"; then
      return 0
    fi
  fi
  
  return 1
}

# Function to check containerd.io version
check_containerd_version() {
  if ! command -v containerd &>/dev/null; then
    echo "not_installed"
    return 1
  fi
  
  # Get installed version
  local version=$(dpkg -l | grep containerd.io | awk '{print $3}' | head -n1)
  echo "$version"
  return 0
}

# Function to get Docker API version
get_docker_api_version() {
  local api_version=""
  
  # Try to get the API version from docker version command
  if command -v docker &>/dev/null; then
    # Get server API version
    api_version=$($SUDO docker version --format '{{.Server.APIVersion}}' 2>/dev/null || echo "")
    
    if [ -z "$api_version" ]; then
      # Fallback: try to parse from docker version output
      api_version=$($SUDO docker version 2>/dev/null | grep -A 5 "Server:" | grep "API version:" | awk '{print $3}' | head -n1 || echo "")
    fi
  fi
  
  echo "$api_version"
  return 0
}

# Function to verify dockerd binary version
verify_dockerd_binary_version() {
  echo "Verifying dockerd binary version..."
  
  if ! command -v dockerd &>/dev/null; then
    echo "⚠ WARNING: dockerd binary not found"
    return 1
  fi
  
  local dockerd_version=$(dockerd --version 2>/dev/null | head -n1)
  echo "dockerd binary version: $dockerd_version"
  
  # Check if it contains "28." (28.0, 28.1, 28.5, etc.)
  if echo "$dockerd_version" | grep -qE "Docker version 28\."; then
    echo "✓ dockerd binary is version 28.x"
    echo ""
    return 0
  else
    echo "⚠ WARNING: dockerd binary may not be the expected version"
    echo ""
    return 1
  fi
}

# Function to ensure all Docker processes are terminated
ensure_docker_processes_stopped() {
  echo "Ensuring all Docker processes are completely stopped..."
  
  local max_attempts=3
  local attempt=0
  
  while [ $attempt -lt $max_attempts ]; do
    # Check for dockerd
    if pgrep -x dockerd >/dev/null 2>&1; then
      echo "Attempt $((attempt + 1)): Found running dockerd processes, terminating..."
      $SUDO pkill -9 dockerd 2>/dev/null || true
      sleep 2
      attempt=$((attempt + 1))
    else
      echo "✓ No dockerd processes running"
      break
    fi
  done
  
  # Final check
  if pgrep -x dockerd >/dev/null 2>&1; then
    echo "⚠ WARNING: dockerd processes still running after $max_attempts attempts"
    echo "Listing running dockerd processes:"
    pgrep -a dockerd || true
    echo ""
    return 1
  fi
  
  echo ""
  return 0
}

# Function to verify Docker API version after installation
verify_docker_api_version() {
  echo "Verifying Docker API version..."
  
  local api_version=$(get_docker_api_version)
  
  if [ -z "$api_version" ]; then
    echo "⚠ WARNING: Could not determine Docker API version"
    echo "This might indicate a problem with the Docker installation"
    echo ""
    return 1
  fi
  
  echo "Current Docker API version: $api_version"
  echo ""
  
  # Check if it's 1.47 or 1.48 (Docker 28.x series)
  if [[ "$api_version" == "1.47" ]] || [[ "$api_version" == "1.48" ]]; then
    echo "✓ Docker API version is compatible with CasaOS ($api_version)"
    echo ""
    return 0
  else
    echo "⚠ WARNING: Docker API version is $api_version"
    echo "Expected: 1.47 or 1.48 for CasaOS compatibility (Docker 28.x)"
    echo ""
    echo "Current version: $api_version"
    if (( $(echo "$api_version > 1.47" | bc -l) )); then
      echo "You have a newer Docker version installed (API $api_version)"
      echo ""
      echo "This might indicate:"
      echo "  - The Docker repository setup failed (check for GPG key conflicts)"
      echo "  - The Docker package installation didn't work properly"
      echo "  - You may need to use the 'apply-override' method instead"
    else
      echo "This might indicate:"
      echo "  - The Docker package installation didn't work properly"
      echo "  - A different Docker binary is being used"
      echo "  - The Docker daemon didn't restart with the new version"
    fi
    echo ""
    return 1
  fi
}

# Function to add user to docker group
add_user_to_docker_group() {
  # Only add user to docker group if not running as root
  if [ "$EUID" -ne 0 ]; then
    local current_user=$(whoami)
    
    # Check if docker group exists
    if getent group docker >/dev/null 2>&1; then
      # Check if user is already in docker group
      if ! groups "$current_user" | grep -q '\bdocker\b'; then
        echo "Adding user '$current_user' to docker group..."
        $SUDO usermod -aG docker "$current_user"
        echo ""
        echo "✓ User added to docker group"
        echo ""
        echo "=========================================="
        echo "IMPORTANT: Group Change Requires New Login"
        echo "=========================================="
        echo ""
        echo "For the docker group permission to take effect, you need to:"
        echo "  1. Log out of your current session"
        echo "  2. Log back in"
        echo ""
        echo "OR run this command to start a new shell with updated groups:"
        echo "  newgrp docker"
        echo ""
        echo "After that, you'll be able to run docker commands without sudo."
        echo ""
        return 0
      else
        echo "User '$current_user' is already in docker group"
        echo ""
        return 0
      fi
    else
      echo "Warning: docker group does not exist"
      echo "This is unusual - Docker installation may have issues"
      echo ""
      return 1
    fi
  else
    echo "Running as root - skipping docker group addition"
    echo ""
    return 0
  fi
}

# Function to stop CasaOS services
stop_casaos_services() {
  echo "Stopping CasaOS services..."
  
  CASA_SERVICES=(
    "casaos-gateway.service"
    "casaos-message-bus.service"
    "casaos-user-service.service"
    "casaos-local-storage.service"
    "casaos-app-management.service"
    "casaos.service"
  )
  
  for SERVICE in "${CASA_SERVICES[@]}"; do
    if $SUDO systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
      echo "  Stopping $SERVICE..."
      $SUDO systemctl stop "$SERVICE" || true
    fi
  done
  echo ""
}

# Function to start CasaOS services
start_casaos_services() {
  echo "Starting CasaOS services..."
  
  CASA_SERVICES=(
    "casaos-gateway.service"
    "casaos-message-bus.service"
    "casaos-user-service.service"
    "casaos-local-storage.service"
    "casaos-app-management.service"
    "casaos.service"
  )
  
  for SERVICE in "${CASA_SERVICES[@]}"; do
    if $SUDO systemctl is-enabled --quiet "$SERVICE" 2>/dev/null; then
      echo "  Starting $SERVICE..."
      $SUDO systemctl start "$SERVICE" || true
    fi
  done
  echo ""
}

# Function to apply Docker API override (alternative fix for newer distros)
apply_docker_api_override() {
  echo "=========================================="
  echo "Applying Docker API Override Configuration"
  echo "=========================================="
  echo ""
  echo "This sets DOCKER_MIN_API_VERSION=1.24 to allow older CasaOS versions"
  echo "to work with newer Docker versions (27.x, 28.x, 29.x)"
  echo ""
  echo "Use this method on distributions where Docker 24.0.x is not available:"
  echo "  - Ubuntu 24.04 (noble)"
  echo "  - Ubuntu 24.10 (oracular)"
  echo "  - Debian 13 (trixie)"
  echo ""
  
  local override_dir="/etc/systemd/system/docker.service.d"
  local override_file="$override_dir/override.conf"
  
  # Create directory if it doesn't exist
  if [ ! -d "$override_dir" ]; then
    echo "Creating directory: $override_dir"
    $SUDO mkdir -p "$override_dir"
  fi
  
  # Create or update override.conf
  echo "Creating Docker service override configuration..."
  $SUDO tee "$override_file" > /dev/null <<'EOF'
[Service]
Environment=DOCKER_MIN_API_VERSION=1.24
EOF
  
  if [ -f "$override_file" ]; then
    echo "✓ Created: $override_file"
    echo ""
    echo "Contents:"
    $SUDO cat "$override_file" | sed 's/^/  /'
    echo ""
  else
    echo "ERROR: Failed to create override file"
    return 1
  fi
  
  # Reload systemd daemon
  echo "Reloading systemd daemon..."
  $SUDO systemctl daemon-reload
  echo ""
  
  # Restart Docker
  echo "Restarting Docker service..."
  $SUDO systemctl restart docker
  sleep 3
  echo ""
  
  # Verify Docker is running
  if $SUDO systemctl is-active --quiet docker; then
    echo "✓ Docker service restarted successfully"
    
    # Show current Docker info
    local docker_version=$(get_docker_api_version)
    if command -v docker &>/dev/null; then
      local docker_ver=$($SUDO docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
      echo ""
      echo "Current configuration:"
      echo "  Docker version: $docker_ver"
      echo "  API version:    $docker_version"
      echo ""
    fi
    
    echo "✓ Docker API override applied successfully!"
    echo "CasaOS should now work with this Docker version"
    echo ""
    return 0
  else
    echo "ERROR: Docker service failed to start after applying override"
    echo ""
    echo "Check logs with: sudo journalctl -u docker -n 50"
    return 1
  fi
}

# Function to remove Docker API override
remove_docker_api_override() {
  echo "=========================================="
  echo "Removing Docker API Override Configuration"
  echo "=========================================="
  echo ""
  
  local override_file="/etc/systemd/system/docker.service.d/override.conf"
  
  if [ ! -f "$override_file" ]; then
    echo "No override configuration found"
    echo ""
    return 0
  fi
  
  echo "Removing: $override_file"
  $SUDO rm -f "$override_file"
  
  # Reload systemd daemon
  echo "Reloading systemd daemon..."
  $SUDO systemctl daemon-reload
  echo ""
  
  # Restart Docker
  echo "Restarting Docker service..."
  $SUDO systemctl restart docker
  sleep 3
  echo ""
  
  if $SUDO systemctl is-active --quiet docker; then
    echo "✓ Docker API override removed successfully"
    echo ""
    return 0
  else
    echo "WARNING: Docker service may have issues after removing override"
    echo "Check logs with: sudo journalctl -u docker -n 50"
    echo ""
    return 1
  fi
}

# Function to validate daemon.json
validate_daemon_json() {
  local daemon_json="/etc/docker/daemon.json"
  
  if [ ! -f "$daemon_json" ]; then
    return 0
  fi
  
  # Check if it's valid JSON
  if command -v python3 &>/dev/null; then
    if ! python3 -m json.tool "$daemon_json" > /dev/null 2>&1; then
      echo "ERROR: daemon.json is not valid JSON"
      return 1
    fi
  elif command -v jq &>/dev/null; then
    if ! jq empty "$daemon_json" > /dev/null 2>&1; then
      echo "ERROR: daemon.json is not valid JSON"
      return 1
    fi
  fi
  
  return 0
}

# Function to detect and fix Docker errors
detect_and_fix_docker_errors() {
  echo "Analyzing Docker error logs..."
  
  # Get recent Docker logs
  local docker_logs=$($SUDO journalctl -u docker --no-pager -n 100 2>/dev/null)
  
  # Check for specific errors and apply fixes
  
  # Error 1: overlay2.override_kernel_check unknown option
  if echo "$docker_logs" | grep -q "unknown option overlay2.override_kernel_check"; then
    echo "Detected: Invalid overlay2.override_kernel_check option in daemon.json"
    echo "Fix: Removing invalid storage-opts from daemon.json..."
    
    if [ -f /etc/docker/daemon.json ]; then
      # Backup the file
      $SUDO cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%Y%m%d_%H%M%S)
      
      # Remove the invalid option using python or sed
      if command -v python3 &>/dev/null; then
        $SUDO python3 << 'EOF'
import json
try:
    with open('/etc/docker/daemon.json', 'r') as f:
        config = json.load(f)
    
    # Remove storage-opts if it contains the invalid option
    if 'storage-opts' in config:
        config['storage-opts'] = [opt for opt in config['storage-opts'] 
                                  if 'overlay2.override_kernel_check' not in opt]
        if not config['storage-opts']:
            del config['storage-opts']
    
    with open('/etc/docker/daemon.json', 'w') as f:
        json.dump(config, f, indent=2)
    print("Fixed: Removed invalid storage-opts")
except Exception as e:
    print(f"Error: {e}")
EOF
      else
        # Fallback: create a simple daemon.json
        $SUDO tee /etc/docker/daemon.json > /dev/null <<EOL
{
  "storage-driver": "overlay2"
}
EOL
      fi
      echo "daemon.json has been fixed"
      return 0
    fi
  fi
  
  # Error 2: Permission denied errors
  if echo "$docker_logs" | grep -q "permission denied"; then
    echo "Detected: Permission errors in Docker"
    echo "Fix: Resetting Docker directory permissions..."
    clean_docker_state
    return 0
  fi
  
  # Error 3: Failed to create shim task / OCI runtime errors (including sysctl permission denied)
  if echo "$docker_logs" | grep -q -E "failed to create shim task|OCI runtime create failed"; then
    echo "Detected: Container runtime errors"
    
    # Check specifically for the CVE-2025-52881 AppArmor sysctl issue
    if echo "$docker_logs" | grep -q "open sysctl.*permission denied"; then
      echo ""
      echo "=========================================="
      echo "CRITICAL: CVE-2025-52881 AppArmor Issue Detected"
      echo "=========================================="
      echo ""
      echo "This error is caused by containerd.io 1.7.28-2 or newer in LXC/Proxmox containers."
      echo "The security patch for CVE-2025-52881 conflicts with AppArmor profiles."
      echo ""
      
      if check_lxc_environment; then
        echo "✓ LXC/Proxmox environment detected"
        echo ""
        local current_containerd=$(check_containerd_version)
        echo "Current containerd.io version: $current_containerd"
        echo ""
        
        # Check if we need to downgrade containerd
        if [[ "$current_containerd" =~ 1\.7\.(28-2|29) ]] || [[ "$current_containerd" =~ 1\.7\.(3[0-9]) ]]; then
          echo "This version causes the sysctl permission error."
          echo "The script will downgrade containerd.io to version 1.7.28-1"
          echo ""
          echo "Note: This is the recommended workaround until LXC/Proxmox updates their AppArmor profiles."
          echo "See: https://github.com/opencontainers/runc/issues/4968"
          echo ""
          return 1  # Signal that we need to proceed with the full installation
        fi
      else
        echo "⚠ Not running in LXC/Proxmox - this error is unexpected"
        echo "Please check your Docker and containerd configuration."
      fi
      echo ""
    else
      # Generic runtime error - try cleaning runtime state
      echo "Fix: Cleaning runtime state..."
      
      # Clean containerd
      $SUDO systemctl stop docker 2>/dev/null || true
      $SUDO systemctl stop containerd 2>/dev/null || true
      
      if [ -d /run/containerd ]; then
        $SUDO rm -rf /run/containerd/* 2>/dev/null || true
      fi
      
      $SUDO systemctl start containerd 2>/dev/null || true
      sleep 2
      echo "Runtime state cleaned"
      return 0
    fi
  fi
  
  # Error 4: Address already in use
  if echo "$docker_logs" | grep -q "address already in use"; then
    echo "Detected: Port conflict"
    echo "Fix: Cleaning stale Docker sockets..."
    
    $SUDO systemctl stop docker 2>/dev/null || true
    $SUDO systemctl stop docker.socket 2>/dev/null || true
    
    # Remove stale sockets
    $SUDO rm -f /var/run/docker.sock
    $SUDO rm -f /var/run/docker.pid
    
    sleep 2
    echo "Stale sockets removed"
    return 0
  fi
  
  echo "No specific Docker errors detected in logs"
  return 1
}

# Function to set up Docker repository
setup_docker_repository() {
  echo "Setting up Docker repository..."
  
  # Clean up any existing Docker repository configurations to avoid conflicts
  echo "Cleaning up old Docker repository configurations..."
  if [ -f /etc/apt/sources.list.d/docker.list ]; then
    echo "Removing existing docker.list..."
    $SUDO rm -f /etc/apt/sources.list.d/docker.list
  fi
  
  # Also check for other potential Docker repo files
  if ls /etc/apt/sources.list.d/docker*.list 1> /dev/null 2>&1; then
    echo "Removing other Docker repository files..."
    $SUDO rm -f /etc/apt/sources.list.d/docker*.list
  fi
  
  # Remove old GPG keys that might conflict
  echo "Removing old Docker GPG keys..."
  if [ -f /usr/share/keyrings/docker.gpg ]; then
    $SUDO rm -f /usr/share/keyrings/docker.gpg
  fi
  if [ -f /etc/apt/keyrings/docker.gpg ]; then
    $SUDO rm -f /etc/apt/keyrings/docker.gpg
  fi
  if [ -f /etc/apt/keyrings/docker.asc ]; then
    $SUDO rm -f /etc/apt/keyrings/docker.asc
  fi
  
  # Clean apt cache to force fresh download
  echo "Cleaning apt cache..."
  $SUDO apt-get clean
  $SUDO rm -rf /var/lib/apt/lists/*
  
  $SUDO apt-get update
  echo ""

  echo "Installing prerequisites..."
  if ! $SUDO apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release; then
    echo "ERROR: Failed to install prerequisites"
    return 1
  fi
  echo ""

  # Add Docker's official GPG key
  echo "Adding Docker's official GPG key..."
  $SUDO install -m 0755 -d /etc/apt/keyrings
  if ! $SUDO curl -fsSL https://download.docker.com/linux/${OS}/gpg -o /etc/apt/keyrings/docker.asc; then
    echo "ERROR: Failed to download Docker GPG key"
    return 1
  fi
  $SUDO chmod a+r /etc/apt/keyrings/docker.asc
  echo ""

  # Set up the stable repository
  echo "Setting up Docker repository..."
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${OS} \
    ${VERSION_CODENAME} stable" | \
    $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null
  echo ""

  # Update package index with new repository (force refresh)
  echo "Updating package lists with Docker repository..."
  if ! $SUDO apt-get update; then
    echo "ERROR: Failed to update package lists"
    return 1
  fi
  echo ""
  
  return 0
}

# Function to remove standalone Docker Compose if it exists
remove_standalone_docker_compose() {
  if command -v docker-compose &>/dev/null; then
    echo "Standalone docker-compose found. Checking installation method..."

    # Check if docker-compose was installed via package manager
    if dpkg -l | grep -qw docker-compose 2>/dev/null; then
      echo "Removing docker-compose installed via package manager..."
      $SUDO apt-get remove -y docker-compose
    else
      echo "Removing standalone docker-compose binary..."
      $SUDO rm -f $(which docker-compose)
    fi
    echo ""
  fi
}

# Function to clean Docker runtime state
clean_docker_state() {
  echo "Cleaning Docker runtime state..."
  
  # Stop Docker first
  if $SUDO systemctl is-active --quiet docker; then
    echo "Stopping Docker service..."
    $SUDO systemctl stop docker
    sleep 2
    echo ""
  fi
  
  # Stop docker socket to prevent auto-restart
  if $SUDO systemctl is-active --quiet docker.socket; then
    echo "Stopping Docker socket..."
    $SUDO systemctl stop docker.socket
    sleep 1
    echo ""
  fi
  
  # Kill any remaining dockerd processes that might be hanging
  echo "Checking for lingering Docker processes..."
  if pgrep -x dockerd >/dev/null 2>&1; then
    echo "Found running dockerd processes, terminating them..."
    $SUDO pkill -9 dockerd 2>/dev/null || true
    sleep 2
    echo ""
  fi
  
  # Kill containerd-shim processes that might be keeping containers alive
  if pgrep containerd-shim >/dev/null 2>&1; then
    echo "Found containerd-shim processes, terminating them..."
    $SUDO pkill -9 containerd-shim 2>/dev/null || true
    sleep 1
    echo ""
  fi
  
  # Clean up Docker runtime state (sockets, pids)
  if [ -d /var/run/docker ]; then
    echo "Cleaning Docker sockets and pids..."
    # Try to remove, but don't fail if network namespaces are busy
    $SUDO find /var/run/docker -mindepth 1 -maxdepth 1 ! -path '/var/run/docker/netns' -delete 2>/dev/null || true
    # Try to clean netns, but ignore "device busy" errors
    if [ -d /var/run/docker/netns ]; then
      $SUDO find /var/run/docker/netns -type f -delete 2>/dev/null || true
    fi
    echo ""
  fi
  
  # Fix containerd state
  if [ -d /run/containerd ]; then
    echo "Cleaning containerd runtime state..."
    $SUDO rm -rf /run/containerd/runc
    $SUDO rm -rf /run/containerd/io.containerd*
    echo ""
  fi
  
  # Clean up any stale container pids
  if [ -d /var/lib/docker/containers ]; then
    echo "Cleaning stale container pids..."
    $SUDO find /var/lib/docker/containers -name "*.pid" -delete 2>/dev/null || true
    echo ""
  fi
  
  echo "Docker runtime cleanup complete"
  echo "Docker will set its own directory permissions on startup"
  echo ""
}

# Function to resolve latest available Docker 28.x version
resolve_docker_version() {
  # Query available docker-ce versions and filter for 28.x.x (any patch in 28 series)
  # Pattern matches: 5:28.X.X-1~ (Docker 28.x.x series - includes 28.0.x, 28.1.x, 28.5.x, etc.)
  # Handles various distro suffixes: ~debian.13~trixie, ~ubuntu.22.04~jammy, etc.
  # Sort versions to get the latest (highest version number)
  local available_version=$(apt-cache madison docker-ce 2>/dev/null | \
    awk '{print $3}' | \
    grep -E '^5:28\.[0-9]+\.[0-9]+-1~' | \
    sort -V -r | \
    head -n1)
  
  if [ -z "$available_version" ]; then
    echo "ERROR: Could not find any Docker 28.x version in repository" >&2
    echo "Available versions:" >&2
    apt-cache madison docker-ce 2>/dev/null | head -n 10 >&2
    return 1
  fi
  
  # Only output the version string, no other messages
  echo "$available_version"
  return 0
}

# Function to downgrade Docker to compatible version
downgrade_docker() {
  # Set up Docker repository
  if ! setup_docker_repository; then
    echo "ERROR: Failed to set up Docker repository"
    return 1
  fi

  # Get available versions
  echo "Available Docker CE versions:"
  apt-cache madison docker-ce | head -n 5
  echo ""

  # Hold Docker packages to prevent auto-upgrade
  echo "Configuring Docker packages to prevent auto-upgrade..."
  $SUDO apt-mark unhold docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
  echo ""

  # Check if Docker is already installed and remove it to ensure clean downgrade
  if dpkg -l | grep -qE "docker-ce|containerd.io"; then
    echo "Removing existing Docker packages to ensure clean installation..."
    
    # Stop Docker services before removal
    echo "Stopping Docker services before package removal..."
    $SUDO systemctl stop docker.socket 2>/dev/null || true
    $SUDO systemctl stop docker 2>/dev/null || true
    $SUDO systemctl stop containerd 2>/dev/null || true
    sleep 2
    
    $SUDO apt-get remove --purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
    
    # Clean up unused dependencies
    echo "Cleaning up unused dependencies..."
    $SUDO apt-get autoremove -y
    echo ""
  fi

  # Resolve exact Docker version at runtime
  echo "Resolving latest Docker 28.x version from repository..."
  DOCKER_VERSION=$(resolve_docker_version)
  if [ $? -ne 0 ] || [ -z "$DOCKER_VERSION" ]; then
    echo "ERROR: Failed to resolve Docker version"
    return 1
  fi
  echo "Found Docker version: $DOCKER_VERSION"
  echo ""
  
  # Resolve exact containerd version
  echo "Resolving exact containerd.io version..."
  CONTAINERD_FULL="${CONTAINERD_VERSION}~${OS}~${VERSION_CODENAME}"
  
  # Verify containerd version exists
  if ! apt-cache madison containerd.io 2>/dev/null | grep -q "${CONTAINERD_FULL}"; then
    echo "Exact containerd version ${CONTAINERD_FULL} not found"
    echo "Searching for any 1.7.28-1 variant..."
    CONTAINERD_FULL=$(apt-cache madison containerd.io 2>/dev/null | \
      grep -E '1\.7\.28-1~' | \
      head -n1 | \
      awk '{print $3}')
    
    if [ -z "$CONTAINERD_FULL" ]; then
      echo "ERROR: Could not find containerd.io 1.7.28-1 in repository"
      echo "Available containerd.io versions:"
      apt-cache madison containerd.io 2>/dev/null | head -n 5
      return 1
    fi
    echo "Found containerd version: $CONTAINERD_FULL"
  fi
  echo ""
  
  # Install latest Docker 28.x version compatible with CasaOS
  echo "Installing Docker 28.x (API 1.47/1.48) - one version behind latest..."
  
  # Check if we're in LXC and warn about containerd version
  if check_lxc_environment; then
    echo ""
    echo "=========================================="
    echo "LXC/Proxmox Environment Detected"
    echo "=========================================="
    echo ""
    echo "Installing containerd.io ${CONTAINERD_VERSION} to avoid CVE-2025-52881 AppArmor issues."
    echo "This version is safe and prevents 'permission denied' errors on sysctl."
    echo ""
    echo "For more information, see:"
    echo "https://github.com/opencontainers/runc/issues/4968"
    echo ""
  fi
  
  # Install with exact versions (no wildcards)
  echo "Installing docker-ce=${DOCKER_VERSION}"
  echo "Installing docker-ce-cli=${DOCKER_VERSION}"
  echo "Installing containerd.io=${CONTAINERD_FULL}"
  echo ""
  
  if ! $SUDO apt-get install -y --allow-downgrades \
    docker-ce=${DOCKER_VERSION} \
    docker-ce-cli=${DOCKER_VERSION} \
    containerd.io=${CONTAINERD_FULL} \
    docker-buildx-plugin \
    docker-compose-plugin; then
      echo ""
      echo "ERROR: Docker installation failed!"
      echo "Please check your internet connection and try again."
      echo ""
      echo "Attempted to install:"
      echo "  docker-ce=${DOCKER_VERSION}"
      echo "  docker-ce-cli=${DOCKER_VERSION}"
      echo "  containerd.io=${CONTAINERD_FULL}"
      return 1
  fi
  
  echo "✓ Successfully installed Docker 28.x (API 1.47/1.48)"
  echo ""

  # Hold packages to prevent auto-upgrade
  echo "Holding Docker packages at current version..."
  $SUDO apt-mark hold docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  echo ""
  
  # Verify the dockerd binary version before starting
  echo "Step 7.1: Verifying installed dockerd binary..."
  verify_dockerd_binary_version

  # Check if daemon.json exists and validate it
  if [ -f /etc/docker/daemon.json ]; then
    echo "Existing daemon.json found - preserving user configuration..."
    if ! validate_daemon_json; then
      echo "WARNING: Your existing daemon.json may have syntax errors"
      echo "Please check /etc/docker/daemon.json for any issues"
    else
      echo "Existing daemon.json is valid - keeping it unchanged"
    fi
  else
    echo "No daemon.json found - Docker will use default settings"
  fi
  echo ""

  # Reload systemd and restart Docker service
  echo "Reloading systemd daemon..."
  $SUDO systemctl daemon-reload
  echo ""

  # Ensure Docker is completely stopped before starting
  echo "Step 7.2: Ensuring Docker is completely stopped..."
  $SUDO systemctl stop docker.socket 2>/dev/null || true
  $SUDO systemctl stop docker 2>/dev/null || true
  sleep 2
  
  # Use the new function to ensure processes are stopped
  ensure_docker_processes_stopped
  
  # Stop containerd to ensure clean slate
  echo "Restarting containerd for clean state..."
  $SUDO systemctl stop containerd 2>/dev/null || true
  sleep 1
  if pgrep -x containerd >/dev/null 2>&1; then
    $SUDO pkill -9 containerd 2>/dev/null || true
    sleep 1
  fi
  $SUDO systemctl start containerd 2>/dev/null || true
  sleep 2
  echo ""

  # Enable and start docker socket first, then service
  echo "Step 7.3: Enabling and starting Docker socket..."
  $SUDO systemctl enable docker.socket 2>/dev/null || true
  $SUDO systemctl start docker.socket
  sleep 1
  echo ""

  echo "Step 7.4: Enabling and starting Docker service..."
  $SUDO systemctl enable docker
  $SUDO systemctl start docker
  sleep 5  # Give Docker more time to fully initialize
  echo ""
  
  # Verify Docker is running
  if ! $SUDO systemctl is-active --quiet docker; then
    echo "=========================================="
    echo "ERROR: Docker service failed to start"
    echo "=========================================="
    echo ""
    echo "Checking Docker status and logs..."
    $SUDO systemctl status docker --no-pager -l || true
    echo ""
    echo "Recent Docker logs:"
    $SUDO journalctl -u docker --no-pager -n 50 || true
    echo ""
    
    # Attempt to detect and fix the error
    echo "=========================================="
    echo "Attempting automatic error detection and fix..."
    echo "=========================================="
    echo ""
    
    if detect_and_fix_docker_errors; then
      # Try to start Docker again after fix
      echo ""
      echo "Reloading systemd and restarting Docker..."
      $SUDO systemctl daemon-reload
      $SUDO systemctl stop docker.socket 2>/dev/null || true
      $SUDO systemctl stop docker 2>/dev/null || true
      sleep 2
      $SUDO systemctl start docker.socket
      sleep 1
      $SUDO systemctl start docker
      sleep 3
      
      if $SUDO systemctl is-active --quiet docker; then
        echo "✓ Docker started successfully after automatic fix!"
        echo ""
      else
        echo "✗ Docker still failed to start after automatic fix"
        echo ""
        echo "Checking for daemon.json syntax errors..."
        if command -v dockerd &>/dev/null; then
          $SUDO dockerd --validate 2>&1 || true
        fi
        echo ""
        echo "Please check the error messages above."
        if [ -f /etc/docker/daemon.json ]; then
          echo "daemon.json location: /etc/docker/daemon.json"
          echo "Backups are in: /etc/docker/daemon.json.backup.*"
        fi
        echo ""
        return 1
      fi
    else
      echo "Could not automatically detect/fix the error"
      echo ""
      if [ -f /etc/docker/daemon.json ]; then
        echo "daemon.json location: /etc/docker/daemon.json"
        echo "You may need to manually review this file"
      fi
      echo ""
      return 1
    fi
  else
    echo "Docker service started successfully!"
    echo ""
    
    # Test Docker functionality
    echo "Testing Docker functionality..."
    if $SUDO docker info >/dev/null 2>&1; then
      echo "Docker is responding correctly!"
      echo ""
      
      # Additional test: Try to run a simple container to check for runtime errors
      echo "Testing container creation (this may take a moment to download the test image)..."
      if timeout 60 $SUDO docker run --rm hello-world >/dev/null 2>&1; then
        echo "✓ Container test successful - Docker is fully functional"
      else
        echo "⚠ Container test failed - attempting to fix runtime issues..."
        
        # Check for the specific sysctl permission error
        test_output=$(timeout 60 $SUDO docker run --rm hello-world 2>&1 || true)
        if echo "$test_output" | grep -q "open sysctl.*permission denied"; then
          echo ""
          echo "Detected: Container runtime sysctl permission error (CVE-2025-52881)"
          echo ""
          
          # Check containerd version
          local current_containerd=$(check_containerd_version)
          echo "Current containerd.io version: $current_containerd"
          
          if [[ "$current_containerd" =~ 1\.7\.(28-2|29) ]] || [[ "$current_containerd" =~ 1\.7\.(3[0-9]) ]]; then
            echo ""
            echo "=========================================="
            echo "ERROR: Problematic containerd.io version detected!"
            echo "=========================================="
            echo ""
            echo "You have containerd.io $current_containerd which causes this error."
            echo "This script should have installed version 1.7.28-1."
            echo ""
            echo "This is a known issue with newer containerd versions in LXC/Proxmox."
            echo "See: https://github.com/opencontainers/runc/issues/4968"
            echo ""
            echo "To fix manually:"
            echo "  sudo apt-get install -y --allow-downgrades containerd.io=1.7.28-1~${OS}~${VERSION_CODENAME}"
            echo "  sudo apt-mark hold containerd.io"
            echo "  sudo systemctl restart docker"
            echo ""
            return 1
          fi
          
          echo "This error can also indicate corrupted Docker storage"
          echo ""
          echo "=========================================="
          echo "RECOMMENDED ACTION: Full Docker Reset"
          echo "=========================================="
          echo ""
          echo "This will:"
          echo "  • Remove all containers and images"
          echo "  • Clear all Docker volumes"
          echo "  • Reset Docker to clean state"
          echo "  • Fix all permission issues"
          echo ""
          
          # Ask for user confirmation
          read -p "Do you want to proceed with Docker reset? (yes/no): " -r REPLY 2>/dev/null || REPLY="no"
          echo ""
          
          if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]] || [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Performing Docker reset..."
            
            # Stop all Docker services
            $SUDO systemctl stop docker.socket 2>/dev/null || true
            $SUDO systemctl stop docker 2>/dev/null || true
            $SUDO systemctl stop containerd 2>/dev/null || true
            sleep 2
            
            # Backup important data
            timestamp=$(date +%Y%m%d_%H%M%S)
            if [ -d /var/lib/docker ]; then
              echo "Creating backup at /var/lib/docker.backup.$timestamp ..."
              $SUDO mv /var/lib/docker /var/lib/docker.backup.$timestamp
            fi
            
            # Clean all runtime state
            $SUDO rm -rf /run/containerd/* 2>/dev/null || true
            $SUDO rm -rf /var/run/docker/* 2>/dev/null || true
            
            # Restart services - Docker will recreate /var/lib/docker with correct permissions
            echo "Starting Docker services..."
            $SUDO systemctl start containerd 2>/dev/null || true
            sleep 2
            $SUDO systemctl start docker.socket
            sleep 1
            $SUDO systemctl start docker
            sleep 5
            
            # Test again
            echo "Testing Docker after reset..."
            if $SUDO docker run --rm hello-world >/dev/null 2>&1; then
              echo ""
              echo "✓ Docker reset successful!"
              echo "✓ Containers can now run properly"
              echo ""
              echo "Your old data is backed up at:"
              echo "  /var/lib/docker.backup.$timestamp"
              echo ""
            else
              echo ""
              echo "✗ Docker still has issues after reset"
              echo "Please check the logs with:"
              echo "  sudo journalctl -u docker --no-pager -n 100"
            fi
          else
            echo "Docker reset cancelled."
            echo ""
            echo "⚠ WARNING: Your Docker installation has container runtime errors"
            echo "Containers will not be able to start until this is resolved."
            echo ""
            echo "To manually reset later:"
            echo "  sudo systemctl stop docker"
            echo "  sudo mv /var/lib/docker /var/lib/docker.backup"
            echo "  sudo systemctl start docker"
          fi
        else
          echo "⚠ Container test failed for unknown reason"
          echo "Error output:"
          echo "$test_output"
        fi
      fi
    else
      echo "Warning: Docker started but may not be fully functional"
      $SUDO docker info || true
    fi
  fi
  echo ""
}

# Function to show usage information
show_usage() {
  echo "Usage: $0 [command]"
  echo ""
  echo "Commands:"
  echo "  (no arguments)      - Run the full Docker downgrade fix (default)"
  echo "  apply-override      - Apply Docker API override (for newer distros)"
  echo "  remove-override     - Remove Docker API override configuration"
  echo "  help                - Show this help message"
  echo ""
  echo "Default behavior (no arguments):"
  echo "  Installs Docker 28.x (API 1.47/1.48) - compatible with CasaOS"
  echo "  Use on: Ubuntu 20.04, 22.04, 24.04, Debian 11, 12, 13"
  echo ""
  echo "Alternative fix (apply-override):"
  echo "  Sets DOCKER_MIN_API_VERSION=1.24 environment variable"
  echo "  Allows newer Docker versions (29.x) to work with CasaOS"
  echo "  Use on: Distros where Docker 28.x is not available"
  echo ""
  echo "Examples:"
  echo "  $0                  # Run the downgrade fix (default)"
  echo "  $0 apply-override   # Apply API override for newer distros"
  echo "  $0 remove-override  # Remove API override"
  echo ""
}

# Main function
main() {
  # Handle command-line arguments
  if [ $# -gt 0 ]; then
    case "$1" in
      apply-override|override)
        echo "=========================================="
        echo "BigBear CasaOS Docker Version Fix Script 1.6.1"
        echo "=========================================="
        echo ""
        apply_docker_api_override
        exit $?
        ;;
      remove-override|no-override)
        echo "=========================================="
        echo "BigBear CasaOS Docker Version Fix Script 1.6.1"
        echo "=========================================="
        echo ""
        remove_docker_api_override
        exit $?
        ;;
      help|--help|-h)
        echo "=========================================="
        echo "BigBear CasaOS Docker Version Fix Script 1.6.1"
        echo "=========================================="
        echo ""
        show_usage
        exit 0
        ;;
      *)
        echo "ERROR: Unknown command: $1"
        echo ""
        show_usage
        exit 1
        ;;
    esac
  fi
  
  echo "Step 1: Checking system..."
  check_sudo
  detect_os
  
  echo "Step 1a: Verifying Docker 28.x availability..."
  check_docker_availability
  local availability_result=$?
  
  # If return code is 2, Docker 28.x is not available - use override method
  if [ $availability_result -eq 2 ]; then
    echo "Proceeding with Docker API override method..."
    echo ""
    
    # Check if Docker is installed
    if ! command -v docker &>/dev/null; then
      echo "Docker is not installed. Installing latest Docker version..."
      echo ""
      
      # Set up Docker repository
      if ! setup_docker_repository; then
        echo "ERROR: Failed to set up Docker repository"
        exit 1
      fi
      
      # Check if we're in LXC to determine containerd version
      local containerd_spec="containerd.io"
      if check_lxc_environment; then
        echo ""
        echo "=========================================="
        echo "LXC/Proxmox Environment Detected"
        echo "=========================================="
        echo ""
        echo "Installing containerd.io ${CONTAINERD_VERSION} to avoid CVE-2025-52881 AppArmor issues."
        echo "This version is safe and prevents 'permission denied' errors on sysctl."
        echo ""
        echo "For more information, see:"
        echo "https://github.com/opencontainers/runc/issues/4968"
        echo ""
        
        # Resolve exact containerd version
        CONTAINERD_FULL="${CONTAINERD_VERSION}~${OS}~${VERSION_CODENAME}"
        
        # Verify containerd version exists
        if ! apt-cache madison containerd.io 2>/dev/null | grep -q "${CONTAINERD_FULL}"; then
          echo "Exact containerd version ${CONTAINERD_FULL} not found"
          echo "Searching for any 1.7.28-1 variant..."
          CONTAINERD_FULL=$(apt-cache madison containerd.io 2>/dev/null | \
            grep -E '1\.7\.28-1~' | \
            head -n1 | \
            awk '{print $3}')
          
          if [ -z "$CONTAINERD_FULL" ]; then
            echo "ERROR: Could not find containerd.io 1.7.28-1 in repository"
            echo "Available containerd.io versions:"
            apt-cache madison containerd.io 2>/dev/null | head -n 5
            echo ""
            echo "The script will install the latest containerd.io,"
            echo "but containers may not run properly in LXC/Proxmox."
            echo ""
            CONTAINERD_FULL=""
          else
            echo "Found containerd version: $CONTAINERD_FULL"
          fi
        fi
        
        if [ -n "$CONTAINERD_FULL" ]; then
          containerd_spec="containerd.io=${CONTAINERD_FULL}"
        fi
        echo ""
      fi
      
      # Install Docker with appropriate containerd version
      echo "Installing Docker CE (latest version)..."
      echo "  docker-ce (latest)"
      echo "  docker-ce-cli (latest)"
      echo "  ${containerd_spec}"
      echo "  docker-buildx-plugin (latest)"
      echo "  docker-compose-plugin (latest)"
      echo ""
      
      if ! $SUDO apt-get install -y \
        docker-ce \
        docker-ce-cli \
        ${containerd_spec} \
        docker-buildx-plugin \
        docker-compose-plugin; then
        echo ""
        echo "ERROR: Docker installation failed!"
        echo "Please check your internet connection and try again."
        exit 1
      fi
      
      echo "✓ Docker installed successfully"
      echo ""
      
      # Hold containerd if we specified a version (LXC environment)
      if [[ "$containerd_spec" == *"="* ]]; then
        echo "Holding containerd.io at version ${CONTAINERD_VERSION}..."
        $SUDO apt-mark hold containerd.io
        echo ""
      fi
      
      # Enable and start Docker
      echo "Enabling and starting Docker service..."
      $SUDO systemctl enable docker
      $SUDO systemctl start docker
      sleep 3
      echo ""
      
      # Verify Docker is running
      if ! $SUDO systemctl is-active --quiet docker; then
        echo "ERROR: Docker service failed to start after installation"
        echo "Check logs with: sudo journalctl -u docker -n 50"
        exit 1
      fi
      
      echo "✓ Docker service is running"
      echo ""
    else
      echo "Docker is already installed"
      echo ""
      
      # Check containerd version if in LXC environment
      if check_lxc_environment; then
        echo "Checking containerd.io version for LXC/Proxmox compatibility..."
        local current_containerd=$(check_containerd_version)
        echo "Current containerd.io version: $current_containerd"
        echo ""
        
        # Check if we need to downgrade containerd
        if [[ "$current_containerd" =~ 1\.7\.(28-2|29) ]] || [[ "$current_containerd" =~ 1\.7\.(3[0-9]) ]] || [[ "$current_containerd" =~ 1\.7\.[4-9][0-9] ]] || [[ "$current_containerd" =~ 1\.[8-9]\. ]] || [[ "$current_containerd" =~ ^2\. ]]; then
          echo ""
          echo "=========================================="
          echo "CRITICAL: Problematic containerd.io Detected"
          echo "=========================================="
          echo ""
          echo "Your containerd.io version ($current_containerd) is known to cause"
          echo "'permission denied' errors in LXC/Proxmox containers."
          echo ""
          echo "This is due to CVE-2025-52881 AppArmor security patches."
          echo "See: https://github.com/opencontainers/runc/issues/4968"
          echo ""
          echo "Downgrading to containerd.io ${CONTAINERD_VERSION}..."
          echo ""
          
          # Resolve exact containerd version
          CONTAINERD_FULL="${CONTAINERD_VERSION}~${OS}~${VERSION_CODENAME}"
          
          # Verify containerd version exists
          if ! apt-cache madison containerd.io 2>/dev/null | grep -q "${CONTAINERD_FULL}"; then
            echo "Exact containerd version ${CONTAINERD_FULL} not found"
            echo "Searching for any 1.7.28-1 variant..."
            CONTAINERD_FULL=$(apt-cache madison containerd.io 2>/dev/null | \
              grep -E '1\.7\.28-1~' | \
              head -n1 | \
              awk '{print $3}')
            
            if [ -z "$CONTAINERD_FULL" ]; then
              echo "ERROR: Could not find containerd.io 1.7.28-1 in repository"
              echo "Available containerd.io versions:"
              apt-cache madison containerd.io 2>/dev/null | head -n 5
              echo ""
              echo "⚠ WARNING: Cannot fix containerd version"
              echo "Containers may not run properly in LXC/Proxmox."
              echo ""
            else
              echo "Found containerd version: $CONTAINERD_FULL"
              echo ""
              
              # Stop Docker services
              echo "Stopping Docker services..."
              $SUDO systemctl stop docker 2>/dev/null || true
              $SUDO systemctl stop containerd 2>/dev/null || true
              sleep 2
              echo ""
              
              # Downgrade containerd
              echo "Installing containerd.io=${CONTAINERD_FULL}..."
              if $SUDO apt-get install -y --allow-downgrades containerd.io=${CONTAINERD_FULL}; then
                echo "✓ Successfully downgraded containerd.io"
                echo ""
                
                # Hold the package
                echo "Holding containerd.io at version ${CONTAINERD_VERSION}..."
                $SUDO apt-mark hold containerd.io
                echo ""
                
                # Restart services
                echo "Restarting Docker services..."
                $SUDO systemctl start containerd 2>/dev/null || true
                sleep 2
                $SUDO systemctl start docker
                sleep 3
                echo ""
                
                if $SUDO systemctl is-active --quiet docker; then
                  echo "✓ Docker service restarted successfully"
                  echo ""
                else
                  echo "⚠ WARNING: Docker service failed to start after containerd downgrade"
                  echo "Check logs with: sudo journalctl -u docker -n 50"
                  echo ""
                fi
              else
                echo "ERROR: Failed to downgrade containerd.io"
                echo ""
              fi
            fi
          else
            echo "Found containerd version: $CONTAINERD_FULL"
            echo ""
            
            # Stop Docker services
            echo "Stopping Docker services..."
            $SUDO systemctl stop docker 2>/dev/null || true
            $SUDO systemctl stop containerd 2>/dev/null || true
            sleep 2
            echo ""
            
            # Downgrade containerd
            echo "Installing containerd.io=${CONTAINERD_FULL}..."
            if $SUDO apt-get install -y --allow-downgrades containerd.io=${CONTAINERD_FULL}; then
              echo "✓ Successfully downgraded containerd.io"
              echo ""
              
              # Hold the package
              echo "Holding containerd.io at version ${CONTAINERD_VERSION}..."
              $SUDO apt-mark hold containerd.io
              echo ""
              
              # Restart services
              echo "Restarting Docker services..."
              $SUDO systemctl start containerd 2>/dev/null || true
              sleep 2
              $SUDO systemctl start docker
              sleep 3
              echo ""
              
              if $SUDO systemctl is-active --quiet docker; then
                echo "✓ Docker service restarted successfully"
                echo ""
              else
                echo "⚠ WARNING: Docker service failed to start after containerd downgrade"
                echo "Check logs with: sudo journalctl -u docker -n 50"
                echo ""
              fi
            else
              echo "ERROR: Failed to downgrade containerd.io"
              echo ""
            fi
          fi
        else
          echo "✓ containerd.io version is compatible (no downgrade needed)"
          echo ""
        fi
      fi
    fi
    
    # Now apply the override configuration
    if apply_docker_api_override; then
      echo ""
      echo "=========================================="
      echo "Docker API Override Applied Successfully!"
      echo "=========================================="
      echo ""
      echo "Your system is now configured to work with CasaOS using newer Docker versions."
      echo ""
      
      # Add user to docker group
      add_user_to_docker_group
      
      # Restart CasaOS if installed
      if check_casaos; then
        echo "Restarting CasaOS services..."
        stop_casaos_services
        sleep 2
        start_casaos_services
      fi
      
      echo "Setup complete! CasaOS should now work properly with Docker."
      echo ""
      exit 0
    else
      echo ""
      echo "ERROR: Failed to apply Docker API override"
      echo "Please check the error messages above."
      exit 1
    fi
  fi
  
  echo "Step 1b: Checking for Snap Docker installation..."
  if ! check_and_remove_snap_docker; then
    echo "=========================================="
    echo "ERROR: Failed to remove Snap Docker"
    echo "=========================================="
    echo ""
    echo "The script cannot continue with Snap Docker installed."
    echo "Please manually remove Snap Docker and try again:"
    echo "  sudo snap remove --purge docker"
    echo ""
    exit 1
  fi
  
  echo "Step 1c: Checking for multiple Docker binaries..."
  check_docker_binary_locations
  
  echo "Step 2: Checking for CasaOS..."
  CASAOS_INSTALLED=false
  if check_casaos; then
    CASAOS_INSTALLED=true
  fi
  echo ""
  
  echo "Step 2a: Checking environment..."
  if check_lxc_environment; then
    echo "Running in LXC/Proxmox container - will use containerd.io ${CONTAINERD_VERSION}"
    echo "This avoids CVE-2025-52881 AppArmor sysctl permission issues."
  else
    echo "Running on standard system (not LXC)"
  fi
  echo ""
  
  echo "Step 3: Displaying current Docker versions..."
  display_versions
  
  # Store the current API version before making changes
  echo "Step 3a: Checking current Docker API version..."
  CURRENT_API_VERSION=$(get_docker_api_version)
  if [ -n "$CURRENT_API_VERSION" ]; then
    echo "Current Docker API version: $CURRENT_API_VERSION"
  else
    echo "Unable to determine current Docker API version"
  fi
  echo ""
  
  echo "Step 4: Stopping CasaOS services (if installed)..."
  if [ "$CASAOS_INSTALLED" = true ]; then
    stop_casaos_services
  else
    echo "CasaOS not installed, skipping service stop."
    echo ""
  fi
  
  echo "Step 5: Removing standalone docker-compose if present..."
  remove_standalone_docker_compose
  
  echo "Step 6: Cleaning Docker state and fixing permissions..."
  clean_docker_state
  
  echo "Step 7: Installing Docker version compatible with CasaOS..."
  if ! downgrade_docker; then
    echo "=========================================="
    echo "ERROR: Docker installation/configuration failed"
    echo "=========================================="
    echo ""
    echo "Attempting to start Docker..."
    
    # Try to start Docker
    $SUDO systemctl start docker.socket 2>/dev/null || true
    $SUDO systemctl start docker
    sleep 3
    
    if ! $SUDO systemctl is-active --quiet docker; then
      echo "Could not start Docker. Please check the error messages above."
      exit 1
    fi
    
    echo "Docker started with previous configuration."
    echo "The version downgrade may have failed, but Docker is running."
    echo ""
  fi
  
  echo "=========================================="
  echo "Docker Configuration Complete!"
  echo "=========================================="
  echo ""
  echo "Installed Docker Package Versions:"
  dpkg -l | grep -E "docker-ce|containerd.io" | awk '{print "  " $2 " = " $3}' 2>/dev/null || echo "Unable to query package versions"
  echo ""
  echo "Docker Version Information:"
  $SUDO docker version 2>&1 || echo "Unable to get Docker version"
  echo ""
  if command -v docker &>/dev/null; then
    echo "Docker Compose Version:"
    $SUDO docker compose version 2>&1 || echo "Unable to get Docker Compose version"
  fi
  echo ""
  
  echo "Step 7a: Verifying Docker API version change..."
  if ! verify_docker_api_version; then
    echo "=========================================="
    echo "WARNING: Docker API Version Issue Detected"
    echo "=========================================="
    echo ""
    echo "The Docker API version may not have changed as expected."
    echo ""
    
    # Additional diagnostics
    echo "Diagnostic Information:"
    echo ""
    
    # Check dockerd binary version
    if command -v dockerd &>/dev/null; then
      echo "1. dockerd binary version:"
      dockerd --version 2>/dev/null || echo "   Unable to get dockerd version"
      echo ""
    fi
    
    # Check running dockerd process
    if pgrep -x dockerd >/dev/null 2>&1; then
      echo "2. Running dockerd process(es):"
      pgrep -a dockerd 2>/dev/null || true
      echo ""
    else
      echo "2. No dockerd process is currently running"
      echo ""
    fi
    
    # Check which docker binary
    echo "3. Docker binary in use:"
    which docker 2>/dev/null || echo "   docker command not found"
    if command -v docker &>/dev/null; then
      local docker_bin=$(which docker)
      local docker_real=$(readlink -f "$docker_bin" 2>/dev/null || echo "$docker_bin")
      echo "   Binary location: $docker_bin"
      if [ "$docker_bin" != "$docker_real" ]; then
        echo "   -> Points to: $docker_real"
      fi
    fi
    echo ""
    
    # Check installed packages
    echo "4. Installed Docker packages:"
    dpkg -l | grep -E "docker-ce|containerd.io" | awk '{print "   " $2 " = " $3}' 2>/dev/null || echo "   Unable to query packages"
    echo ""
    
    # Check Docker service status
    echo "5. Docker service status:"
    if $SUDO systemctl is-active --quiet docker; then
      echo "   Docker service is active"
    else
      echo "   Docker service is NOT active"
    fi
    echo ""
    
    echo "=========================================="
    echo "Troubleshooting steps:"
    echo "=========================================="
    echo ""
    echo "  1. Verify the dockerd binary was actually replaced:"
    echo "     dockerd --version"
    echo "     (Should show version 28.0.x)"
    echo ""
    echo "  2. Manually restart Docker to ensure new binary loads:"
    echo "     sudo systemctl stop docker"
    echo "     sudo pkill -9 dockerd"
    echo "     sudo systemctl start docker"
    echo "     docker version"
    echo ""
    echo "  3. Check if there are multiple Docker installations:"
    echo "     which -a docker"
    echo "     which -a dockerd"
    echo ""
    echo "  4. Verify package installation succeeded:"
    echo "     dpkg -l | grep docker-ce"
    echo "     (Should show version 5:28.0.x-1~...)"
    echo ""
    echo "  5. Check Docker daemon logs for errors:"
    echo "     sudo journalctl -u docker --no-pager -n 50"
    echo ""
  fi
  
  echo "Step 8: Configuring Docker permissions..."
  add_user_to_docker_group
  
  if [ "$CASAOS_INSTALLED" = true ]; then
    echo "Step 9: Restarting CasaOS services..."
    start_casaos_services
    
    echo "=========================================="
    echo "CasaOS Docker Fix Complete!"
    echo "=========================================="
    echo ""
    echo "Docker has been set to version 28.0.x (API 1.47 - compatible with CasaOS)"
    echo "Docker packages have been held to prevent automatic upgrades."
    echo ""
    echo "To allow Docker to be upgraded in the future, run:"
    echo "  sudo apt-mark unhold docker-ce docker-ce-cli containerd.io"
    echo ""
    echo "If you found this helpful, please consider supporting BigBear:"
    echo "  https://ko-fi.com/bigbeartechworld"
    echo ""
  else
    echo "=========================================="
    echo "Docker version has been set to 28.0.x"
    echo "This version is compatible with CasaOS API 1.47"
    echo "=========================================="
    echo ""
  fi
  
  echo "The Docker client version error should now be resolved."
  echo "You can now run your Docker commands without API version issues."
  echo ""
  
  # Final verification
  NEW_API_VERSION=$(get_docker_api_version)
  if [ -n "$NEW_API_VERSION" ]; then
    if [ "$CURRENT_API_VERSION" != "$NEW_API_VERSION" ]; then
      echo "✓ Docker API version changed from $CURRENT_API_VERSION to $NEW_API_VERSION"
    else
      echo "⚠ Docker API version unchanged: $NEW_API_VERSION"
      echo "  This may indicate the downgrade didn't take effect."
      echo "  Please review the troubleshooting steps above."
    fi
  fi
  echo ""
}

# Execute the main function
main
