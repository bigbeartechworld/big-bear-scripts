#!/bin/bash

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# This script finds active network interfaces for arp-scan and exports them to a config file.
# It detects interfaces that are "UP" (usable for scanning), skips virtual container interfaces (veth),
# and handles special cases like eth0@if46 that might be in different network namespaces.

# Function to get and filter usable network interfaces with their states
get_usable_interfaces() {
    # Capture the output of 'ip link show' once to list all network interfaces
    # We use this single call to avoid issues with repeated calls failing for namespaced interfaces
    ip link show | 
    # Filter for lines starting with a number (interface entries), exclude loopback (lo)
    grep -E '^[0-9]+:' | grep -v 'lo:' | 
    # Process each line of output
    while read -r line; do
        # Extract the interface name (e.g., eth0@if46) from the line, removing whitespace
        iface=$(echo "$line" | awk -F: '{print $2}' | tr -d ' ')
        
        # Skip virtual Ethernet (veth) interfaces used by containers, as they’re not useful for general scanning
        if [[ "$iface" =~ ^veth ]]; then
            continue
        fi
        
        # Check if the interface has "UP" in its flags, meaning it’s active and usable
        if echo "$line" | grep -q "<.*,UP"; then
            # Extract the state (e.g., UP, DOWN) from the line
            state=$(echo "$line" | grep -o "state [A-Z]*" | awk '{print $2}')
            # Output the interface name and state, separated by | for later parsing
            echo "$iface|$state"
        fi
    done | 
    # Remove duplicates and sort the list
    sort -u
}

# Display Welcome
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}BigBear ARP Interface Finder V0.1${NC}"
echo -e "${BLUE}========================================${NC}"
echo "Here are some links:"
echo "https://community.bigbeartechworld.com"
echo "https://github.com/BigBearTechWorld"
echo ""
echo "If you would like to support me, please consider buying me a tea:"
echo "https://ko-fi.com/bigbeartechworld"
echo ""

# Get the list of usable interfaces and store it in an array
# The < <() syntax feeds the function output into mapfile
mapfile -t interface_lines < <(get_usable_interfaces)

# If no usable interfaces are found, exit with an error
if [ ${#interface_lines[@]} -eq 0 ]; then
    echo "No usable interfaces found!"
    exit 1
fi

# Initialize an array to store the final list of interface names
usable_interfaces=()

# Loop through each interface line to extract details and display them
for line in "${interface_lines[@]}"; do
    # Split the line into interface name and state using | as the delimiter
    iface=$(echo "$line" | cut -d'|' -f1)
    state=$(echo "$line" | cut -d'|' -f2)
    
    # Try to get the IP address for the interface; suppress errors if it fails (e.g., namespace issues)
    ip_addr=$(ip addr show "$iface" 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
    # If no IP is found (e.g., due to namespace mismatch), set a default message
    [ -z "$ip_addr" ] && ip_addr="No IP"
    
    # Display the interface details for the user
    echo "Found usable interface: $iface (IP: $ip_addr, State: $state)"
    
    # Add the interface name to the array
    usable_interfaces+=("$iface")
done

# Combine all usable interface names into a single space-separated string
IFACES="${usable_interfaces[*]}"
echo -e "\nUsable interfaces detected: $IFACES"

# Prepare the export command for the config file
echo -e "\nGenerated configuration:"
echo "export IFACES=\"$IFACES\""

# Write the export command to a file that can be sourced later
# This creates arp_scan_config.sh with the IFACES variable set
echo "export IFACES=\"$IFACES\"" > arp_scan_config.sh

# Tell the user how to use the generated config file
echo -e "\nConfiguration saved to arp_scan_config.sh"
echo "Source the file with: source ./arp_scan_config.sh"