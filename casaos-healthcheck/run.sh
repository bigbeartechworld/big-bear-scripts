#!/usr/bin/env bash

# Constants
CONFIG_FILE="/etc/casaos/gateway.ini"
SERVICE_PREFIX="casaos"
CHECK_MARK="\033[0;32m✓\033[0m"
CROSS_MARK="\033[0;31m✗\033[0m"
WARNING_MARK="\033[0;33m⚠\033[0m"

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "\033[${color}m${message}\033[0m"
}

# Function to print section headers
print_header() {
    local header=$1
    echo "-------------------"
    print_color "1;34" "$header"
    echo "-------------------"
}

# Function to check service status
check_service_status() {
    local service=$1
    local status=$(systemctl is-active "$service")

    if [[ "$service" == "casaos-local-storage-first.service" && "$status" == "inactive" ]]; then
        print_color "0;33" "${WARNING_MARK} $service is normally stopped"
        return
    fi

    case $status in
        "active")
            print_color "0;32" "${CHECK_MARK} $service is running"
            ;;
        "inactive")
            print_color "0;31" "${CROSS_MARK} $service is stopped"
            ;;
        "failed")
            print_color "0;31" "${CROSS_MARK} $service has failed"
            ;;
        *)
            print_color "0;33" "${WARNING_MARK} $service status is unknown: $status"
            ;;
    esac
}

# Function to simulate log entries for testing
simulate_logs() {
    cat << EOF
{"time":"2024-08-12T12:37:58.012507488-05:00","remote_ip":"127.0.0.1","host":"127.0.0.1:43139","method":"POST","uri":"/v1/notify/system_status","status":200,"error":"","latency":67789}
{"time":"2024-08-12T12:22:44.297502408-05:00","remote_ip":"192.168.1.212","host":"192.168.20.105","method":"GET","uri":"/v2/local_storage/merge","status":503,"error":"","latency":557474}
{"time":"2024-08-12T13:00:00.123456789-05:00","remote_ip":"192.168.1.100","host":"192.168.20.105","method":"GET","uri":"/v1/system/status","status":500,"error":"Internal Server Error","latency":1000000}
{"time":"2024-08-12T13:05:00.987654321-05:00","remote_ip":"192.168.1.101","host":"192.168.20.105","method":"POST","uri":"/v1/apps/install","status":200,"error":"App installation failed","latency":2000000}
{"time":"2024-08-12T13:10:00.246813579-05:00","remote_ip":"192.168.1.102","host":"192.168.20.105","method":"GET","uri":"/v1/storage/list","status":404,"error":"Storage not found","latency":500000}
EOF
}

# Function to check if a log line is a real error
is_real_error() {
    local line="$1"

    # Known non-error patterns (can be configured or extended as needed)
    local non_error_patterns=(
        "remote_ip\":\"127.0.0.1\",\"host\":\"127.0.0.1:"
        "status\":200,\"error\":\"\""
        "uri\":\"/v2/local_storage/merge\".*status\":503"
    )

    # Exclude known non-error patterns
    for pattern in "${non_error_patterns[@]}"; do
        [[ "$line" =~ $pattern ]] && return 1
    done

    # Include patterns that are likely real errors
    [[ "$line" =~ "error\":\"[^\"]+\"" && ! "$line" =~ "error\":\"\"" ]] && return 0
    [[ "$line" =~ "status\":5[0-9][0-9]" && ! "$line" =~ "status\":503" ]] && return 0
    [[ "$line" =~ "status\":4[0-9][0-9]" ]] && return 0

    # If none of the above conditions are met, it's not considered a real error
    return 1
}

# Check for any errors in the service logs
check_service_logs() {
    local source="$1"
    echo ""
    print_header "Service Logs (last 50 lines):"
    ERROR_FOUND=false
    while read -r service; do
        # Use simulated logs if in test mode, otherwise use real logs
        if [[ "$source" == "simulated_test" ]]; then
            LOGS=$(simulate_logs)
        elif [[ "$source" == "real_test" ]]; then
            LOGS=$(journalctl -u "$service" -n 1000 2>/dev/null | tail -n 50)
        else
            LOGS=$(journalctl -u "$service" -n 50 2>/dev/null)
        fi

        ERRORS=$(echo "$LOGS" | while read -r line; do
            if is_real_error "$line"; then
                echo "$line"
            fi
        done)

        if [[ -n $ERRORS ]]; then
            ERROR_FOUND=true
            print_color "0;31" "Errors in $service logs:"
            echo "$ERRORS"
            echo "-----"
        elif [[ "$source" == "real_test" || "$source" == "simulated_test" ]]; then
            echo "No errors found in $service logs"
            echo "Sample log entries:"
            echo "$LOGS" | head -n 5
            echo "-----"
        fi
    done <<< "$SERVICES"

    if $ERROR_FOUND; then
        print_color "0;31" "${CROSS_MARK} Errors found in service logs"
    else
        print_color "0;32" "${CHECK_MARK} No errors found in service logs"
    fi
}

# Get a list of all casaos services
get_casaos_services() {
    systemctl list-units --all --type=service | grep "$SERVICE_PREFIX" | awk '{print $1}'
}

# Function to check DNS resolution for a list of registries
check_dns_resolution() {
    local registries=(
        "docker.io"
        "index.docker.io"
        "registry-1.docker.io"
        "registry.hub.docker.com"
        "gcr.io"
        "azurecr.io"
        "ghcr.io"
        "registry.gitlab.com"
    )
    local retries=3
    local timeout=5
    local dns_servers=("8.8.8.8" "1.1.1.1" "9.9.9.9" "208.67.222.222")

    print_header "DNS Resolution Check:"

    # Verify basic network connectivity
    if ! ping -c 1 8.8.8.8 &>/dev/null; then
        print_color "0;31" "${CROSS_MARK} Network connectivity issue: Unable to reach 8.8.8.8"
        return
    fi

    for registry in "${registries[@]}"; do
        local success=false
        for dns_server in "${dns_servers[@]}"; do
            for ((i=1; i<=retries; i++)); do
                if timeout $timeout nslookup "$registry" "$dns_server" &>/dev/null; then
                    print_color "0;32" "${CHECK_MARK} DNS resolution for $registry is successful using DNS server $dns_server"
                    success=true
                    break 2
                else
                    echo "Attempt $i of $retries for $registry using DNS server $dns_server failed"
                fi
            done
        done

        if [ "$success" = false ]; then
            print_color "0;31" "${CROSS_MARK} DNS resolution for $registry failed"
            echo "Debugging info for $registry:"
            nslookup "$registry" 2>&1
            # Alternative check with dig for more detailed output
            if command -v dig &> /dev/null; then
                echo "Dig output:"
                dig +short "$registry" @8.8.8.8
            fi
        fi
    done
}

# Function to check Docker status
check_docker_status() {
    print_header "Docker Status Check"
    if command -v docker &> /dev/null; then
        if docker info &> /dev/null; then
            print_color "0;32" "${CHECK_MARK} Docker is running"
        else
            print_color "0;31" "${CROSS_MARK} Docker is installed but not running"
        fi
    else
        print_color "0;31" "${CROSS_MARK} Docker is not installed"
    fi
}

# Function to check storage health
check_storage_health() {
    print_header "Storage Health Check"
    local disks=$(lsblk -ndo NAME,TYPE | awk '$2=="disk"{print $1}')
    for disk in $disks; do
        if smartctl -H /dev/$disk &> /dev/null; then
            local health=$(smartctl -H /dev/$disk | grep "SMART overall-health")
            if [[ $health == *"PASSED"* ]]; then
                print_color "0;32" "${CHECK_MARK} /dev/$disk is healthy"
            else
                print_color "0;31" "${CROSS_MARK} /dev/$disk may have issues"
            fi
        else
            print_color "0;33" "${WARNING_MARK} Unable to check health of /dev/$disk"
        fi
    done
}

# Function to check disk space
check_disk_space() {
    print_header "Disk Space Check"
    local threshold=80
    local usage=$(df / | grep / | awk '{ print $5 }' | sed 's/%//g')
    if [ "$usage" -ge "$threshold" ]; then
        print_color "0;31" "${CROSS_MARK} Disk usage is at ${usage}%, which is above the threshold of ${threshold}%"
    else
        print_color "0;32" "${CHECK_MARK} Disk usage is at ${usage}%, which is below the threshold of ${threshold}%"
    fi
}

# Function to check CPU load
check_cpu_load() {
    print_header "CPU Load Check"
    local load=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d, -f1 | xargs)
    local cores=$(nproc)
    local threshold=$(awk "BEGIN {print $cores * 0.7}")
    if (( $(awk "BEGIN {print ($load > $threshold) ? 1 : 0}") )); then
        print_color "0;31" "${CROSS_MARK} CPU load is high: ${load} (Threshold: ${threshold})"
    else
        print_color "0;32" "${CHECK_MARK} CPU load is acceptable: ${load} (Threshold: ${threshold})"
    fi
}

# Function to check memory usage
check_memory_usage() {
    print_header "Memory Usage Check"
    local total_mem=$(free -m | awk '/^Mem:/ { print $2 }')
    local used_mem=$(free -m | awk '/^Mem:/ { print $3 }')
    local threshold=$(awk "BEGIN {print int($total_mem * 0.8)}")
    if (( $(awk "BEGIN {print ($used_mem > $threshold) ? 1 : 0}") )); then
        print_color "0;31" "${CROSS_MARK} Memory usage is high: ${used_mem}MB used of ${total_mem}MB (Threshold: ${threshold}MB)"
    else
        print_color "0;32" "${CHECK_MARK} Memory usage is acceptable: ${used_mem}MB used of ${total_mem}MB (Threshold: ${threshold}MB)"
    fi
}

# Function to check system temperature
check_system_temperature() {
    print_header "System Temperature Check"
    if command -v sensors &> /dev/null; then
        sensors | grep -E 'Core|temp' | while read -r line; do
            local temp=$(echo "$line" | awk '{print $2}' | sed 's/+//' | sed 's/°C//')
            if (( $(awk "BEGIN {print ($temp > 80) ? 1 : 0}") )); then
                print_color "0;31" "${CROSS_MARK} High temperature detected: ${line}"
            else
                print_color "0;32" "${CHECK_MARK} Temperature is normal: ${line}"
            fi
        done
    elif [ -f "/sys/class/thermal/thermal_zone0/temp" ]; then
        local temp=$(awk '{print $1/1000}' /sys/class/thermal/thermal_zone0/temp)
        if (( $(awk "BEGIN {print ($temp > 80) ? 1 : 0}") )); then
            print_color "0;31" "${CROSS_MARK} High temperature detected: ${temp}°C"
        else
            print_color "0;32" "${CHECK_MARK} Temperature is normal: ${temp}°C"
        fi
    else
        print_color "0;33" "${WARNING_MARK} Unable to check system temperature. sensors command not found and /sys/class/thermal not available."
    fi
}

# Function to check for system updates
check_system_updates() {
    print_header "System Update Check"
    if command -v apt-get &> /dev/null; then
        local updates=$(apt-get -s upgrade | grep -P '^\d+ upgraded')
        print_color "0;32" "${CHECK_MARK} System updates available: ${updates}"
    else
        print_color "0;33" "${WARNING_MARK} apt-get command not found, skipping system update check"
    fi
}

check_docker_ports() {
    print_header "Docker Container Port Check"

    # Check if Docker is installed and running
    if ! command -v docker &> /dev/null || ! docker info &> /dev/null; then
        print_color "0;33" "${WARNING_MARK} Docker is not installed or not running. Skipping Docker port check."
        return
    fi

    # Check if UFW is installed and active
    if ! command -v ufw &> /dev/null || ! ufw status | grep -q "Status: active"; then
        print_color "0;33" "${WARNING_MARK} UFW is not installed or not active. Skipping firewall check for Docker ports."
        return
    fi

    # Get UFW rules
    ufw_rules=$(sudo ufw status | grep -E '^[0-9]+' | awk '{print $1}')

    # Get all running Docker containers
    containers=$(docker ps --format "{{.Names}}")

    for container in $containers; do
        # Get port mappings for each container
        ports=$(docker port $container | awk '{print $3}' | cut -d ':' -f2)

        for port in $ports; do
            if echo "$ufw_rules" | grep -q "^$port$"; then
                print_color "0;32" "${CHECK_MARK} Port $port for container $container is allowed by UFW."
            else
                print_color "0;31" "${CROSS_MARK} Port $port for container $container might be blocked by UFW."
            fi
        done
    done

    echo
    print_color "0;33" "Note: Please manually verify UFW rules for more complex configurations."
    echo "      You can do this by running 'sudo ufw status verbose'"
}

check_root_privileges() {
    if [ "$EUID" -ne 0 ]; then
        print_color "0;33" "${WARNING_MARK} This script requires root privileges for full functionality."
        echo "Some checks might fail or provide incomplete information without root access."
        echo "Consider running the script with sudo if you encounter permission-related issues."
        echo
        read -p "Do you want to continue without root privileges? (y/N) " -n 1 -r
        echo
        REPLY=${REPLY,,} # convert to lowercase
        if [[ $REPLY != "y" ]]; then
            echo "Exiting. Please run the script again with sudo."
            exit 1
        fi
    fi
}

check_sudo_privileges() {
    if ! sudo -n true 2>/dev/null; then
        print_color "0;33" "${WARNING_MARK} You are running as root, but might not have full sudo privileges."
        echo "Some checks might still fail or provide incomplete information."
        echo
        read -p "Do you want to continue? (y/N) " -n 1 -r
        echo
        REPLY=${REPLY,,} # convert to lowercase
        if [[ $REPLY != "y" ]]; then
            echo "Exiting. Please ensure you have full sudo privileges and run the script again."
            exit 1
        fi
    fi
}

# Function to check dmesg logs for errors
check_dmesg_errors() {
    print_header "DMESG Error Check"
    
    # Direct check if we can read dmesg output
    local dmesg_output=$(dmesg 2>/dev/null)
    if [ -n "$dmesg_output" ]; then
        local dmesg_errors=$(echo "$dmesg_output" | tail -n 1000 | grep -i "error\|failed\|failure\|panic\|critical" | grep -v "ACPI Error: AE_NOT_FOUND")
        
        if [ -n "$dmesg_errors" ]; then
            print_color "0;31" "${CROSS_MARK} Found system errors in dmesg:"
            echo "$dmesg_errors" | head -n 10
            local error_count=$(echo "$dmesg_errors" | wc -l)
            if [ $error_count -gt 10 ]; then
                echo "... and $(($error_count - 10)) more errors"
            fi
        else
            print_color "0;32" "${CHECK_MARK} No critical errors found in dmesg logs"
        fi
    else
        print_color "0;33" "${WARNING_MARK} Root privileges required to read dmesg logs. Run with sudo for full dmesg analysis."
    fi
}

check_process_resources() {
    print_header "Process Resource Check"
    
    echo "Top 5 CPU consuming processes:"
    ps aux --sort=-%cpu | head -6 | tail -5 | \
        awk '{printf "%-20s %5s%%\n", $11, $3}'
    
    echo -e "\nTop 5 Memory consuming processes:"
    ps aux --sort=-%mem | head -6 | tail -5 | \
        awk '{printf "%-20s %5s%%\n", $11, $4}'
    
    local zombie_count=$(ps aux | grep -w Z | wc -l)
    if [ "$zombie_count" -gt 0 ]; then
        print_color "0;31" "${CROSS_MARK} Found $zombie_count zombie processes"
    else
        print_color "0;32" "${CHECK_MARK} No zombie processes found"
    fi
}

# Main script flow
check_root_privileges

# If running as root, optionally check for sudo
if [ "$EUID" -eq 0 ]; then
    check_sudo_privileges
fi

# Main execution
if [[ "$1" == "simulated_test" ]]; then
    echo "Running in simulated test mode..."
    SERVICES="test-service"
    check_service_logs "simulated_test"
elif [[ "$1" == "real_test" ]]; then
    echo "Running in real error test mode..."
    SERVICES=$(get_casaos_services)
    print_header "Service Status Check:"
    while read -r service; do
        check_service_status "$service"
    done <<< "$SERVICES"
    check_service_logs "real_test"
else
    # Normal script execution
    # Display Welcome
    print_header "BigBearCasaOS Healthcheck V3.3"
    echo "Here are some links:"
    echo "https://community.bigbeartechworld.com"
    echo "https://github.com/BigBearTechWorld"
    echo ""
    echo "If you would like to support me, please consider buying me a tea:"
    echo "https://ko-fi.com/bigbeartechworld"
    echo ""

    # Display system information
    print_header "System Information:"
    echo "Operating System: $(lsb_release -d | cut -f 2-)"
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime -p)"
    echo "Packages: $(dpkg -l | wc -l)"
    echo "Shell: $SHELL"
    echo "Terminal: $(basename "$TERM")"
    echo "CPU: $(lscpu | grep 'Model name' | cut -d ':' -f 2 | xargs)"
    if command -v lspci &> /dev/null; then
        echo "GPU: $(lspci | grep -i --color 'vga\|3d\|2d')"
    else
        echo "GPU: Unable to detect (lspci not available)"
    fi
    echo "Memory: $(free -h | awk '/^Mem:/ {print $2 " Total, " $3 " Used"}')"
    echo ""

    print_header "CasaOS Healthcheck:"

    # Check if the configuration file exists
    if [[ -f $CONFIG_FILE ]]; then
        PORT=$(grep '^port=' "$CONFIG_FILE" | cut -d'=' -f2)
        IP_ADDR=$(hostname -I | awk '{print $1}')
        echo "Local IP address: $IP_ADDR"
        echo "Port number: $PORT"
        echo "Access URL: http://$IP_ADDR:$PORT"

        if command -v ufw &> /dev/null; then
            if ufw status | grep -q "$PORT.*DENY"; then
                print_color "0;33" "${WARNING_MARK} The port $PORT is blocked by UFW."
            else
                print_color "0;32" "${CHECK_MARK} The port $PORT is not blocked by UFW."
            fi
        else
            echo "UFW not installed, skipping firewall check."
        fi
    else
        print_color "0;31" "${CROSS_MARK} Error: Configuration file not found."
    fi

    # Docker port check
    check_docker_ports

    # DNS resolution check for Docker registries
    check_dns_resolution

    # Get a list of all casaos services and check their status
    SERVICES=$(get_casaos_services)

    print_header "Service Status Check:"
    while read -r service; do
        check_service_status "$service"
    done <<< "$SERVICES"

    check_service_logs "real"

    # New health checks
    check_docker_status
    check_storage_health
    check_disk_space
    check_cpu_load
    check_memory_usage
    check_system_temperature
    check_system_updates
    check_dmesg_errors
    check_process_resources

    print_header "Health Check Complete"
fi
