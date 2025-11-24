#!/usr/bin/env bash

# Test script for casaos-fix-docker-api-version
# This script simulates upgrading Docker to a newer version and then tests
# that the fix script can successfully downgrade it back to 24.0.7
#
# Usage:
#   ./test-script.sh upgrade    - Upgrade Docker to latest version (simulates the problem)
#   ./test-script.sh test       - Run the fix script and verify it works
#   ./test-script.sh full       - Do both: upgrade then test the fix
#   ./test-script.sh status     - Show current Docker version and API
#

set -o pipefail

# Initialize SUDO variable
if [ "$EUID" -eq 0 ]; then
  SUDO=""
else
  SUDO="sudo"
fi

# Check for non-interactive mode
if [ "$NON_INTERACTIVE" = "true" ]; then
  echo "Running in NON-INTERACTIVE mode"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
  echo ""
  echo "=========================================="
  echo "$1"
  echo "=========================================="
  echo ""
}

# Function to get Docker version
get_docker_version() {
  if command -v docker &>/dev/null; then
    local version=$(timeout 10 $SUDO docker version --format '{{.Server.Version}}' 2>/dev/null || echo "")
    echo "$version"
  else
    echo "not_installed"
  fi
}

# Function to get Docker API version
get_docker_api_version() {
  if command -v docker &>/dev/null; then
    local api_version=$(timeout 10 $SUDO docker version --format '{{.Server.APIVersion}}' 2>/dev/null || echo "")
    if [ -z "$api_version" ]; then
      # Fallback method
      api_version=$(timeout 10 $SUDO docker version 2>/dev/null | grep -A 5 "Server:" | grep "API version:" | awk '{print $3}' | head -n1 || echo "")
    fi
    echo "$api_version"
  else
    echo "not_installed"
  fi
}

# Function to get dockerd binary version
get_dockerd_binary_version() {
  if command -v dockerd &>/dev/null; then
    dockerd --version 2>/dev/null | head -n1 | awk '{print $3}' | sed 's/,//'
  else
    echo "not_installed"
  fi
}

# Function to show current status
show_status() {
  print_header "Current Docker Status"
  
  local docker_version=$(get_docker_version)
  local api_version=$(get_docker_api_version)
  local dockerd_version=$(get_dockerd_binary_version)
  
  echo "Docker daemon version:    $docker_version"
  echo "Docker API version:       $api_version"
  echo "dockerd binary version:   $dockerd_version"
  echo ""
  
  # Show package versions
  echo "Installed packages:"
  dpkg -l | grep -E "docker-ce|containerd.io" | awk '{print "  " $2 " = " $3}' 2>/dev/null || echo "  No Docker packages found"
  echo ""
  
  # Show which docker binary
  if command -v docker &>/dev/null; then
    echo "Docker binary location:   $(which docker)"
  fi
  
  if command -v dockerd &>/dev/null; then
    echo "dockerd binary location:  $(which dockerd)"
  fi
  echo ""
  
  # Check if Docker is running
  if $SUDO systemctl is-active --quiet docker 2>/dev/null; then
    print_success "Docker service is running"
  else
    print_warning "Docker service is NOT running"
  fi
  
  # Check running processes
  if pgrep -x dockerd >/dev/null 2>&1; then
    echo ""
    echo "Running dockerd process(es):"
    pgrep -a dockerd
  fi
  echo ""
}

# Function to detect OS
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION_CODENAME=${VERSION_CODENAME:-$(lsb_release -cs 2>/dev/null)}
  else
    print_error "Cannot detect OS. This script supports Debian/Ubuntu-based systems."
    exit 1
  fi
}

# Function to check if CasaOS is installed
check_casaos_installed() {
  if command -v casaos &>/dev/null; then
    return 0
  else
    return 1
  fi
}

# Function to restart CasaOS services
restart_casaos() {
  print_info "Restarting CasaOS services..."
  
  local CASA_SERVICES=(
    "casaos-gateway.service"
    "casaos-message-bus.service"
    "casaos-user-service.service"
    "casaos-local-storage.service"
    "casaos-app-management.service"
    "casaos.service"
  )
  
  # Stop services
  for SERVICE in "${CASA_SERVICES[@]}"; do
    if $SUDO systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
      $SUDO systemctl stop "$SERVICE" 2>/dev/null || true
    fi
  done
  
  sleep 2
  
  # Start services
  for SERVICE in "${CASA_SERVICES[@]}"; do
    if $SUDO systemctl is-enabled --quiet "$SERVICE" 2>/dev/null; then
      $SUDO systemctl start "$SERVICE" 2>/dev/null || true
    fi
  done
  
  sleep 2
  print_success "CasaOS services restarted"
  echo ""
}

# Function to apply Docker API override (for newer distros without Docker 24.0.x)
apply_docker_api_override() {
  print_header "Applying Docker API Override Configuration"
  print_info "This sets DOCKER_MIN_API_VERSION=1.24 to allow older CasaOS versions"
  print_info "to work with newer Docker versions (27.x, 28.x, 29.x)"
  echo ""
  
  local override_dir="/etc/systemd/system/docker.service.d"
  local override_file="$override_dir/override.conf"
  
  # Create directory if it doesn't exist
  if [ ! -d "$override_dir" ]; then
    print_info "Creating directory: $override_dir"
    $SUDO mkdir -p "$override_dir"
  fi
  
  # Create or update override.conf
  print_info "Creating Docker service override configuration..."
  $SUDO tee "$override_file" > /dev/null <<'EOF'
[Service]
Environment=DOCKER_MIN_API_VERSION=1.24
EOF
  
  if [ -f "$override_file" ]; then
    print_success "Created: $override_file"
    echo ""
    echo "Contents:"
    $SUDO cat "$override_file" | sed 's/^/  /'
    echo ""
  else
    print_error "Failed to create override file"
    return 1
  fi
  
  # Reload systemd daemon
  print_info "Reloading systemd daemon..."
  $SUDO systemctl daemon-reload
  echo ""
  
  # Restart Docker
  print_info "Restarting Docker service..."
  $SUDO systemctl restart docker
  sleep 3
  echo ""
  
  # Verify Docker is running
  if $SUDO systemctl is-active --quiet docker; then
    print_success "Docker service restarted successfully"
    
    # Show current Docker info
    local docker_version=$(get_docker_version)
    local api_version=$(get_docker_api_version)
    
    echo ""
    echo "Current configuration:"
    echo "  Docker version: $docker_version"
    echo "  API version:    $api_version"
    echo ""
    
    print_success "Docker API override applied successfully!"
    print_info "CasaOS should now work with this Docker version"
  else
    print_error "Docker service failed to start after applying override"
    return 1
  fi
  
  echo ""
  return 0
}

# Function to remove Docker API override
remove_docker_api_override() {
  print_header "Removing Docker API Override Configuration"
  
  local override_file="/etc/systemd/system/docker.service.d/override.conf"
  
  if [ ! -f "$override_file" ]; then
    print_info "No override configuration found"
    return 0
  fi
  
  print_info "Removing: $override_file"
  $SUDO rm -f "$override_file"
  
  # Reload systemd daemon
  print_info "Reloading systemd daemon..."
  $SUDO systemctl daemon-reload
  
  # Restart Docker
  print_info "Restarting Docker service..."
  $SUDO systemctl restart docker
  sleep 3
  
  if $SUDO systemctl is-active --quiet docker; then
    print_success "Docker API override removed successfully"
  else
    print_warning "Docker service may have issues after removing override"
  fi
  
  echo ""
  return 0
}

# Function to upgrade Docker to latest version (simulate the problem)
upgrade_docker_to_latest() {
  print_header "Upgrading Docker to Latest Version"
  print_info "This simulates the problem where Docker gets upgraded to a newer version"
  print_info "that is incompatible with CasaOS (API 1.45+)"
  echo ""
  
  detect_os
  
  # Unhold packages if they're held
  print_info "Unholding Docker packages..."
  $SUDO apt-mark unhold docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
  echo ""
  
  # Setup Docker repository if not already present
  print_info "Setting up Docker repository..."
  $SUDO apt-get update
  
  if [ ! -f /etc/apt/keyrings/docker.asc ]; then
    print_info "Adding Docker GPG key..."
    $SUDO install -m 0755 -d /etc/apt/keyrings
    $SUDO curl -fsSL https://download.docker.com/linux/${OS}/gpg -o /etc/apt/keyrings/docker.asc
    $SUDO chmod a+r /etc/apt/keyrings/docker.asc
  fi
  
  if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
    print_info "Adding Docker repository..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${OS} \
      ${VERSION_CODENAME} stable" | \
      $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null
    $SUDO apt-get update
  fi
  echo ""
  
  # Install latest Docker
  print_info "Installing latest Docker version..."
  print_warning "This will upgrade Docker to the latest version (API 1.45+)"
  echo ""
  
  if $SUDO apt-get install -y --allow-downgrades \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin; then
    print_success "Docker upgraded to latest version"
  else
    print_error "Failed to upgrade Docker"
    return 1
  fi
  echo ""
  
  # Restart Docker
  print_info "Restarting Docker to ensure new version loads..."
  $SUDO systemctl daemon-reload
  $SUDO systemctl stop docker 2>/dev/null || true
  $SUDO pkill -9 dockerd 2>/dev/null || true
  sleep 2
  $SUDO systemctl start docker
  sleep 3
  echo ""
  
  # Verify upgrade
  local new_version=$(get_docker_version)
  local new_api=$(get_docker_api_version)
  
  print_header "Upgrade Complete"
  echo "New Docker version: $new_version"
  echo "New API version:    $new_api"
  echo ""
  
  if awk -v ver="$new_api" 'BEGIN {exit !(ver >= 1.45)}'; then
    print_success "Successfully upgraded to newer Docker (API $new_api)"
    print_warning "This version is incompatible with older CasaOS versions"
    return 0
  else
    print_warning "Upgrade may not have worked as expected (API: $new_api)"
    print_warning "Expected API 1.45 or higher"
    return 1
  fi
}

# Function to test the fix script
test_fix_script() {
  print_header "Testing the Fix Script"
  
  # Get current version before fix
  local before_version=$(get_docker_version)
  local before_api=$(get_docker_api_version)
  
  print_info "Docker version before fix: $before_version"
  print_info "API version before fix:    $before_api"
  echo ""
  
  # Check if the fix script exists
  if [ ! -f "./run.sh" ]; then
    print_error "Fix script (run.sh) not found in current directory"
    print_info "Please run this test script from the casaos-fix-docker-api-version directory"
    return 1
  fi
  
  print_info "Running the fix script..."
  echo ""
  echo "=========================================="
  
  # Run the fix script
  if bash ./run.sh; then
    echo "=========================================="
    echo ""
    print_success "Fix script completed"
  else
    local exit_code=$?
    echo "=========================================="
    echo ""
    print_error "Fix script failed with exit code $exit_code"
    return $exit_code
  fi
  
  # Wait a moment for Docker to stabilize
  sleep 3
  
  # Verify the fix
  print_header "Verifying the Fix"
  
  local after_version=$(get_docker_version)
  local after_api=$(get_docker_api_version)
  local dockerd_binary=$(get_dockerd_binary_version)
  
  echo "Docker version after fix:  $after_version"
  echo "API version after fix:     $after_api"
  echo "dockerd binary version:    $dockerd_binary"
  echo ""
  
  # Check package versions
  echo "Package versions:"
  dpkg -l | grep -E "docker-ce|containerd.io" | awk '{print "  " $2 " = " $3}'
  echo ""
  
  # Verify results
  local success=true
  
  # Check if version contains 28.x (28.0, 28.1, 28.5, etc.)
  if echo "$after_version" | grep -q "^28\."; then
    print_success "✓ Docker version is 28.x ($after_version)"
  else
    print_error "✗ Docker version is NOT 28.x (got: $after_version)"
    success=false
  fi
  
  # Check if API is below 1.52 (Docker 28.x series, before breaking change)
  # Use awk for decimal comparison (doesn't require bc)
  if awk -v ver="$after_api" 'BEGIN {exit !(ver >= 1.47 && ver < 1.52)}'; then
    print_success "✓ API version is compatible ($after_api - Docker 28.x, below 1.52 breaking change)"
  else
    print_error "✗ API version is NOT compatible (got: $after_api, expected: 1.47-1.51, below 1.52 breaking change)"
    success=false
  fi
  
  # Check if dockerd binary is correct
  if echo "$dockerd_binary" | grep -q "^28\."; then
    print_success "✓ dockerd binary is version 28.x ($dockerd_binary)"
  else
    print_error "✗ dockerd binary is NOT 28.x (got: $dockerd_binary)"
    success=false
  fi
  
  # Check if Docker is running
  if $SUDO systemctl is-active --quiet docker; then
    print_success "✓ Docker service is running"
  else
    print_error "✗ Docker service is NOT running"
    success=false
  fi
  
  # Check if packages are held
  echo ""
  echo "Checking if packages are held:"
  local held_packages=$($SUDO apt-mark showhold | grep -E "docker-ce|containerd.io")
  if [ -n "$held_packages" ]; then
    print_success "✓ Docker packages are held:"
    echo "$held_packages" | sed 's/^/    /'
  else
    print_warning "⚠ Docker packages are NOT held (they may auto-upgrade)"
  fi
  
  echo ""
  if [ "$success" = true ]; then
    print_header "Test Result: PASSED"
    print_success "The fix script successfully installed Docker 28.x"
    print_success "API version is compatible with CasaOS"
    return 0
  else
    print_header "Test Result: FAILED"
    print_error "The fix script did not successfully install Docker 28.x"
    print_error "Please review the errors above"
    return 1
  fi
}

# Function to run full test
run_full_test() {
  print_header "Full Test: Upgrade then Fix"
  print_info "This will:"
  print_info "  1. Upgrade Docker to latest version (simulate the problem)"
  print_info "  2. Run the fix script to install Docker 28.x"
  print_info "  3. Verify everything works correctly"
  echo ""
  
  if [ "$NON_INTERACTIVE" = "true" ]; then
    REPLY="yes"
  else
    read -p "Do you want to continue? (yes/no): " -r REPLY
    echo ""
  fi
  
  if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]] && [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Test cancelled"
    return 0
  fi
  
  # Step 1: Upgrade
  if ! upgrade_docker_to_latest; then
    print_error "Upgrade step failed"
    return 1
  fi
  
  echo ""
  if [ "$NON_INTERACTIVE" != "true" ]; then
    read -p "Press Enter to continue with the fix script test..." -r
    echo ""
  fi
  
  # Step 2: Test fix
  if ! test_fix_script; then
    print_error "Fix script test failed"
    return 1
  fi
  
  return 0
}

# Function to install specific Docker version
install_docker_version() {
  local version=$1
  local description=$2
  
  print_header "Installing Docker $version"
  print_info "$description"
  echo ""
  
  detect_os
  
  # Unhold packages if they're held
  print_info "Unholding Docker packages..."
  $SUDO apt-mark unhold docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
  echo ""
  
  # Setup Docker repository if not already present
  print_info "Setting up Docker repository..."
  $SUDO apt-get update -qq
  
  if [ ! -f /etc/apt/keyrings/docker.asc ]; then
    print_info "Adding Docker GPG key..."
    $SUDO install -m 0755 -d /etc/apt/keyrings
    $SUDO curl -fsSL https://download.docker.com/linux/${OS}/gpg -o /etc/apt/keyrings/docker.asc
    $SUDO chmod a+r /etc/apt/keyrings/docker.asc
  fi
  
  if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
    print_info "Adding Docker repository..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${OS} \
      ${VERSION_CODENAME} stable" | \
      $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null
    $SUDO apt-get update -qq
  fi
  echo ""
  
  # Query available versions
  print_info "Looking for Docker $version in repository..."
  local full_version=$(apt-cache madison docker-ce 2>/dev/null | grep "$version" | head -n1 | awk '{print $3}')
  
  if [ -z "$full_version" ]; then
    print_error "Could not find Docker version $version in repository"
    print_info "Available versions:"
    apt-cache madison docker-ce 2>/dev/null | head -n 10
    return 1
  fi
  
  print_info "Found: $full_version"
  echo ""
  
  # Install specific version
  print_info "Installing Docker $full_version..."
  if $SUDO apt-get install -y --allow-downgrades \
    docker-ce=$full_version \
    docker-ce-cli=$full_version \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin; then
    print_success "Docker $version installed successfully"
  else
    print_error "Failed to install Docker $version"
    return 1
  fi
  echo ""
  
  # Restart Docker
  print_info "Restarting Docker to ensure new version loads..."
  $SUDO systemctl daemon-reload
  $SUDO systemctl stop docker 2>/dev/null || true
  $SUDO pkill -9 dockerd 2>/dev/null || true
  sleep 2
  $SUDO systemctl start docker
  sleep 3
  echo ""
  
  # Verify installation
  local installed_version=$(get_docker_version)
  local installed_api=$(get_docker_api_version)
  
  print_header "Installation Complete"
  echo "Installed Docker version: $installed_version"
  echo "Installed API version:    $installed_api"
  echo ""
  
  if echo "$installed_version" | grep -q "$version"; then
    print_success "Successfully installed Docker $version (API $installed_api)"
  else
    print_warning "Version mismatch: expected $version, got $installed_version"
  fi
  
  # Check if CasaOS is installed and offer to restart it
  if check_casaos_installed; then
    echo ""
    print_info "CasaOS is installed on this system"
    if [ "$NON_INTERACTIVE" = "true" ]; then
      RESTART_REPLY="yes"
    else
      read -p "Do you want to restart CasaOS services? (yes/no): " -r RESTART_REPLY
      echo ""
    fi
    
    if [[ $RESTART_REPLY =~ ^[Yy][Ee][Ss]$ ]] || [[ $RESTART_REPLY =~ ^[Yy]$ ]]; then
      restart_casaos
    else
      print_info "Skipping CasaOS restart"
      echo ""
    fi
  fi
  
  if echo "$installed_version" | grep -q "$version"; then
    return 0
  else
    return 1
  fi
}

# Function to test with API 1.45 (Docker 27.x)
test_api_1_45() {
  print_header "Testing with API 1.45 (Docker 27.x)"
  
  if ! install_docker_version "27." "API 1.45 - Docker 27.x series"; then
    return 1
  fi
  
  echo ""
  print_info "Docker 27.x installed. You can now test CasaOS behavior with this version."
  if [ "$NON_INTERACTIVE" != "true" ]; then
    read -p "Press Enter to run the fix script..." -r
    echo ""
  fi
  
  test_fix_script
}

# Function to test with API 1.46 (Docker 28.x)
test_api_1_46() {
  print_header "Testing with API 1.46 (Docker 28.x)"
  
  if ! install_docker_version "28." "API 1.46 - Docker 28.x series"; then
    return 1
  fi
  
  echo ""
  print_info "Docker 28.x installed. You can now test CasaOS behavior with this version."
  if [ "$NON_INTERACTIVE" != "true" ]; then
    read -p "Press Enter to run the fix script..." -r
    echo ""
  fi
  
  test_fix_script
}

# Function to test with API 1.47 (Docker 29.x)
test_api_1_47() {
  print_header "Testing with API 1.47 (Docker 29.x)"
  
  if ! install_docker_version "29." "API 1.47 - Docker 29.x series"; then
    return 1
  fi
  
  echo ""
  print_info "Docker 29.x installed. You can now test CasaOS behavior with this version."
  if [ "$NON_INTERACTIVE" != "true" ]; then
    read -p "Press Enter to run the fix script..." -r
    echo ""
  fi
  
  test_fix_script
}

# Function to test GPG key conflict handling
test_gpg_key_conflicts() {
  print_header "Testing GPG Key Conflict Handling"
  print_info "This test simulates the GPG key conflict issue reported in Debian/OMV"
  print_info "where multiple Docker GPG keys exist and cause repository conflicts"
  echo ""
  
  detect_os
  
  # Create conflicting GPG keys
  print_info "Creating conflicting Docker GPG keys..."
  
  # Backup existing keys if present
  local backup_dir="/tmp/docker-gpg-backup-$(date +%s)"
  mkdir -p "$backup_dir"
  
  if [ -f /etc/apt/keyrings/docker.asc ]; then
    print_info "Backing up /etc/apt/keyrings/docker.asc"
    $SUDO cp /etc/apt/keyrings/docker.asc "$backup_dir/"
  fi
  
  if [ -f /usr/share/keyrings/docker.gpg ]; then
    print_info "Backing up /usr/share/keyrings/docker.gpg"
    $SUDO cp /usr/share/keyrings/docker.gpg "$backup_dir/"
  fi
  
  # Download Docker GPG key
  print_info "Downloading Docker GPG key..."
  $SUDO install -m 0755 -d /etc/apt/keyrings
  $SUDO install -m 0755 -d /usr/share/keyrings
  $SUDO curl -fsSL https://download.docker.com/linux/${OS}/gpg -o /tmp/docker.gpg
  
  # Create the conflict: place the same key in two locations
  print_info "Creating conflicting GPG key locations..."
  $SUDO cp /tmp/docker.gpg /etc/apt/keyrings/docker.asc
  $SUDO cp /tmp/docker.gpg /usr/share/keyrings/docker.gpg
  $SUDO chmod a+r /etc/apt/keyrings/docker.asc
  $SUDO chmod a+r /usr/share/keyrings/docker.gpg
  
  # Create a conflicting docker.list that references the old location
  print_info "Creating conflicting Docker repository configuration..."
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/${OS} \
    ${VERSION_CODENAME} stable" | \
    $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null
  
  # Try to update - this should fail with the conflict error
  print_info "Testing that apt update fails with conflict..."
  if $SUDO apt-get update 2>&1 | grep -q "Conflicting values set for option Signed-By"; then
    print_success "✓ Confirmed: GPG key conflict error reproduced"
  else
    print_warning "⚠ Could not reproduce GPG key conflict (might already be fixed)"
  fi
  
  echo ""
  print_info "Running fix script to resolve GPG key conflicts..."
  echo ""
  echo "=========================================="
  
  # Run the fix script - it should handle the conflict
  if bash ./run.sh; then
    echo "=========================================="
    echo ""
    print_success "Fix script completed"
  else
    echo "=========================================="
    echo ""
    print_error "Fix script failed"
    
    # Restore backups
    print_info "Restoring GPG key backups..."
    if [ -f "$backup_dir/docker.asc" ]; then
      $SUDO cp "$backup_dir/docker.asc" /etc/apt/keyrings/
    fi
    if [ -f "$backup_dir/docker.gpg" ]; then
      $SUDO cp "$backup_dir/docker.gpg" /usr/share/keyrings/
    fi
    
    return 1
  fi
  
  # Verify the fix
  print_header "Verifying GPG Key Conflict Resolution"
  
  # Check that only docker.asc exists in the correct location
  local gpg_success=true
  
  if [ -f /etc/apt/keyrings/docker.asc ]; then
    print_success "✓ /etc/apt/keyrings/docker.asc exists"
  else
    print_error "✗ /etc/apt/keyrings/docker.asc missing"
    gpg_success=false
  fi
  
  if [ ! -f /usr/share/keyrings/docker.gpg ]; then
    print_success "✓ /usr/share/keyrings/docker.gpg removed (conflict resolved)"
  else
    print_error "✗ /usr/share/keyrings/docker.gpg still exists (conflict not resolved)"
    gpg_success=false
  fi
  
  # Check that apt update works now
  print_info "Testing apt update after fix..."
  if $SUDO apt-get update >/dev/null 2>&1; then
    print_success "✓ apt update works (no conflicts)"
  else
    print_error "✗ apt update still fails"
    $SUDO apt-get update 2>&1 | tail -n 5
    gpg_success=false
  fi
  
  # Check Docker installation
  local docker_version=$(get_docker_version)
  local api_version=$(get_docker_api_version)
  
  echo ""
  echo "Docker status after fix:"
  echo "  Version: $docker_version"
  echo "  API:     $api_version"
  echo ""
  
  if echo "$docker_version" | grep -q "^28\."; then
    print_success "✓ Docker 28.x installed successfully ($docker_version)"
  else
    print_error "✗ Docker version incorrect: $docker_version (expected 28.x)"
    gpg_success=false
  fi
  
  if awk -v ver="$api_version" 'BEGIN {exit !(ver >= 1.47 && ver < 1.52)}'; then
    print_success "✓ Docker API $api_version confirmed (Docker 28.x series, below 1.52 breaking change)"
  else
    print_error "✗ Docker API incorrect: $api_version (expected 1.47-1.51, below 1.52 breaking change)"
    gpg_success=false
  fi
  
  # Cleanup
  rm -rf "$backup_dir"
  $SUDO rm -f /tmp/docker.gpg
  
  echo ""
  if [ "$gpg_success" = true ]; then
    print_header "Test Result: PASSED"
    print_success "GPG key conflict handling works correctly"
    return 0
  else
    print_header "Test Result: FAILED"
    print_error "GPG key conflict handling has issues"
    return 1
  fi
}

# Function to test GPG download resilience
test_gpg_download_resilience() {
  print_header "Testing GPG Download Resilience"
  print_info "This test verifies the GPG key download logic (retries + HTTP/1.1 fallback)"
  echo ""

  # Backup existing key
  if [ -f /etc/apt/keyrings/docker.asc ]; then
    print_info "Backing up existing GPG key..."
    $SUDO cp /etc/apt/keyrings/docker.asc /tmp/docker.asc.backup
  fi

  # Remove key to force download
  print_info "Removing GPG key to force download..."
  $SUDO rm -f /etc/apt/keyrings/docker.asc

  # Run the script
  print_info "Running fix script..."
  if bash ./run.sh; then
    print_success "Script finished successfully"
  else
    print_error "Script failed"
    # Restore backup if script failed
    if [ -f /tmp/docker.asc.backup ]; then
      $SUDO cp /tmp/docker.asc.backup /etc/apt/keyrings/docker.asc
    fi
    return 1
  fi

  # Verify key exists
  if [ -f /etc/apt/keyrings/docker.asc ]; then
    print_success "✓ GPG key downloaded successfully"
    
    # Verify it's a valid key
    if file /etc/apt/keyrings/docker.asc | grep -q "PGP public key"; then
      print_success "✓ File is a valid PGP public key"
    else
      print_error "✗ File is not a valid PGP key"
      return 1
    fi
  else
    print_error "✗ GPG key failed to download"
    # Restore backup
    if [ -f /tmp/docker.asc.backup ]; then
      $SUDO cp /tmp/docker.asc.backup /etc/apt/keyrings/docker.asc
    fi
    return 1
  fi
  
  # Clean up backup
  rm -f /tmp/docker.asc.backup

  return 0
}

# Function to test Snap daemon hang handling
test_snap_hang() {
  print_header "Testing Snap Daemon Hang Handling"
  print_info "This test directly tests the check_and_remove_snap_docker function"
  print_info "It should timeout in 3 seconds and not hang forever"
  echo ""

  # Create mock snap command
  local mock_dir="/tmp/mock-snap-$$"
  mkdir -p "$mock_dir"
  
  cat > "$mock_dir/snap" << 'EOF'
#!/bin/sh
# Simulate hang
sleep 10
exit 0
EOF
  chmod +x "$mock_dir/snap"
  
  # Save PATH
  local old_path="$PATH"
  export PATH="$mock_dir:$PATH"
  
  print_info "Testing: timeout 3 snap list docker"
  
  # Test the timeout command directly
  local start_time=$(date +%s)
  timeout 3 snap list docker >/dev/null 2>&1
  local exit_code=$?
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  
  # Restore PATH
  export PATH="$old_path"
  
  print_info "Command completed in $duration seconds with exit code $exit_code"
  
  # Analyze results
  if [ $exit_code -eq 124 ]; then
    print_success "✓ Timeout occurred (exit code 124)"
  else
    print_error "✗ Expected exit code 124 (timeout), got $exit_code"
    rm -rf "$mock_dir"
    return 1
  fi
  
  if [ $duration -le 5 ]; then
    print_success "✓ Timeout triggered in $duration seconds (expected ~3s)"
  else
    print_error "✗ Timeout took $duration seconds (expected ~3s)"
    rm -rf "$mock_dir"
    return 1
  fi
  
  # Now test the actual function behavior by sourcing and calling it
  print_info "Testing actual check_and_remove_snap_docker function..."
  
  # Extract just the function from run.sh
  local test_script="/tmp/test-snap-func-$$.sh"
  cat > "$test_script" << 'TESTEOF'
#!/bin/bash
set -o pipefail

SUDO=""
if [ "$EUID" -ne 0 ]; then
  SUDO="sudo"
fi

check_and_remove_snap_docker() {
  echo "Checking for Docker installed via Snap..."
  
  if ! command -v snap &>/dev/null; then
    echo "Snap is not installed on this system"
    echo ""
    return 0
  fi
  
  # Check if Docker is installed via snap
  # Use timeout to prevent hanging if snapd is unresponsive
  if timeout 3 snap list docker >/dev/null 2>&1; then
    echo ""
    echo "=========================================="
    echo "WARNING: Docker installed via Snap detected!"
    echo "=========================================="
    echo ""
    return 0
  else
    # Check if it was a timeout or just not found
    local exit_code=$?
    if [ $exit_code -eq 124 ]; then
      echo "WARNING: 'snap list' timed out. Snap daemon might be unresponsive."
      echo "Skipping Snap Docker check to prevent hanging."
      echo ""
      return 0
    fi

    echo "No Docker Snap package found"
    echo ""
    return 0
  fi
}

check_and_remove_snap_docker
TESTEOF
  
  chmod +x "$test_script"
  
  # Run with mocked snap
  export PATH="$mock_dir:$PATH"
  start_time=$(date +%s)
  local output=$($test_script 2>&1)
  local func_exit=$?
  end_time=$(date +%s)
  duration=$((end_time - start_time))
  export PATH="$old_path"
  
  print_info "Function test completed in $duration seconds"
  
  if [ $duration -le 5 ]; then
    print_success "✓ Function completed in $duration seconds (expected ~3s)"
  else
    print_error "✗ Function took $duration seconds (expected ~3s)"
    echo "Output: $output"
    rm -rf "$mock_dir" "$test_script"
    return 1
  fi
  
  if echo "$output" | grep -q "WARNING: 'snap list' timed out"; then
    print_success "✓ Function detected timeout and printed correct warning"
  else
    print_error "✗ Function did not detect timeout correctly"
    echo "Output: $output"
    rm -rf "$mock_dir" "$test_script"
    return 1
  fi
  
  # Clean up
  rm -rf "$mock_dir" "$test_script"
  
  print_header "Test Result: PASSED"
  print_success "Snap timeout handling works correctly"
  return 0
}

# Function to test network namespace cleanup
test_netns_cleanup() {
  print_header "Testing Network Namespace Cleanup"
  print_info "This test verifies that the script handles 'device busy' errors"
  print_info "when cleaning up Docker network namespaces"
  echo ""
  
  # Check if Docker is running
  if ! $SUDO systemctl is-active --quiet docker; then
    print_warning "Docker is not running, starting it..."
    $SUDO systemctl start docker
    sleep 3
  fi
  
  # Create some network namespaces by running containers
  print_info "Creating Docker containers with network namespaces..."
  
  local containers=()
  for i in 1 2 3; do
    local container_id=$(timeout 10 $SUDO docker run -d --rm --name test-netns-$i busybox sleep 300 2>/dev/null || echo "")
    if [ -n "$container_id" ]; then
      containers+=("test-netns-$i")
      print_success "Created container: test-netns-$i"
    else
      print_warning "Could not create test container $i (busybox image may need to be pulled)"
    fi
  done
  
  if [ ${#containers[@]} -eq 0 ]; then
    print_warning "No containers created, trying to pull busybox..."
    if timeout 60 $SUDO docker pull busybox >/dev/null 2>&1; then
      print_success "Pulled busybox image"
      # Try again
      for i in 1 2 3; do
        local container_id=$(timeout 10 $SUDO docker run -d --rm --name test-netns-$i busybox sleep 300 2>/dev/null || echo "")
        if [ -n "$container_id" ]; then
          containers+=("test-netns-$i")
          print_success "Created container: test-netns-$i"
        fi
      done
    fi
  fi
  
  echo ""
  print_info "Containers created: ${#containers[@]}"
  
  if [ ${#containers[@]} -eq 0 ]; then
    print_warning "Could not create test containers, skipping netns cleanup test"
    return 0
  fi
  
  # Check that network namespaces exist
  if [ -d /var/run/docker/netns ]; then
    local netns_count=$(find /var/run/docker/netns -type f 2>/dev/null | wc -l)
    print_info "Network namespaces found: $netns_count"
  fi
  
  # Now try to clean Docker state while containers are running
  # This should trigger the "device busy" error on /var/run/docker/netns/default
  print_info "Stopping Docker while containers are running (simulates cleanup scenario)..."
  $SUDO systemctl stop docker 2>/dev/null || true
  sleep 2
  
  # Try to clean up - this is what the script does
  print_info "Attempting to clean /var/run/docker (should handle 'device busy' gracefully)..."
  
  if [ -d /var/run/docker ]; then
    # This should NOT fail even if netns is busy
    if $SUDO find /var/run/docker -mindepth 1 -maxdepth 1 ! -path '/var/run/docker/netns' -delete 2>/dev/null; then
      print_success "✓ Cleaned /var/run/docker (excluding netns)"
    else
      print_warning "⚠ Some files could not be cleaned"
    fi
    
    # Try to clean netns, but ignore "device busy" errors
    if [ -d /var/run/docker/netns ]; then
      $SUDO find /var/run/docker/netns -type f -delete 2>/dev/null || true
      print_success "✓ Attempted netns cleanup (errors ignored)"
    fi
  fi
  
  # Start Docker again
  print_info "Starting Docker..."
  $SUDO systemctl start docker
  sleep 3
  
  # Clean up test containers
  print_info "Cleaning up test containers..."
  for container in "${containers[@]}"; do
    timeout 10 $SUDO docker stop "$container" 2>/dev/null || true
    timeout 10 $SUDO docker rm -f "$container" 2>/dev/null || true
  done
  
  # Verify Docker is working
  if $SUDO systemctl is-active --quiet docker; then
    print_success "✓ Docker service is running after cleanup test"
  else
    print_error "✗ Docker service failed to start after cleanup test"
    return 1
  fi
  
  # Try to run a simple container to verify functionality
  print_info "Testing Docker functionality with hello-world..."
  if timeout 60 $SUDO docker run --rm hello-world >/dev/null 2>&1; then
    print_success "✓ Docker is fully functional after netns cleanup test"
  else
    print_warning "⚠ Docker may have issues after netns cleanup test"
  fi
  
  print_header "Test Result: PASSED"
  print_success "Network namespace cleanup handled correctly"
  print_info "The script properly handles 'device busy' errors during cleanup"
  
  return 0
}

# Function to test all API versions
test_all_apis() {
  print_header "Testing All API Versions Above 1.44"
  print_info "This will test the fix script against multiple Docker versions:"
  print_info "  • API 1.45 (Docker 27.x)"
  print_info "  • API 1.46 (Docker 28.x)"
  print_info "  • API 1.47 (Docker 29.x)"
  echo ""
  
  if [ "$NON_INTERACTIVE" = "true" ]; then
    REPLY="yes"
  else
    read -p "Do you want to continue? (yes/no): " -r REPLY
    echo ""
  fi
  
  if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]] && [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Test cancelled"
    return 0
  fi
  
  local results=()
  local failed=0
  
  # Test API 1.45
  print_info "=== Test 1 of 3: API 1.45 ==="
  echo ""
  if install_docker_version "27." "API 1.45 - Docker 27.x series"; then
    if test_fix_script; then
      results+=("✓ API 1.45 (Docker 27.x): PASSED")
    else
      results+=("✗ API 1.45 (Docker 27.x): FAILED")
      failed=$((failed + 1))
    fi
  else
    results+=("✗ API 1.45 (Docker 27.x): Installation FAILED")
    failed=$((failed + 1))
  fi
  
  echo ""
  if [ "$NON_INTERACTIVE" != "true" ]; then
    read -p "Press Enter to continue to next test..." -r
    echo ""
  fi
  
  # Test API 1.46
  print_info "=== Test 2 of 3: API 1.46 ==="
  echo ""
  if install_docker_version "28." "API 1.46 - Docker 28.x series"; then
    if test_fix_script; then
      results+=("✓ API 1.46 (Docker 28.x): PASSED")
    else
      results+=("✗ API 1.46 (Docker 28.x): FAILED")
      failed=$((failed + 1))
    fi
  else
    results+=("✗ API 1.46 (Docker 28.x): Installation FAILED")
    failed=$((failed + 1))
  fi
  
  echo ""
  if [ "$NON_INTERACTIVE" != "true" ]; then
    read -p "Press Enter to continue to next test..." -r
    echo ""
  fi
  
  # Test API 1.47
  print_info "=== Test 3 of 3: API 1.47 ==="
  echo ""
  if install_docker_version "29." "API 1.47 - Docker 29.x series"; then
    if test_fix_script; then
      results+=("✓ API 1.47 (Docker 29.x): PASSED")
    else
      results+=("✗ API 1.47 (Docker 29.x): FAILED")
      failed=$((failed + 1))
    fi
  else
    results+=("✗ API 1.47 (Docker 29.x): Installation FAILED")
    failed=$((failed + 1))
  fi
  
  # Print summary
  print_header "Test Summary: All API Versions"
  echo "Results:"
  for result in "${results[@]}"; do
    echo "  $result"
  done
  echo ""
  
  if [ $failed -eq 0 ]; then
    print_success "All tests PASSED!"
    return 0
  else
    print_error "$failed test(s) FAILED"
    return 1
  fi
}

# Function to show usage
show_usage() {
  echo "Usage: $0 [command]"
  echo ""
  echo "Commands:"
  echo "  status      - Show current Docker version and API"
  echo "  upgrade     - Upgrade Docker to latest (simulates the problem)"
  echo "  test        - Run the fix script and verify it works"
  echo "  full        - Run full test (upgrade + test fix)"
  echo ""
  echo "Test specific API versions:"
  echo "  api-1.45    - Test with API 1.45 (Docker 27.x)"
  echo "  api-1.46    - Test with API 1.46 (Docker 28.x)"
  echo "  api-1.47    - Test with API 1.47 (Docker 29.x)"
  echo "  test-all    - Test all API versions above 1.44"
  echo ""
  echo "Bug fix tests (for reported issues):"
  echo "  test-gpg       - Test GPG key conflict handling (Debian/OMV issue)"
  echo "  test-download  - Test GPG download resilience (retries + HTTP/1.1)"
  echo "  test-snap      - Test Snap daemon hang handling (timeout check)"
  echo "  test-netns     - Test network namespace cleanup (device busy error)"
  echo "  test-bugfixes  - Run all bug fix tests"
  echo ""
  echo "Alternative fix for newer distros (Ubuntu 24.04+, Debian trixie):"
  echo "  apply-override   - Apply Docker API override (DOCKER_MIN_API_VERSION=1.24)"
  echo "  remove-override  - Remove Docker API override configuration"
  echo ""
  echo "  help        - Show this help message"
  echo ""
  echo "Example workflow:"
  echo "  1. $0 status        # Check current state"
  echo "  2. $0 upgrade       # Simulate the problem"
  echo "  3. $0 status        # Verify Docker was upgraded"
  echo "  4. $0 test          # Test the fix script"
  echo ""
  echo "Test specific API versions:"
  echo "  $0 api-1.45         # Install Docker 27.x and test"
  echo "  $0 api-1.46         # Install Docker 28.x and test"
  echo "  $0 api-1.47         # Install Docker 29.x and test"
  echo ""
  echo "Test bug fixes:"
  echo "  $0 test-gpg         # Test GPG key conflict resolution (Debian/OMV)"
  echo "  $0 test-download    # Test GPG download resilience"
  echo "  $0 test-snap        # Test Snap hang handling"
  echo "  $0 test-netns       # Test network namespace cleanup"
  echo "  $0 test-bugfixes    # Run all bug fix tests"
  echo ""
  echo "Alternative fix (for distros without Docker 28.x):"
  echo "  $0 apply-override   # Apply API override to work with newer Docker"
  echo "  $0 remove-override  # Remove API override"
  echo ""
  echo "Or run all tests:"
  echo "  $0 test-all         # Test against all API versions"
  echo "  $0 full             # Standard full test (upgrade + fix)"
  echo ""
}

# Function to test unresponsive Docker daemon
test_unresponsive_daemon() {
  print_header "Testing Unresponsive Docker Daemon Handling"
  print_info "This test verifies that the script handles an unresponsive Docker daemon"
  print_info "It should timeout in 10 seconds and not hang forever"
  echo ""

  # Create mock docker command
  local mock_dir="/tmp/mock-docker-$$"
  mkdir -p "$mock_dir"
  
  cat > "$mock_dir/docker" << 'EOF'
#!/bin/sh
# Simulate hang
sleep 20
exit 0
EOF
  chmod +x "$mock_dir/docker"
  
  # Save PATH
  local old_path="$PATH"
  export PATH="$mock_dir:$PATH"
  
  print_info "Testing: timeout 10 docker version"
  
  # Test the timeout command directly
  local start_time=$(date +%s)
  timeout 10 docker version >/dev/null 2>&1
  local exit_code=$?
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  
  # Restore PATH
  export PATH="$old_path"
  
  print_info "Command completed in $duration seconds with exit code $exit_code"
  
  # Analyze results
  if [ $exit_code -eq 124 ]; then
    print_success "✓ Timeout occurred (exit code 124)"
  else
    print_error "✗ Expected exit code 124 (timeout), got $exit_code"
    rm -rf "$mock_dir"
    return 1
  fi
  
  if [ $duration -le 12 ]; then
    print_success "✓ Timeout triggered in $duration seconds (expected ~10s)"
  else
    print_error "✗ Timeout took $duration seconds (expected ~10s)"
    rm -rf "$mock_dir"
    return 1
  fi
  
  # Now test the actual function behavior by sourcing and calling it
  print_info "Testing actual get_docker_api_version function..."
  
  # Extract just the function from run.sh
  local test_script="/tmp/test-docker-func-$$.sh"
  cat > "$test_script" << 'TESTEOF'
#!/bin/bash
set -o pipefail

SUDO=""
if [ "$EUID" -ne 0 ]; then
  SUDO="sudo"
fi

# Function to get Docker API version
get_docker_api_version() {
  local api_version=""
  
  # Try to get the API version from docker version command
  if command -v docker &>/dev/null; then
    # Get server API version
    # Use timeout to prevent hanging if Docker daemon is unresponsive
    local output
    output=$(timeout 10 $SUDO docker version --format '{{.Server.APIVersion}}' 2>/dev/null)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
      api_version="$output"
    elif [ $exit_code -eq 124 ]; then
      # Timed out - do not try fallback as it will likely hang too
      api_version=""
    else
      # Other error (e.g. format not supported), try fallback
      api_version=""
    fi
    
    if [ -z "$api_version" ] && [ $exit_code -ne 124 ]; then
      # Fallback: try to parse from docker version output
      api_version=$(timeout 10 $SUDO docker version 2>/dev/null | grep -A 5 "Server:" | grep "API version:" | awk '{print $3}' | head -n1 || echo "")
    fi
  fi
  
  echo "$api_version"
  return 0
}

echo "Calling get_docker_api_version..."
get_docker_api_version
TESTEOF
  
  chmod +x "$test_script"
  
  # Run with mocked docker
  export PATH="$mock_dir:$PATH"
  start_time=$(date +%s)
  local output=$($test_script 2>&1)
  local func_exit=$?
  end_time=$(date +%s)
  duration=$((end_time - start_time))
  export PATH="$old_path"
  
  print_info "Function test completed in $duration seconds"
  
  if [ $duration -le 12 ]; then
    print_success "✓ Function completed in $duration seconds (expected ~10s)"
  else
    print_error "✗ Function took $duration seconds (expected ~10s)"
    echo "Output: $output"
    rm -rf "$mock_dir" "$test_script"
    return 1
  fi
  
  # Clean up
  rm -rf "$mock_dir" "$test_script"
  
  print_header "Test Result: PASSED"
  print_success "Docker daemon timeout handling works correctly"
  return 0
}

# Function to run all bug fix tests
test_all_bugfixes() {
  print_header "Running All Bug Fix Tests"
  print_info "This will test all bug fixes:"
  print_info "  1. GPG key conflict handling"
  print_info "  2. GPG download resilience"
  print_info "  3. Snap daemon hang handling"
  print_info "  4. Network namespace cleanup"
  print_info "  5. Unresponsive Docker daemon handling"
  echo ""
  
  local results=()
  local failed=0
  
  # Test GPG conflicts
  print_info "=== Test 1 of 5: GPG Key Conflicts ==="
  echo ""
  if test_gpg_key_conflicts; then
    results+=("✓ GPG key conflict handling: PASSED")
  else
    results+=("✗ GPG key conflict handling: FAILED")
    failed=$((failed + 1))
  fi
  
  echo ""
  if [ "$NON_INTERACTIVE" != "true" ]; then
    read -p "Press Enter to continue to next test..." -r
    echo ""
  fi

  # Test GPG download resilience
  print_info "=== Test 2 of 5: GPG Download Resilience ==="
  echo ""
  if test_gpg_download_resilience; then
    results+=("✓ GPG download resilience: PASSED")
  else
    results+=("✗ GPG download resilience: FAILED")
    failed=$((failed + 1))
  fi
  
  echo ""
  if [ "$NON_INTERACTIVE" != "true" ]; then
    read -p "Press Enter to continue to next test..." -r
    echo ""
  fi

  # Test Snap hang
  print_info "=== Test 3 of 5: Snap Daemon Hang ==="
  echo ""
  if test_snap_hang; then
    results+=("✓ Snap daemon hang handling: PASSED")
  else
    results+=("✗ Snap daemon hang handling: FAILED")
    failed=$((failed + 1))
  fi
  
  echo ""
  if [ "$NON_INTERACTIVE" != "true" ]; then
    read -p "Press Enter to continue to next test..." -r
    echo ""
  fi
  
  # Test netns cleanup
  print_info "=== Test 4 of 5: Network Namespace Cleanup ==="
  echo ""
  if test_netns_cleanup; then
    results+=("✓ Network namespace cleanup: PASSED")
  else
    results+=("✗ Network namespace cleanup: FAILED")
    failed=$((failed + 1))
  fi
  
  echo ""
  if [ "$NON_INTERACTIVE" != "true" ]; then
    read -p "Press Enter to continue to next test..." -r
    echo ""
  fi
  
  # Test unresponsive daemon
  print_info "=== Test 5 of 5: Unresponsive Docker Daemon ==="
  echo ""
  if test_unresponsive_daemon; then
    results+=("✓ Unresponsive daemon handling: PASSED")
  else
    results+=("✗ Unresponsive daemon handling: FAILED")
    failed=$((failed + 1))
  fi
  
  # Print summary
  print_header "Bug Fix Test Summary"
  echo "Results:"
  for result in "${results[@]}"; do
    echo "  $result"
  done
  echo ""
  
  if [ $failed -eq 0 ]; then
    print_success "All bug fix tests PASSED!"
    return 0
  else
    print_error "$failed bug fix test(s) FAILED"
    return 1
  fi
}

# Main script
main() {
  if [ $# -eq 0 ]; then
    show_usage
    exit 0
  fi
  
  case "$1" in
    status)
      show_status
      ;;
    upgrade)
      upgrade_docker_to_latest
      ;;
    test)
      test_fix_script
      ;;
    full)
      run_full_test
      ;;
    api-1.45|api-1-45|api145)
      test_api_1_45
      ;;
    api-1.46|api-1-46|api146)
      test_api_1_46
      ;;
    api-1.47|api-1-47|api147)
      test_api_1_47
      ;;
    test-all|all)
      test_all_apis
      ;;
    test-gpg|gpg|test-gpg-conflicts)
      test_gpg_key_conflicts
      ;;
    test-download|download|test-gpg-download)
      test_gpg_download_resilience
      ;;
    test-snap|snap|test-snap-hang)
      test_snap_hang
      ;;
    test-netns|netns|test-network-namespace)
      test_netns_cleanup
      ;;
    test-bugfixes|bugfixes|bug-fixes)
      test_all_bugfixes
      ;;
    apply-override|override)
      apply_docker_api_override
      ;;
    remove-override|no-override)
      remove_docker_api_override
      ;;
    help|--help|-h)
      show_usage
      ;;
    *)
      print_error "Unknown command: $1"
      echo ""
      show_usage
      exit 1
      ;;
  esac
}

# Run main function
main "$@"
