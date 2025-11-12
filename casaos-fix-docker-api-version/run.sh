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
echo "BigBear CasaOS Docker Version Fix Script 1.1.0"
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
# Using Docker 24.x series which supports API 1.43 (older CasaOS versions)
# but is also compatible with API 1.44 (newer Docker daemons)
readonly DOCKER_CE_VERSION="5:24.0.7-1~"
readonly DOCKER_CLI_VERSION="5:24.0.7-1~"
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

# Function to clean Docker state and fix permissions
clean_docker_state() {
  echo "Cleaning Docker state and fixing permissions..."
  
  # Stop Docker first
  if $SUDO systemctl is-active --quiet docker; then
    echo "Stopping Docker service..."
    $SUDO systemctl stop docker
    sleep 2
    echo ""
  fi
  
  # Clean up Docker runtime state
  if [ -d /var/run/docker ]; then
    echo "Cleaning Docker runtime state..."
    $SUDO rm -rf /var/run/docker/*
    echo ""
  fi
  
  # Fix containerd state
  if [ -d /run/containerd ]; then
    echo "Cleaning containerd state..."
    $SUDO rm -rf /run/containerd/runc
    $SUDO rm -rf /run/containerd/io.containerd*
    echo ""
  fi
  
  # Clean up any stale container state
  if [ -d /var/lib/docker/containers ]; then
    echo "Cleaning container state..."
    $SUDO find /var/lib/docker/containers -name "*.pid" -delete 2>/dev/null || true
    echo ""
  fi
  
  # Fix core Docker directory permissions
  if [ -d /var/lib/docker ]; then
    echo "Fixing Docker directory permissions..."
    $SUDO chown -R root:root /var/lib/docker
    $SUDO chmod 711 /var/lib/docker
    
    # Fix specific subdirectories
    [ -d /var/lib/docker/overlay2 ] && $SUDO chmod 755 /var/lib/docker/overlay2
    [ -d /var/lib/docker/containers ] && $SUDO chmod 755 /var/lib/docker/containers
    [ -d /var/lib/docker/image ] && $SUDO chmod 755 /var/lib/docker/image
    [ -d /var/lib/docker/volumes ] && $SUDO chmod 755 /var/lib/docker/volumes
    
    # Fix overlay2/l directory which is critical for overlay2 storage
    if [ -d /var/lib/docker/overlay2/l ]; then
      $SUDO chmod 700 /var/lib/docker/overlay2/l
    fi
    echo ""
  fi
  
  echo "Docker state cleanup complete"
  echo ""
}

# Function to downgrade Docker to compatible version
downgrade_docker() {
  echo "Setting up Docker repository..."
  $SUDO apt-get update
  echo ""

  echo "Installing prerequisites..."
  $SUDO apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
  echo ""

  # Add Docker's official GPG key
  echo "Adding Docker's official GPG key..."
  $SUDO install -m 0755 -d /etc/apt/keyrings
  $SUDO curl -fsSL https://download.docker.com/linux/${OS}/gpg -o /etc/apt/keyrings/docker.asc
  $SUDO chmod a+r /etc/apt/keyrings/docker.asc
  echo ""

  # Set up the stable repository
  echo "Setting up Docker repository..."
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${OS} \
    ${VERSION_CODENAME} stable" | \
    $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null
  echo ""

  # Update package index with new repository
  echo "Updating package lists with Docker repository..."
  $SUDO apt-get update
  echo ""

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
    
    $SUDO apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
    echo ""
  fi

  # Install specific Docker version compatible with CasaOS
  echo "Installing Docker version compatible with CasaOS (24.0.7)..."
  
  ARCH=$(dpkg --print-architecture)
  DOCKER_CE_FULL="${DOCKER_CE_VERSION}${OS}~${VERSION_CODENAME}"
  DOCKER_CLI_FULL="${DOCKER_CLI_VERSION}${OS}~${VERSION_CODENAME}"
  CONTAINERD_FULL="${CONTAINERD_VERSION}~${OS}~${VERSION_CODENAME}"
  
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
  
  echo "Installing docker-ce-cli=${DOCKER_CLI_FULL}"
  echo "Installing docker-ce=${DOCKER_CE_FULL}"
  echo "Installing containerd.io=${CONTAINERD_FULL}"
  echo ""
  
  if ! $SUDO apt-get install -y --allow-downgrades \
    docker-ce-cli=${DOCKER_CLI_FULL} \
    docker-ce=${DOCKER_CE_FULL} \
    containerd.io=${CONTAINERD_FULL} \
    docker-buildx-plugin \
    docker-compose-plugin; then
      echo ""
      echo "Specific version installation failed. Trying alternative method..."
      echo ""
      
      # Fallback: try without the full version string but keep containerd specific
      if ! $SUDO apt-get install -y --allow-downgrades \
        docker-ce=5:24.0.* \
        docker-ce-cli=5:24.0.* \
        containerd.io=${CONTAINERD_FULL} \
        docker-buildx-plugin \
        docker-compose-plugin; then
          # Last resort: try with pattern match for containerd
          echo ""
          echo "Trying with containerd.io version pattern..."
          echo ""
          if ! $SUDO apt-get install -y --allow-downgrades \
            docker-ce=5:24.0.* \
            docker-ce-cli=5:24.0.* \
            containerd.io=1.7.28-1* \
            docker-buildx-plugin \
            docker-compose-plugin; then
              echo ""
              echo "ERROR: All installation methods failed!"
              echo "Please check your internet connection and try again."
              return 1
          fi
      fi
  fi
  echo ""

  # Hold packages to prevent auto-upgrade
  echo "Holding Docker packages at current version..."
  $SUDO apt-mark hold docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  echo ""

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

  # Fix overlay2 permissions if directory exists
  if [ -d /var/lib/docker/overlay2 ]; then
    echo "Fixing overlay2 directory permissions..."
    $SUDO chown -R root:root /var/lib/docker/overlay2
    $SUDO chmod -R 755 /var/lib/docker/overlay2
    if [ -d /var/lib/docker/overlay2/l ]; then
      $SUDO chmod 700 /var/lib/docker/overlay2/l
    fi
    echo ""
  fi

  # Reload systemd and restart Docker service
  echo "Reloading systemd daemon..."
  $SUDO systemctl daemon-reload
  echo ""

  # Stop docker socket to prevent auto-restart
  echo "Stopping Docker socket and service..."
  $SUDO systemctl stop docker.socket 2>/dev/null || true
  $SUDO systemctl stop docker
  sleep 2
  echo ""

  # Enable and start docker socket first, then service
  echo "Enabling and starting Docker socket..."
  $SUDO systemctl enable docker.socket 2>/dev/null || true
  $SUDO systemctl start docker.socket
  sleep 1
  echo ""

  echo "Enabling and starting Docker service..."
  $SUDO systemctl enable docker
  $SUDO systemctl start docker
  sleep 3
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
            
            # Recreate Docker directory structure
            echo "Creating fresh Docker directory structure..."
            $SUDO mkdir -p /var/lib/docker
            $SUDO chmod 711 /var/lib/docker
            
            # Clean all runtime state
            $SUDO rm -rf /run/containerd/* 2>/dev/null || true
            $SUDO rm -rf /var/run/docker/* 2>/dev/null || true
            
            # Restart services
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

# Main function
main() {
  echo "Step 1: Checking system..."
  check_sudo
  detect_os
  
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
  echo "Docker API Version:"
  $SUDO docker version 2>&1 || echo "Unable to get Docker version"
  echo ""
  if command -v docker &>/dev/null; then
    echo "Docker Compose Version:"
    $SUDO docker compose version 2>&1 || echo "Unable to get Docker Compose version"
  fi
  echo ""
  
  echo "Step 8: Configuring Docker permissions..."
  add_user_to_docker_group
  
  if [ "$CASAOS_INSTALLED" = true ]; then
    echo "Step 9: Restarting CasaOS services..."
    start_casaos_services
    
    echo "=========================================="
    echo "CasaOS Docker Fix Complete!"
    echo "=========================================="
    echo ""
    echo "Docker has been set to version 24.0.7 (compatible with CasaOS)"
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
    echo "Docker version has been set to 24.0.7"
    echo "This version is compatible with CasaOS API 1.43"
    echo "=========================================="
    echo ""
  fi
  
  echo "The Docker client version error should now be resolved."
  echo "You can now run your Docker commands without API version issues."
}

# Execute the main function
main
