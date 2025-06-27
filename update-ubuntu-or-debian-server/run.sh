#!/usr/bin/env bash

# Define a message for branding purposes
MESSAGE="Made by BigBearTechWorld"
VERSION="2.0.0"
SCRIPT_NAME="BigBear Ubuntu/Debian Server Update Script"

# Configuration file path
CONFIG_FILE="$HOME/.bigbear-update.conf"
CONFIG_DIR="$HOME/.config/bigbear"

# Set up logging
LOG_DIR="/var/log/bigbear"
LOG_FILE="$LOG_DIR/big-bear-update-ubuntu-server.log"
JSON_LOG_FILE="$LOG_DIR/big-bear-update-ubuntu-server.json"

# Create log directory if it doesn't exist
if ! sudo mkdir -p "$LOG_DIR" 2>/dev/null; then
    # Fallback to user's local directory
    LOG_DIR="$HOME/.local/log/bigbear"
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/big-bear-update-ubuntu-server.log"
    JSON_LOG_FILE="$LOG_DIR/big-bear-update-ubuntu-server.json"
fi

# Color definitions for better visual appeal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Unicode symbols for better visual appeal
CHECK_MARK="✓"
CROSS_MARK="✗"
INFO_SYMBOL="ℹ"
WARNING_SYMBOL="⚠"
ROCKET="🚀"
GEAR="⚙"
CLEAN="🧹"
SHIELD="🛡"
CLOCK="⏰"
CHART="📊"
EMAIL="📧"
SAVE="💾"

# Performance tracking variables
START_TIME=$(date +%s)
STEP_START_TIME=$START_TIME
NETWORK_USAGE_START=0
MEMORY_USAGE_START=0

# Statistics tracking
PACKAGES_UPGRADED=0
PACKAGES_REMOVED=0
SECURITY_UPDATES=0
TOTAL_DOWNLOAD_SIZE=0
FAILED_OPERATIONS=()

# Default configuration
DEFAULT_CONFIG='# BigBear Update Script Configuration
# Set to true/false to enable/disable features by default
auto_update_package_list=true
auto_upgrade_packages=true
auto_full_upgrade=true
auto_remove_unnecessary=true
auto_clean_cache=true
enable_email_notifications=false
email_address=""
exclude_packages=""
min_disk_space_percent=20
max_load_average=2.0
backup_before_upgrade=false
retry_count=3
parallel_downloads=true
check_security_updates=true
maintenance_window_start="02:00"
maintenance_window_end="04:00"
'

# Helper: Strip ANSI color codes for length calculation
strip_ansi() {
    echo -e "$1" | sed -r 's/\x1B\[[0-9;]*[mK]//g'
}

# Helper: Count emoji as double-width (for 🚀 only)
visible_length() {
    local text="$(strip_ansi "$1")"
    # Each 🚀 is 2 columns, but Bash counts as 1, so add 1 extra per emoji
    local emoji_count=$(grep -o "🚀" <<< "$text" | wc -l)
    local base_len=${#text}
    echo $((base_len + emoji_count))
}

# Print a centered line in a box of width 78
center_box_line() {
    local content="$1"
    local color="$2"
    local width=78
    local len=$(visible_length "$content")
    local pad=$(( (width - len) / 2 ))
    local extra=$(( width - len - pad ))
    printf "${BLUE}║${color}%*s%s%*s${BLUE}║${NC}\n" $pad "" "$content" $extra ""
}

# Function to print a decorative header
print_header() {
    clear
    local box_width=78
    echo -e "${BLUE}╔$(printf '═%.0s' $(seq 1 $box_width))╗${NC}"
    center_box_line "UPDATE UBUNTU/DEBIAN SERVER" "${WHITE}${BOLD}"
    center_box_line "Version $VERSION" "${WHITE}${BOLD}"
    echo -e "${BLUE}╠$(printf '═%.0s' $(seq 1 $box_width))╣${NC}"
    center_box_line "$MESSAGE" "${CYAN}${BOLD}"
    echo -e "${BLUE}╚$(printf '═%.0s' $(seq 1 $box_width))╝${NC}"
    echo
    echo -e "${YELLOW}${BOLD}💖 If this script helps you, please consider supporting my work:${NC}"
    echo -e "${GREEN}${BOLD}   ☕ Ko-fi: https://ko-fi.com/bigbeartechworld${NC}"
    echo -e "${CYAN}${BOLD}   🌟 Star the repo: https://github.com/bigbeartechworld/big-bear-scripts${NC}"
    echo
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────────────────${NC}"
    echo
}

# Function to log messages to file
log() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    # Optionally, also log to JSON
    echo "{\"timestamp\": \"$timestamp\", \"level\": \"$level\", \"message\": \"$message\"}" >> "$JSON_LOG_FILE"
}

# Function to check and install missing dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for bc (calculator)
    if ! command -v bc >/dev/null 2>&1; then
        missing_deps+=("bc")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_warning "Missing dependencies detected: ${missing_deps[*]}"
        if [ "$unattended" = false ]; then
            if prompt_user "Install missing dependencies?"; then
                print_info "Installing missing dependencies..."
                sudo apt update -qq >/dev/null 2>&1
                for dep in "${missing_deps[@]}"; do
                    sudo apt install -y "$dep" >/dev/null 2>&1
                    if command -v "$dep" >/dev/null 2>&1; then
                        print_success "Installed $dep"
                    else
                        print_warning "Failed to install $dep"
                    fi
                done
            else
                print_warning "Continuing without optional dependencies"
            fi
        else
            print_info "Auto-installing missing dependencies in unattended mode..."
            sudo apt update -qq >/dev/null 2>&1
            for dep in "${missing_deps[@]}"; do
                sudo apt install -y "$dep" >/dev/null 2>&1
                log "Attempted to install dependency: $dep"
            done
        fi
    fi
}

# Function to load configuration
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        mkdir -p "$CONFIG_DIR" 2>/dev/null
        echo "$DEFAULT_CONFIG" > "$CONFIG_FILE"
        log "Created default configuration file at $CONFIG_FILE"
    fi
    
    # Safely parse configuration file without executing arbitrary commands
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Only process lines that match key=value format (with optional spaces)
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Remove surrounding quotes if present
            if [[ "$value" =~ ^\"(.*)\"$ ]] || [[ "$value" =~ ^\'(.*)\'$ ]]; then
                value="${BASH_REMATCH[1]}"
            fi
            
            # Only allow known configuration variables for additional security
            case "$key" in
                auto_update_package_list|auto_upgrade_packages|auto_full_upgrade|auto_remove_unnecessary|auto_clean_cache|\
                enable_email_notifications|email_address|exclude_packages|min_disk_space_percent|max_load_average|\
                backup_before_upgrade|retry_count|parallel_downloads|check_security_updates|\
                maintenance_window_start|maintenance_window_end)
                    # Set the variable safely
                    declare -g "$key=$value"
                    ;;
                *)
                    log "Ignoring unknown configuration variable: $key" "WARNING"
                    ;;
            esac
        fi
    done < "$CONFIG_FILE"
    
    log "Configuration loaded from $CONFIG_FILE"
}

# Function to check system health
check_system_health() {
    local health_issues=()
    
    # Check disk space
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    local free_space=$((100 - disk_usage))
    
    if [ "$free_space" -lt "${min_disk_space_percent:-20}" ]; then
        health_issues+=("Low disk space: ${free_space}% free (minimum: ${min_disk_space_percent:-20}%)")
    fi
    
    # Check system load
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    if command -v bc >/dev/null 2>&1; then
        if (( $(echo "$load_avg > ${max_load_average:-2.0}" | bc -l) )); then
            health_issues+=("High system load: $load_avg (maximum: ${max_load_average:-2.0})")
        fi
    else
        # Fallback without bc - simple integer comparison
        local load_int=$(echo "$load_avg" | cut -d'.' -f1)
        local max_load_int=$(echo "${max_load_average:-2.0}" | cut -d'.' -f1)
        if [ "$load_int" -gt "$max_load_int" ]; then
            health_issues+=("High system load: $load_avg (maximum: ${max_load_average:-2.0})")
        fi
    fi
    
    # Check memory usage
    local mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    if command -v bc >/dev/null 2>&1; then
        if (( $(echo "$mem_usage > 90.0" | bc -l) )); then
            health_issues+=("High memory usage: ${mem_usage}%")
        fi
    else
        # Fallback without bc - simple integer comparison
        local mem_int=$(echo "$mem_usage" | cut -d'.' -f1)
        if [ "$mem_int" -gt 90 ]; then
            health_issues+=("High memory usage: ${mem_usage}%")
        fi
    fi
    
    # Check if system is currently updating
    if pgrep -x "apt" > /dev/null || pgrep -x "apt-get" > /dev/null || pgrep -x "dpkg" > /dev/null; then
        health_issues+=("Another package manager is currently running")
    fi
    
    if [ ${#health_issues[@]} -gt 0 ]; then
        print_warning "System health issues detected:"
        for issue in "${health_issues[@]}"; do
            echo -e "  ${RED}• $issue${NC}"
        done
        
        if [ "$unattended" = false ]; then
            if ! prompt_user "Continue despite health issues?"; then
                print_error "Aborting due to system health concerns"
                exit 1
            fi
        else
            log "Continuing in unattended mode despite health issues" "WARNING"
        fi
    else
        print_success "System health check passed"
    fi
}

# Function to create backup
create_backup() {
    if [ "${backup_before_upgrade:-false}" = "true" ]; then
        local backup_dir="/var/backups/bigbear-$(date +%Y%m%d-%H%M%S)"
        print_info "Creating system backup..."
        
        sudo mkdir -p "$backup_dir"
        sudo sh -c "dpkg --get-selections > \"$backup_dir/package-selections.txt\""
        sudo cp -r /etc/apt "$backup_dir/"
        
        print_success "Backup created at $backup_dir"
        log "System backup created at $backup_dir"
        echo "$backup_dir" > "/tmp/bigbear-backup-location"
    fi
}

# Function to send email notification
send_email_notification() {
    if [ "${enable_email_notifications:-false}" = "true" ] && [ -n "${email_address:-}" ]; then
        local subject="$1"
        local body="$2"
        
        if command -v mail >/dev/null 2>&1; then
            echo "$body" | mail -s "$subject" "$email_address"
            log "Email notification sent to $email_address"
        elif command -v sendmail >/dev/null 2>&1; then
            {
                echo "To: $email_address"
                echo "Subject: $subject"
                echo ""
                echo "$body"
            } | sendmail "$email_address"
            log "Email notification sent to $email_address"
        else
            log "Email notification failed: no mail client available" "WARNING"
        fi
    fi
}

# Function to get network usage
get_network_usage() {
    local bytes=$(cat /proc/net/dev | grep -E "(eth0|wlan0|enp|wlp)" | head -1 | awk '{print $2 + $10}' 2>/dev/null)
    # Return 0 if no interface found or empty result
    if [ -z "$bytes" ]; then
        echo "0"
        return
    fi
    # Convert scientific notation to integer if necessary
    if [[ "$bytes" == *"e+"* ]]; then
        bytes=$(printf "%.0f" "$bytes")
    fi
    echo "$bytes"
}

# Function to get memory usage
get_memory_usage() {
    free -m | awk 'NR==2{printf "%.1f", $3*100/$2}'
}

# Function to check for security updates
check_security_updates() {
    if [ "${check_security_updates:-true}" = "true" ]; then
        if command -v unattended-upgrades >/dev/null 2>&1; then
            local security_count=$(apt list --upgradable 2>/dev/null | grep -c "security")
            SECURITY_UPDATES=$security_count
            if [ "$security_count" -gt 0 ]; then
                print_warning "$security_count security updates available"
            else
                print_success "No security updates pending"
            fi
        fi
    fi
}

# Function to retry operations
retry_operation() {
    local operation="$1"
    local max_attempts="${retry_count:-3}"
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if eval "$operation"; then
            return 0
        else
            print_warning "Attempt $attempt/$max_attempts failed, retrying in 5 seconds..."
            sleep 5
            ((attempt++))
        fi
    done
    
    FAILED_OPERATIONS+=("$operation")
    return 1
}

# Function to check if in maintenance window
in_maintenance_window() {
    local current_time=$(date +%H:%M)
    local start_time="${maintenance_window_start:-02:00}"
    local end_time="${maintenance_window_end:-04:00}"
    
    # Convert times to minutes since midnight
    local current_minutes=$(echo "$current_time" | awk -F: '{print $1 * 60 + $2}')
    local start_minutes=$(echo "$start_time" | awk -F: '{print $1 * 60 + $2}')
    local end_minutes=$(echo "$end_time" | awk -F: '{print $1 * 60 + $2}')
    
    # Handle maintenance window that crosses midnight
    if [ $start_minutes -le $end_minutes ]; then
        # Normal case: start <= end (e.g., 02:00 to 04:00)
        if [ $current_minutes -ge $start_minutes ] && [ $current_minutes -le $end_minutes ]; then
            return 0
        fi
    else
        # Wrap-around case: start > end (e.g., 22:00 to 02:00)
        if [ $current_minutes -ge $start_minutes ] || [ $current_minutes -le $end_minutes ]; then
            return 0
        fi
    fi
    
    return 1
}

# Function to estimate time remaining
estimate_time_remaining() {
    local current_step="$1"
    local total_steps=5
    local current_step_num=0
    
    case "$current_step" in
        "update") current_step_num=1 ;;
        "upgrade") current_step_num=2 ;;
        "full-upgrade") current_step_num=3 ;;
        "autoremove") current_step_num=4 ;;
        "clean") current_step_num=5 ;;
    esac
    
    local elapsed=$(($(date +%s) - START_TIME))
    local estimated_total=$((elapsed * total_steps / current_step_num))
    local remaining=$((estimated_total - elapsed))
    
    if [ $remaining -gt 0 ]; then
        print_info "Estimated time remaining: $((remaining / 60))m $((remaining % 60))s"
    fi
}

# Function to print section headers
print_section() {
    echo
    echo -e "${PURPLE}${BOLD}▼ $1${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────────────────${NC}"
    STEP_START_TIME=$(date +%s)
}

# Function to print success message
print_success() {
    echo -e "${GREEN}${BOLD}${CHECK_MARK} $1${NC}"
}

# Function to print error message
print_error() {
    echo -e "${RED}${BOLD}${CROSS_MARK} $1${NC}"
}

# Function to print warning message
print_warning() {
    echo -e "${YELLOW}${BOLD}${WARNING_SYMBOL} $1${NC}"
}

# Function to print info message
print_info() {
    echo -e "${CYAN}${BOLD}${INFO_SYMBOL} $1${NC}"
}

# Enhanced progress bar function
show_progress_bar() {
    local duration=$1
    local task=$2
    local progress=0
    
    # Calculate sleep step with floating-point precision and minimum value
    local sleep_step
    if command -v bc >/dev/null 2>&1; then
        sleep_step=$(echo "scale=3; $duration / 100" | bc)
        # Ensure minimum sleep interval of 0.05 seconds
        if (( $(echo "$sleep_step < 0.05" | bc -l) )); then
            sleep_step="0.05"
        fi
    else
        # Fallback using awk if bc is not available
        sleep_step=$(awk "BEGIN {step = $duration / 100; print (step < 0.05) ? 0.05 : step}")
    fi
    
    echo -ne "${CYAN}${GEAR} $task "
    
    while [ $progress -le 100 ]; do
        local filled=$((progress / 5))
        local empty=$((20 - filled))
        
        printf "\r${CYAN}${GEAR} $task ["
        printf "%*s" $filled | tr ' ' '█'
        printf "%*s" $empty | tr ' ' '░'
        printf "] %d%%" $progress
        
        sleep "$sleep_step"
        progress=$((progress + 1))
    done
    
    echo -e " ${GREEN}${CHECK_MARK}${NC}"
}

# Function to show simple progress
show_progress() {
    local duration=$1
    local task=$2
    echo -ne "${CYAN}${GEAR} $task"
    for ((i=0; i<=duration; i++)); do
        echo -ne "."
        sleep 0.1
    done
    echo -e " ${GREEN}${CHECK_MARK}${NC}"
}

# Print the introduction
print_header

# Load configuration
load_config

# Parse command line arguments
unattended=false
force_update=false
config_only=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --unattended)
            unattended=true
            shift
            ;;
        --force)
            force_update=true
            shift
            ;;
        --config)
            config_only=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --unattended    Run without prompts"
            echo "  --force         Force update despite health issues"
            echo "  --config        Edit configuration file"
            echo "  --help          Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Configuration mode
if [ "$config_only" = true ]; then
    print_section "Configuration Editor"
    if command -v nano >/dev/null 2>&1; then
        nano "$CONFIG_FILE"
    elif command -v vim >/dev/null 2>&1; then
        vim "$CONFIG_FILE"
    else
        print_error "No text editor available. Please edit $CONFIG_FILE manually."
    fi
    exit 0
fi

# Mode detection
if [ "$unattended" = true ]; then
    print_info "Running in unattended mode..."
else
    print_info "Running in interactive mode..."
fi

# Check maintenance window for unattended mode
if [ "$unattended" = true ] && ! in_maintenance_window && [ "$force_update" = false ]; then
    print_warning "Outside maintenance window (${maintenance_window_start:-02:00}-${maintenance_window_end:-04:00})"
    print_info "Use --force to override maintenance window check"
    exit 0
fi

# Function to prompt the user with enhanced visuals
prompt_user() {
    local question="$1"
    local config_var="$2"
    
    if [ "$unattended" = true ]; then
        # Check configuration for auto-answers
        if [ -n "$config_var" ]; then
            local config_value=$(eval echo \$${config_var})
            if [ "$config_value" = "true" ]; then
                print_info "Auto-proceeding: $question"
                return 0
            elif [ "$config_value" = "false" ]; then
                print_info "Auto-skipping: $question"
                return 1
            fi
        fi
        return 0  # Default to proceed in unattended mode
    fi

    echo
    echo -e "${YELLOW}${BOLD}❓ $question${NC}"
    echo -ne "${WHITE}${BOLD}   Enter your choice (${GREEN}y${WHITE}/${RED}n${WHITE}): ${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}   ${CHECK_MARK} Proceeding...${NC}"
        return 0  # Proceed
    else
        echo -e "${YELLOW}   ${WARNING_SYMBOL} Skipping...${NC}"
        return 1  # Skip
    fi
}

# Check OS compatibility
print_section "System Compatibility Check"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        print_error "This script is intended for Ubuntu or Debian. Detected OS: $ID"
        exit 1
    else
        print_success "Compatible OS detected: $PRETTY_NAME"
        log "OS compatibility confirmed: $PRETTY_NAME"
    fi
else
    print_error "Unable to determine OS. This script is intended for Ubuntu or Debian."
    exit 1
fi

# Note: Dependencies will be checked after prompt_user function is defined

# Function to check disk space
check_disk_space() {
    df -h / | awk 'NR==2 {print $5}' | sed 's/%//'
}

# Function to check and hold back problematic packages
check_problematic_packages() {
    local problematic_packages=()
    
    # Add packages from exclude list
    if [ -n "${exclude_packages:-}" ]; then
        IFS=',' read -ra ADDR <<< "$exclude_packages"
        for package in "${ADDR[@]}"; do
            problematic_packages+=("$(echo $package | xargs)")
        done
    fi
    
    for package in "${problematic_packages[@]}"; do
        if dpkg -l | grep -q "^ii  $package "; then
            print_warning "Holding back excluded package: $package"
            sudo apt-mark hold "$package"
            log "Package held: $package"
        fi
    done
}

# Check and install dependencies
print_section "Dependency Check"
check_dependencies

# System health check
if [ "$force_update" = false ]; then
    print_section "System Health Check"
    check_system_health
else
    print_warning "Skipping health check due to --force flag"
fi

# Initialize performance tracking
NETWORK_USAGE_START=$(get_network_usage)
MEMORY_USAGE_START=$(get_memory_usage)

# Explain the script's function if not running in unattended mode
if [ "$unattended" = false ]; then
    print_section "Script Information"
    print_info "This script will help you update and maintain your Ubuntu/Debian server."
    print_info "You will be prompted to confirm each step before proceeding."
    print_info "Configuration file: $CONFIG_FILE"
    print_info "To run in unattended mode, use the --unattended option."
fi

print_section "Disk Space Analysis"
initial_space=$(check_disk_space)
print_info "Initial disk space used: ${BOLD}$initial_space%${NC}"

# Check for apt-fast for parallel downloads
if command -v apt-fast >/dev/null 2>&1 && [ "${parallel_downloads:-true}" = "true" ]; then
    APT_CMD="apt-fast"
    print_info "Using apt-fast for parallel downloads"
else
    APT_CMD="apt"
fi

# Security updates check
check_security_updates

# Create backup if enabled
create_backup

# Initialize tracking variables
updated_package_list=false
upgraded_packages=false
full_upgrade_done=false
removed_unnecessary=false
cache_cleaned=false

# Check and hold excluded packages before upgrades
print_section "Package Exclusion Check"
check_problematic_packages
print_success "Package exclusion check completed"

# Step 1: Update the package list
print_section "Step 1: Package List Update"
estimate_time_remaining "update"
if prompt_user "Do you want to update the package list?" "auto_update_package_list"; then
    if retry_operation "sudo $APT_CMD update >/dev/null 2>&1"; then
        show_progress 10 "Updating package list"
        print_success "Package list updated successfully"
        updated_package_list=true
        log "Package list updated successfully"
    else
        print_error "Failed to update package list after ${retry_count:-3} attempts"
        exit 1
    fi
else
    print_warning "Skipping package list update"
    log "Skipping package list update."
fi

# Step 2: Upgrade installed packages
print_section "Step 2: Package Upgrade"
estimate_time_remaining "upgrade"
if prompt_user "Do you want to upgrade installed packages?" "auto_upgrade_packages"; then
    print_info "Analyzing packages to upgrade..."
    
    # Get package count before upgrade
    packages_before=$(dpkg -l | grep -c "^ii")
    
    print_info "Upgrading installed packages (this may take a while)..."
    if retry_operation "sudo $APT_CMD upgrade -y"; then
        packages_after=$(dpkg -l | grep -c "^ii")
        PACKAGES_UPGRADED=$((packages_after - packages_before))
        print_success "Installed packages upgraded successfully"
        print_info "Packages upgraded: $PACKAGES_UPGRADED"
        upgraded_packages=true
        log "Installed packages upgraded successfully. Count: $PACKAGES_UPGRADED"
    else
        print_error "Failed to upgrade packages after ${retry_count:-3} attempts"
        exit 1
    fi
else
    print_warning "Skipping installed package upgrade"
    log "Skipping installed package upgrade."
fi

# Step 3: Perform full upgrade
print_section "Step 3: Full System Upgrade"
estimate_time_remaining "full-upgrade"
if prompt_user "Do you want to perform a full upgrade?" "auto_full_upgrade"; then
    print_info "Performing a full upgrade (this may take a while)..."
    if retry_operation "sudo $APT_CMD full-upgrade -y"; then
        print_success "Full upgrade completed successfully"
        full_upgrade_done=true
        log "Full upgrade completed successfully"
    else
        print_error "Failed to perform full upgrade after ${retry_count:-3} attempts"
        exit 1
    fi
else
    print_warning "Skipping full upgrade"
    log "Skipping full upgrade."
fi

# Step 4: Remove unnecessary packages
print_section "Step 4: Cleanup Unnecessary Packages"
estimate_time_remaining "autoremove"
if prompt_user "Do you want to remove unnecessary packages?" "auto_remove_unnecessary"; then
    # Count packages before removal
    packages_before_removal=$(dpkg -l | grep -c "^ii")
    
    if retry_operation "sudo apt autoremove -y >/dev/null 2>&1"; then
        show_progress_bar 3 "Removing unnecessary packages"
        packages_after_removal=$(dpkg -l | grep -c "^ii")
        PACKAGES_REMOVED=$((packages_before_removal - packages_after_removal))
        print_success "Unnecessary packages removed successfully"
        print_info "Packages removed: $PACKAGES_REMOVED"
        removed_unnecessary=true
        log "Unnecessary packages removed successfully. Count: $PACKAGES_REMOVED"
    else
        print_error "Failed to remove unnecessary packages after ${retry_count:-3} attempts"
        exit 1
    fi
else
    print_warning "Skipping unnecessary package removal"
    log "Skipping unnecessary package removal."
fi

# Step 5: Clean up package files
print_section "Step 5: Cache Cleanup"
estimate_time_remaining "clean"
if prompt_user "Do you want to clean up cached package files?" "auto_clean_cache"; then
    # Get cache size before cleaning
    cache_size_before=$(du -sm /var/cache/apt 2>/dev/null | cut -f1 || echo "0")
    
    if retry_operation "sudo apt clean >/dev/null 2>&1"; then
        show_progress 8 "Cleaning cached package files"
        cache_size_after=$(du -sm /var/cache/apt 2>/dev/null | cut -f1 || echo "0")
        cache_freed=$((cache_size_before - cache_size_after))
        print_success "Cached package files cleaned successfully"
        print_info "Cache space freed: ${cache_freed}MB"
        cache_cleaned=true
        log "Cached package files cleaned successfully. Space freed: ${cache_freed}MB"
    else
        print_error "Failed to clean cached package files after ${retry_count:-3} attempts"
        exit 1
    fi
else
    print_warning "Skipping cache cleanup"
    log "Skipping cache cleanup."
fi



# Performance metrics
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
NETWORK_USAGE_END=$(get_network_usage)
MEMORY_USAGE_END=$(get_memory_usage)
NETWORK_USED=$((NETWORK_USAGE_END - NETWORK_USAGE_START))

# Print enhanced summary
print_summary() {
    final_space=$(check_disk_space)
    space_freed=$((initial_space - final_space))
    
    print_section "Update Summary Report"
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${WHITE}                              ${SHIELD} SUMMARY REPORT ${SHIELD}                             ${BLUE}║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    
    # Task completion status
    if [ "$updated_package_list" = true ]; then
        echo -e "${BLUE}║ ${GREEN}${CHECK_MARK} Package list updated${NC}                                                  ${BLUE}║${NC}"
    else
        echo -e "${BLUE}║ ${YELLOW}${CROSS_MARK} Package list update skipped${NC}                                          ${BLUE}║${NC}"
    fi
    
    if [ "$upgraded_packages" = true ]; then
        echo -e "${BLUE}║ ${GREEN}${CHECK_MARK} Packages upgraded${NC} (${PACKAGES_UPGRADED} packages)                                    ${BLUE}║${NC}"
    else
        echo -e "${BLUE}║ ${YELLOW}${CROSS_MARK} Package upgrade skipped${NC}                                              ${BLUE}║${NC}"
    fi
    
    if [ "$full_upgrade_done" = true ]; then
        echo -e "${BLUE}║ ${GREEN}${CHECK_MARK} Full upgrade performed${NC}                                                ${BLUE}║${NC}"
    else
        echo -e "${BLUE}║ ${YELLOW}${CROSS_MARK} Full upgrade skipped${NC}                                                 ${BLUE}║${NC}"
    fi
    
    if [ "$removed_unnecessary" = true ]; then
        echo -e "${BLUE}║ ${GREEN}${CHECK_MARK} Unnecessary packages removed${NC} (${PACKAGES_REMOVED} packages)                          ${BLUE}║${NC}"
    else
        echo -e "${BLUE}║ ${YELLOW}${CROSS_MARK} Unnecessary package removal skipped${NC}                                 ${BLUE}║${NC}"
    fi
    
    if [ "$cache_cleaned" = true ]; then
        echo -e "${BLUE}║ ${GREEN}${CHECK_MARK} Cache cleaned${NC}                                                         ${BLUE}║${NC}"
    else
        echo -e "${BLUE}║ ${YELLOW}${CROSS_MARK} Cache cleanup skipped${NC}                                                ${BLUE}║${NC}"
    fi
    
    echo -e "${BLUE}║${NC}                                                                              ${BLUE}║${NC}"
    
    # Performance metrics
    echo -e "${BLUE}║ ${CHART} Performance Metrics:${NC}                                                    ${BLUE}║${NC}"
    echo -e "${BLUE}║   ${CLOCK} Total time: ${BOLD}$((TOTAL_TIME / 60))m $((TOTAL_TIME % 60))s${NC}                                          ${BLUE}║${NC}"
    
    if [ $space_freed -gt 0 ]; then
        echo -e "${BLUE}║   ${CLEAN} Disk space freed: ${GREEN}${BOLD}${space_freed}%${NC}                                          ${BLUE}║${NC}"
    else
        echo -e "${BLUE}║   ${INFO_SYMBOL} Disk space used: ${BOLD}${final_space}%${NC}                                           ${BLUE}║${NC}"
    fi
    
    if [ "$SECURITY_UPDATES" -gt 0 ]; then
        echo -e "${BLUE}║   ${SHIELD} Security updates: ${BOLD}${SECURITY_UPDATES}${NC}                                             ${BLUE}║${NC}"
    fi
    
    if [ ${#FAILED_OPERATIONS[@]} -gt 0 ]; then
        echo -e "${BLUE}║   ${WARNING_SYMBOL} Failed operations: ${BOLD}${#FAILED_OPERATIONS[@]}${NC}                                         ${BLUE}║${NC}"
    fi
    
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    
    # Detailed logs
    log "Update Summary:"
    log "- Package list updated: $updated_package_list"
    log "- Packages upgraded: $upgraded_packages ($PACKAGES_UPGRADED packages)"
    log "- Full upgrade performed: $full_upgrade_done"
    log "- Unnecessary packages removed: $removed_unnecessary ($PACKAGES_REMOVED packages)"
    log "- Cache cleaned: $cache_cleaned"
    log "- Total execution time: ${TOTAL_TIME}s"
    log "- Disk space freed: ${space_freed}%"
    log "- Security updates processed: $SECURITY_UPDATES"
    log "- Failed operations: ${#FAILED_OPERATIONS[@]}"
    
    # Send email notification if enabled
    if [ "${enable_email_notifications:-false}" = "true" ]; then
        local email_body="Update Summary for $(hostname):
- Packages upgraded: $PACKAGES_UPGRADED
- Packages removed: $PACKAGES_REMOVED  
- Security updates: $SECURITY_UPDATES
- Disk space freed: ${space_freed}%
- Total time: $((TOTAL_TIME / 60))m $((TOTAL_TIME % 60))s
- Status: $([ ${#FAILED_OPERATIONS[@]} -eq 0 ] && echo "Success" || echo "Completed with ${#FAILED_OPERATIONS[@]} failed operations")

Log file: $LOG_FILE"
        send_email_notification "System Update Completed - $(hostname)" "$email_body"
    fi
}

print_summary

# Check if reboot is required
check_reboot_required() {
    print_section "Reboot Check"
    if [ -f /var/run/reboot-required ]; then
        print_warning "A system reboot is required to complete the update process."
        if [ -f /var/run/reboot-required.pkgs ]; then
            print_info "Packages requiring reboot:"
            while read -r pkg; do
                echo -e "  ${YELLOW}• $pkg${NC}"
            done < /var/run/reboot-required.pkgs
        fi
        
        if prompt_user "Do you want to reboot now?"; then
            print_info "Rebooting system in 10 seconds... (Press Ctrl+C to cancel)"
            for i in {10..1}; do
                echo -ne "\r${YELLOW}Rebooting in $i seconds...${NC}"
                sleep 1
            done
            echo
            log "System reboot initiated by user"
            send_email_notification "System Reboot - $(hostname)" "System is rebooting to complete updates."
            sudo reboot
        else
            print_warning "Please remember to reboot your system as soon as possible."
            log "Reboot required but deferred by user"
        fi
    else
        print_success "No reboot required at this time."
        log "No reboot required"
    fi
}

check_reboot_required

# Final cleanup and completion
print_section "Completion"
print_success "Script execution completed successfully!"

if [ ${#FAILED_OPERATIONS[@]} -gt 0 ]; then
    print_warning "Some operations failed:"
    for op in "${FAILED_OPERATIONS[@]}"; do
        echo -e "  ${RED}• $op${NC}"
    done
fi

echo
echo -e "${GREEN}${BOLD}Thank you for using BigBearTechWorld scripts! ${ROCKET}${NC}"
echo
echo -e "${YELLOW}${BOLD}💝 Enjoyed this script? Show your support:${NC}"
echo -e "${GREEN}   ☕ Buy me a tea: ${BOLD}https://ko-fi.com/bigbeartechworld${NC}"
echo -e "${CYAN}   🌟 Star on GitHub: ${BOLD}https://github.com/bigbeartechworld/big-bear-scripts${NC}"
echo -e "${PURPLE}   📺 Subscribe: ${BOLD}https://youtube.com/@BigBearTechWorld${NC}"
echo
echo -e "${BLUE}${BOLD}📁 Files:${NC}"
echo -e "${CYAN}   Configuration: $CONFIG_FILE${NC}"
echo -e "${CYAN}   Logs: $LOG_FILE${NC}"
echo -e "${CYAN}   JSON Log: $JSON_LOG_FILE${NC}"
echo

log "Script execution completed successfully"
