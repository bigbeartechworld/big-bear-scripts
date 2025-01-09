#!/usr/bin/env bash

# Crafted by BigBearTechWorld
# Script to set up Pterodactyl server environment and networking
# Takes a UUID as an argument for server identification

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

# Function to show spinner for long-running operations
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p $pid > /dev/null; do
        for i in "${spinstr[@]}"; do
            printf "\r[%c] " "$i"
            sleep $delay
            printf "\b\b\b\b"
        done
    done
    printf "\r   \b\b\b"
}

# Input validation: Check if exactly one argument (UUID) is provided
if [ $# -ne 1 ]; then
   echo -e "${CROSS_MARK} Error: UUID argument is required"
   echo "Usage: $0 <uuid>"
   exit 1
fi

# Store the server UUID in a variable
UUID=$1

# Display Welcome ---->
print_header "BigBearCasaOS Setup Pterodactyl Wings V0.1"
echo "Here are some links:"
echo "https://community.bigbeartechworld.com"
echo "https://github.com/BigBearTechWorld"
echo ""
echo "If you would like to support me, please consider buying me a tea:"
echo "https://ko-fi.com/bigbeartechworld"
echo ""

# Display interactive menu for setup options ---->
echo "Please select an option:"
echo "1) Full setup - Create directories, set permissions, and configure networking"
echo "2) Quick setup - Only create directories and set permissions"
read -p "Enter your choice (1 or 2): " choice

# Process user's menu choice ---->
# Mission is a go 3 2 1 lift off!!!!
case $choice in
    1)
        echo -e "${CHECK_MARK} Selected: Full setup"
        ;;
    2)
        echo -e "${CHECK_MARK} Selected: Quick setup"
        echo -e "\n${WARNING_MARK} Creating required directories..."
        mkdir -p "/var/lib/pterodactyl/volumes"
        mkdir -p "/tmp/pterodactyl"
        mkdir -p "/etc/pterodactyl"
        mkdir -p "/var/log/pterodactyl"
        echo -e "${WARNING_MARK} Running chown commands..."
        (chown -R 988:988 /tmp/pterodactyl /etc/pterodactyl /var/log/pterodactyl /var/lib/pterodactyl) &
        show_spinner $!
        echo -e "${CHECK_MARK} Chown commands completed successfully."
        exit 0
        ;;
    *)
        echo -e "${CROSS_MARK} Invalid choice. Please run the script again and select 1 or 2."
        exit 1
        ;;
esac

# Running full setup ---->
echo -e "\n${WARNING_MARK} Initiating full setup process..."

# Function to check if a subnet is already in use by either system routes or Docker networks
# Parameters: 
#   $1 = subnet to check (e.g., "172.40.0.0/16")
#   $2 = network name to exclude from check (to avoid false positives with our own network)
# Returns:
#   0 (true) if subnet is in use
#   1 (false) if subnet is available
is_subnet_in_use() {
    # Store input parameters in local variables for safety
    local subnet=$1
    local network_name=$2
    # Remove CIDR notation (e.g., "172.40.0.0/16" becomes "172.40.0.0")
    local subnet_base=${subnet%/*}  

    # First Phase: Check system routes for subnet usage
    # Use process substitution to read output of 'ip route show'
    while read -r route; do
        # Check if the current route contains our subnet base
        if [[ "$route" == *"$subnet_base"* ]]; then
            # Extract interface name from route (e.g., "dev eth0" becomes "eth0")
            # grep -o extracts only matching pattern
            # cut -d' ' -f2 splits on space and takes second field
            local iface=$(echo "$route" | grep -o "dev [^ ]*" | cut -d' ' -f2)
            
            # Verify interface exists (-n) and isn't our pterodactyl interface
            # We ignore pterodactyl0 to avoid detecting our own network
            if [ -n "$iface" ] && [ "$iface" != "pterodactyl0" ]; then
                return 0  # Subnet is in use by another interface
            fi
        fi
    done < <(ip route show)  # Feed output of 'ip route show' into while loop

    # Second Phase: Check Docker networks for subnet usage
    # Use process substitution to read Docker networks
    while read -r other_network; do
        # Skip checking our own network to avoid false positives
        if [ "$other_network" != "$network_name" ]; then
            # Inspect Docker network configuration
            # 2>/dev/null suppresses errors if network doesn't exist
            # grep -q quietly checks for subnet match
            if docker network inspect "$other_network" 2>/dev/null | grep -q "\"Subnet\": \"$subnet\""; then
                return 0  # Subnet is in use by another Docker network
            fi
        fi
    done < <(docker network ls --format "{{.Name}}")  # Get list of Docker networks

    # If we get here, no conflicts were found
    return 1  # Subnet is available for use
}

# Function to find an available subnet for Docker networking
# Takes a network name as parameter to avoid checking against itself
# Returns:
#   - First available subnet via echo
#   - 0 if subnet found successfully
#   - 1 if no subnets are available
find_available_subnet() {
   # Store network name parameter locally
   local network_name=$1

   # Define array of possible subnet ranges to try
   # Using 172.40-47 range to avoid conflicts with:
   # - Docker default subnet (172.17.0.0/16)
   # - Common private network ranges
   # Each subnet provides 65,534 usable addresses (/16 network)
   local subnet_ranges=(
       "172.40.0.0/16"  # Provides 172.40.0.1 - 172.40.255.254
       "172.41.0.0/16"  # Provides 172.41.0.1 - 172.41.255.254
       "172.42.0.0/16"  # Provides 172.42.0.1 - 172.42.255.254
       "172.43.0.0/16"  # Provides 172.43.0.1 - 172.43.255.254
       "172.44.0.0/16"  # Provides 172.44.0.1 - 172.44.255.254
       "172.45.0.0/16"  # Provides 172.45.0.1 - 172.45.255.254
       "172.46.0.0/16"  # Provides 172.46.0.1 - 172.46.255.254
       "172.47.0.0/16"  # Provides 172.47.0.1 - 172.47.255.254
   )

   # Iterate through each subnet in the array until we find an available one
   # [@] expands array to list of elements
   for subnet in "${subnet_ranges[@]}"; do
       # Check if subnet is available using is_subnet_in_use function
       # ! inverts the return value since is_subnet_in_use returns 0 when in use
       if ! is_subnet_in_use "$subnet" "$network_name"; then
           echo "$subnet"    # Output the available subnet
           return 0         # Return success
       fi
   done

   # If we've tried all subnets and found none available
   return 1  # Return failure - no available subnets found :( <Mission Failed>
}

# Function to calculate gateway IP for a given subnet
get_gateway_for_subnet() {
    local subnet=$1
    echo "${subnet%.*}.1"  # Use .1 as the gateway address
}

# Function to create Docker network for Pterodactyl
create_pterodactyl_network() {
    local subnet=$1
    local gateway=$2

    # Remove existing network if it exists
    if docker network ls | grep -q "pterodactyl_nw"; then
        docker network rm pterodactyl_nw || true
    fi

    # Create new network with specified configuration
    if ! docker network create \
        --driver=bridge \
        --ipv6 \
        --subnet="$subnet" \
        --gateway="$gateway" \
        --subnet=fd00::/64 \
        --gateway=fd00::1 \
        -o "com.docker.network.bridge.name=pterodactyl0" \
        -o "com.docker.network.bridge.enable_ip_masquerade=true" \
        -o "com.docker.network.bridge.enable_icc=true" \
        pterodactyl_nw; then
        return 1 # Network creation failed
    fi

    # Verify network creation
    if ! docker network ls | grep -q "pterodactyl_nw"; then
        return 1 # Network creation failed
    fi

    return 0 # Return success :)
}

# Main function to orchestrate the network configuration process
# This function coordinates:
# - Finding an available subnet
# - Calculating the gateway address
# - Creating the Docker network
# Returns:
#   0 on success
#   1 on any error
configure_network() {
   # Step 1: Find an available subnet
   # Store result in local variable for safety
   local new_subnet
   # Call find_available_subnet and capture its output
   # pterodactyl_nw is passed to avoid self-reference in subnet checks
   new_subnet=$(find_available_subnet "pterodactyl_nw")
   # Check return status of find_available_subnet
   # $? contains the return value of the last command
   if [ $? -ne 0 ]; then
       echo -e "${CROSS_MARK} ERROR: Could not find available subnet"
       return 1
   fi
   echo -e "${CHECK_MARK} Found available subnet: $new_subnet"

   # Step 2: Calculate the gateway IP address for our subnet
   # Store in local variable for safety
   local new_gateway
   # Call get_gateway_for_subnet to calculate the gateway IP
   # Typically this will be the .1 address in the subnet
   new_gateway=$(get_gateway_for_subnet "$new_subnet")
   # Verify gateway calculation was successful
   if [ $? -ne 0 ]; then
       echo "ERROR: Could not determine gateway"
       return 1  # Exit function with error
   fi

   # Echo results
   echo -e "${CHECK_MARK} Gateway IP set to: $new_gateway"

   # Step 3: Create the Docker network
   # Use ! to invert the return value since we want to check for failure
   # Pass both subnet and gateway to create_pterodactyl_network
   if ! create_pterodactyl_network "$new_subnet" "$new_gateway"; then
       echo "ERROR: Failed to create network"
       return 1  # Exit function with error
   fi
   echo -e "${CHECK_MARK} Docker network created successfully"

   # If we get here, all steps completed successfully Woohooo!!!
   echo "Network created successfully"
   return 0  # Return success :)
}

# Create directory structure for Pterodactyl
echo -e "\n${WARNING_MARK} Creating required directories..."
mkdir -p "/var/lib/pterodactyl/volumes/$UUID"
mkdir -p "/tmp/pterodactyl/$UUID"
mkdir -p "/etc/pterodactyl"
mkdir -p "/var/log/pterodactyl"

# Set up network configuration for Pterodactyl
echo -e "\n${WARNING_MARK} Configuring network..."
if ! configure_network; then
    echo "ERROR: Network configuration failed"
    exit 1
fi

# Set appropriate ownership for Pterodactyl directories
echo -e "\n${WARNING_MARK} Setting directory permissions..."
chown -R 988:988 /tmp/pterodactyl /etc/pterodactyl /var/log/pterodactyl /var/lib/pterodactyl

# Restart the Pterodactyl wings service
echo -e "\n${WARNING_MARK} Restarting pterodactyl-wings container..."
if ! docker restart pterodactyl-wings; then
    echo -e "${CROSS_MARK} WARNING: Failed to restart pterodactyl-wings container"
    echo "Please restart it manually using: docker restart pterodactyl-wings"
fi

# Mission is complete
echo -e "\n${CHECK_MARK} Setup completed successfully for UUID: $UUID"