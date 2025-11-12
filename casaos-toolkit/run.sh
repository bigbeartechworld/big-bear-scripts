#!/usr/bin/env bash

# BigBear CasaOS Complete Toolkit - Diagnostics and Fixes
# Run with sudo permissions
#
# GitHub: https://github.com/BigBearTechWorld
# Community: https://community.bigbeartechworld.com
# Support: https://ko-fi.com/bigbeartechworld
#

# Set text colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Function to print header
print_header() {
    echo "================================================"
    echo "$1"
    echo "================================================"
    echo
}

# Function to display menu
show_menu() {
    clear
    print_header "BigBearCasaOS Toolkit V0.0.1"

    echo "Here are some links:"
    echo "https://community.bigbeartechworld.com"
    echo "https://github.com/BigBearTechWorld"
    echo ""
    echo "If you would like to support me, please consider buying me a tea:"
    echo "https://ko-fi.com/bigbeartechworld"
    echo ""
    
    echo "===================="
    echo "1. Run Diagnostics - Collect system information and logs for troubleshooting"
    echo "2. Fix Docker Overlay2 Issues - Repair storage driver problems and rebuild Docker structure"
    echo "3. Full System Reset - Clean reinstall of Docker and CasaOS (Backs up existing data from /var/lib/docker)"
    echo "4. Exit - Close the toolkit"
    read -p "Enter your choice (1-4): " choice
}


# Function to collect diagnostic information
run_diagnostics() {
    echo -e "${GREEN}Starting CasaOS diagnostic collection...${NC}"
    
    # Create output directory
    timestamp=$(date +%Y%m%d_%H%M%S)
    output_dir="casaos_diagnostics_${timestamp}"
    mkdir -p "$output_dir"

    # Function to collect command output
    collect_output() {
        local cmd="$1"
        local output_file="$2"
        echo -e "${YELLOW}Collecting: ${cmd}${NC}"
        eval "$cmd" > "$output_dir/$output_file" 2>&1
    }

    # Collect System Information
    collect_output "uname -a" "system_info.txt"
    collect_output "free -h" "memory_info.txt"
    collect_output "df -h" "disk_info.txt"
    collect_output "docker info" "docker_info.txt"
    collect_output "docker ps -a" "docker_containers.txt"
    collect_output "docker images" "docker_images.txt"
    collect_output "ls -la /var/lib/docker" "docker_directory_structure.txt"
    collect_output "systemctl status docker" "docker_service_status.txt"
    collect_output "systemctl status casaos" "casaos_service_status.txt"
    collect_output "journalctl -u docker --no-pager -n 200" "docker_logs.txt"
    collect_output "journalctl -u casaos --no-pager -n 200" "casaos_logs.txt"

    # Compress and cleanup
    tar czf "casaos_diagnostics_${timestamp}.tar.gz" "$output_dir"
    rm -rf "$output_dir"

    echo -e "${GREEN}Diagnostic collection complete!${NC}"
    echo -e "Diagnostic file created: ${YELLOW}casaos_diagnostics_${timestamp}.tar.gz${NC}"
}

# Function to fix Overlay2 issues
fix_overlay2() {
    echo -e "${YELLOW}Fixing Docker overlay2 issues...${NC}"
    
    # Stop services
    systemctl stop docker
    systemctl stop casaos

    # Backup existing Docker root
    if [ -d "/var/lib/docker" ]; then
        mv /var/lib/docker /var/lib/docker.bak.$(date +%Y%m%d_%H%M%S)
    fi

    # Create fresh directory structure - Docker will set proper permissions
    mkdir -p /var/lib/docker

    # Configure Docker daemon
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<EOL
{
    "storage-driver": "overlay2",
    "storage-opts": [
        "overlay2.override_kernel_check=true"
    ]
}
EOL

    # Restart services - Docker daemon will create proper directory structure
    systemctl daemon-reload
    systemctl start docker
    systemctl start casaos

    # Clean up
    docker system prune -af --volumes

    echo -e "${GREEN}Overlay2 fix complete!${NC}"
}
# Function for full system reset
full_reset() {
    echo -e "${RED}WARNING: This will remove all Docker containers, images, and reset CasaOS settings!${NC}"
    read -p "Are you sure you want to continue? (y/N): " confirm
    if [[ $confirm == [yY] ]]; then
        echo -e "${YELLOW}Performing full system reset...${NC}"
        
        # Stop services
        systemctl stop docker
        systemctl stop casaos

        # Backup and clean Docker
        timestamp=$(date +%Y%m%d_%H%M%S)
        if [ -d "/var/lib/docker" ]; then
            mv /var/lib/docker "/var/lib/docker.backup_${timestamp}"
        fi

        # Backup CasaOS data
        if [ -d "/var/lib/casaos" ]; then
            mv /var/lib/casaos "/var/lib/casaos.backup_${timestamp}"
        fi

        # Remove Docker configuration
        rm -rf /etc/docker

        # Remove CasaOS
        curl -fsSL https://get.casaos.io/uninstall | sudo bash

        # Reinstall CasaOS
        curl -fsSL https://get.casaos.io | sudo bash

        # Reinstall Docker configuration
        mkdir -p /etc/docker
        cat > /etc/docker/daemon.json <<EOL
{
    "storage-driver": "overlay2",
    "storage-opts": [
        "overlay2.override_kernel_check=true"
    ]
}
EOL

        # Restart services - Docker daemon will create proper directory structure
        systemctl daemon-reload
        systemctl start docker
        systemctl start casaos

        echo -e "${GREEN}Full system reset complete!${NC}"
    else
        echo "Reset cancelled."
    fi

}
# Main loop
while true; do
    show_menu
    case $choice in
        1)
            run_diagnostics
            ;;
        2)
            fix_overlay2
            ;;
        3)
            full_reset
            ;;
        4)
            echo -e "${GREEN}Exiting...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
    
    echo
    read -p "Press Enter to continue..."
done
