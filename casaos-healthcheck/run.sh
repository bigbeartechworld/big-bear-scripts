#!/bin/bash

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
    print_header "BigBearCasaOS Healthcheck V2"
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

    # Get a list of all casaos services and check their status
    SERVICES=$(get_casaos_services)

    print_header "Service Status Check:"
    while read -r service; do
        check_service_status "$service"
    done <<< "$SERVICES"

    check_service_logs "real"
fi
