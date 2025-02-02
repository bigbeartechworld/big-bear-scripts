#!/bin/bash

# Configuration
PORTS_TO_SCAN="80,81,8080,8888,8000,8001,8008,8081,8880,3000,5000,5050"
MAX_PARALLEL_CHECKS=10
LOG_FILE="/tmp/bigbear-casaos-server-finder.log"
TIMEOUT=3

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize logging
init_logging() {
    echo "=== BigBearCasaOS Server Finder Log ===" > "$LOG_FILE"
    echo "Start time: $(date)" >> "$LOG_FILE"
}

# Log messages
log() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$LOG_FILE"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to find all available subnets
find_subnets() {
    local subnets=()
    while IFS= read -r line; do
        if [[ $line =~ inet[[:space:]]([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+) ]]; then
            local cidr=${BASH_REMATCH[1]}
            # Skip loopback addresses (e.g., 127.0.0.0/8)
            if [[ $cidr == 127.* ]]; then
                continue
            fi
            local network=$(echo "$cidr" | cut -d'/' -f1 | sed 's/\.[0-9]\+$/.0/')
            local prefix=$(echo "$cidr" | cut -d'/' -f2)
            subnets+=("$network/$prefix")
        fi
    done < <(ip addr show | grep "inet ")
    echo "${subnets[@]}"
}

# Function to show progress spinner
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " ${BLUE}[%c]${NC}  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Check for CasaOS server
check_casaos() {
    local ip=$1
    local port=$2
    if curl -s -m $TIMEOUT --connect-timeout $TIMEOUT "http://$ip:$port" 2>/dev/null | grep -q "CasaOS"; then
        local result="Found CasaOS server at: $ip:$port"
        echo -e "\r${GREEN}$result${NC}"
        echo "$result" >> "$TEMP_RESULTS"
        return 0
    fi
    return 1
}

# Main function
main() {
    # Display Welcome
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}BigBearCasaOS Server Finder V0.1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo "Here are some links:"
    echo "https://community.bigbeartechworld.com"
    echo "https://github.com/BigBearTechWorld"
    echo ""
    echo "If you would like to support me, please consider buying me a tea:"
    echo "https://ko-fi.com/bigbeartechworld"
    echo ""
    
    init_logging
    
    # Check for required tools
    if ! command_exists nmap || ! command_exists ip; then
        echo -e "${RED}Error:${NC} Required tools not found"
        echo -e "Missing: $(! command_exists nmap && echo -n "nmap ") $(! command_exists ip && echo -n "iproute2")"
        echo -e "${BLUE}Would you like to install them now? (y/N): ${NC}"
        read -r install_choice
        if [[ "$install_choice" =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}Installing required tools...${NC}"
            sudo apt-get install -y nmap iproute2
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Installation successful!${NC}"
            else
                echo -e "${RED}Installation failed!${NC}"
                log "Error: Required tools installation failed"
                exit 1
            fi
        else
            log "Error: Required tools not found"
            exit 1
        fi
    fi

    # Get available subnets
    echo -e "${BLUE}Discovering available networks...${NC}"
    SUBNETS=($(find_subnets))
    log "Discovered subnets: ${SUBNETS[*]}"

    if [ ${#SUBNETS[@]} -eq 0 ]; then
        echo -e "${RED}Error: No subnets found!${NC}"
        log "Error: No subnets found"
        exit 1
    fi

    echo -e "${GREEN}Found networks: ${SUBNETS[*]}${NC}"
    echo -e "${BLUE}Do you want to select a specific network to scan? (Faster) (y/N): ${NC}"
    read -r select_choice

    if [[ "$select_choice" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Available networks:${NC}"
        for i in "${!SUBNETS[@]}"; do
            echo -e "${YELLOW}[$((i+1))]${NC} ${SUBNETS[$i]}"
        done
        echo -n -e "${BLUE}Select network to scan [1-${#SUBNETS[@]}]: ${NC}"
        read -r choice

        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#SUBNETS[@]}" ]; then
            echo -e "${RED}Error: Invalid selection!${NC}"
            log "Error: Invalid subnet selection"
            exit 1
        fi

        TARGET_SUBNET="${SUBNETS[$((choice-1))]}"
        echo -e "${BLUE}Scanning network: ${GREEN}$TARGET_SUBNET${NC}"
        log "Selected subnet: $TARGET_SUBNET"
        NMAPPARAMS="$TARGET_SUBNET"
    else
        echo -e "${BLUE}Scanning all discovered networks...${NC}"
        log "Scanning networks: ${SUBNETS[*]}"
        NMAPPARAMS="${SUBNETS[*]}"
    fi

    # Create temporary files for results
    TEMP_NMAP=$(mktemp)
    TEMP_RESULTS=$(mktemp)
    touch "$TEMP_RESULTS"
    chmod 600 "$TEMP_RESULTS"
    export TEMP_RESULTS
    log "Created temporary files: $TEMP_NMAP, $TEMP_RESULTS"

    # Perform initial port scan
    echo -e "${BLUE}Scanning for open ports ($PORTS_TO_SCAN)...${NC}"
    nmap -p$PORTS_TO_SCAN $NMAPPARAMS -oG "$TEMP_NMAP" > /dev/null 2>&1 &
    spinner $!
    log "Nmap scan completed"

    # Process results
    echo -e "${BLUE}Checking for CasaOS servers...${NC}"
    TOTAL_HOSTS=$(grep "open" "$TEMP_NMAP" | wc -l)
    CURRENT_HOST=0
    FOUND_SERVERS=0

    # Export the function before parallel processing
    export -f check_casaos
    export TIMEOUT

    while read -r line; do
        IP=$(echo "$line" | awk '{print $2}')
        PORTS=$(echo "$line" | grep -oP '\d+/open' | cut -d'/' -f1)
        
        CURRENT_HOST=$((CURRENT_HOST + 1))
        printf "\r${YELLOW}Progress: [%d/%d] Checking %s...${NC}" "$CURRENT_HOST" "$TOTAL_HOSTS" "$IP"
        
        # Check ports in parallel
        echo "$PORTS" | xargs -P $MAX_PARALLEL_CHECKS -I {} bash -c "check_casaos $IP {}"
        
        echo -ne "\r\033[K"  # Clear the progress line
    done < <(grep "open" "$TEMP_NMAP")

    # Wait for all parallel processes to complete
    wait

    echo -e "\n${BLUE}Scan complete!${NC}"
    if [ -s "$TEMP_RESULTS" ]; then
        echo -e "${GREEN}Found CasaOS servers:${NC}"
        cat "$TEMP_RESULTS" | sed 's/^/  /'
        log "Found CasaOS servers: $(cat "$TEMP_RESULTS")"
    else
        echo -e "${YELLOW}No CasaOS servers found.${NC}"
        log "No CasaOS servers found"
    fi

    # Cleanup
    rm -f "$TEMP_NMAP" "$TEMP_RESULTS"
    log "Cleanup completed"
}

# Run main function
main