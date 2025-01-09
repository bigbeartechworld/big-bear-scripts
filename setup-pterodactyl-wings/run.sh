#!/bin/bash

# Check if exactly one argument (UUID) is provided to the script
if [ $# -ne 1 ]; then
   echo "Error: UUID argument is required"
   echo "Usage: $0 <uuid>"
   exit 1
fi

UUID=$1

# Display menu for user choice
echo "Please select an option:"
echo "1) Run full setup"
echo "2) Run chown commands only"
read -p "Enter your choice (1 or 2): " choice

case $choice in
    1)
        echo "Running full setup..."
        ;;
    2)
        # Create required directories
        echo "Creating required directories..."
        mkdir -p "/var/lib/pterodactyl/volumes"
        mkdir -p "/tmp/pterodactyl"
        mkdir -p "/etc/pterodactyl"
        mkdir -p "/var/log/pterodactyl"
        echo "Running chown commands only..."
        chown -R 988:988 /tmp/pterodactyl /etc/pterodactyl /var/log/pterodactyl /var/lib/pterodactyl
        echo "Chown commands completed."
        exit 0
        ;;
    *)
        echo "Invalid choice. Please run the script again and select 1 or 2."
        exit 1
        ;;
esac

# Function to check if a subnet is in use
is_subnet_in_use() {
    local subnet=$1
    local network_name=$2
    local subnet_base=${subnet%/*}

    # Check system routes first
    while read -r route; do
        if [[ "$route" == *"$subnet_base"* ]]; then
            local iface=$(echo "$route" | grep -o "dev [^ ]*" | cut -d' ' -f2)
            if [ -n "$iface" ] && [ "$iface" != "pterodactyl0" ]; then
                return 0
            fi
        fi
    done < <(ip route show)

    # Check Docker networks
    while read -r other_network; do
        if [ "$other_network" != "$network_name" ]; then
            if docker network inspect "$other_network" 2>/dev/null | grep -q "\"Subnet\": \"$subnet\""; then
                return 0
            fi
        fi
    done < <(docker network ls --format "{{.Name}}")

    return 1
}

# Function to find an available subnet
find_available_subnet() {
    local network_name=$1
    local subnet_ranges=(
        "172.40.0.0/16"
        "172.41.0.0/16"
        "172.42.0.0/16"
        "172.43.0.0/16"
        "172.44.0.0/16"
        "172.45.0.0/16"
        "172.46.0.0/16"
        "172.47.0.0/16"
    )

    for subnet in "${subnet_ranges[@]}"; do
        if ! is_subnet_in_use "$subnet" "$network_name"; then
            echo "$subnet"
            return 0
        fi
    done

    return 1
}

# Function to get gateway for subnet
get_gateway_for_subnet() {
    local subnet=$1
    echo "${subnet%.*}.1"
}

# Function to create pterodactyl network
create_pterodactyl_network() {
    local subnet=$1
    local gateway=$2

    # Remove existing network if it exists
    if docker network ls | grep -q "pterodactyl_nw"; then
        docker network rm pterodactyl_nw || true
    fi

    # Create the network with error checking
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
        return 1
    fi

    # Verify network was created
    if ! docker network ls | grep -q "pterodactyl_nw"; then
        return 1
    fi

    return 0
}

# Main network configuration function
configure_network() {
    # Find available subnet
    local new_subnet
    new_subnet=$(find_available_subnet "pterodactyl_nw")
    if [ $? -ne 0 ]; then
        echo "ERROR: Could not find available subnet"
        return 1
    fi

    # Get gateway
    local new_gateway
    new_gateway=$(get_gateway_for_subnet "$new_subnet")
    if [ $? -ne 0 ]; then
        echo "ERROR: Could not determine gateway"
        return 1
    fi

    echo "Using subnet: $new_subnet with gateway: $new_gateway"

    # Create network
    if ! create_pterodactyl_network "$new_subnet" "$new_gateway"; then
        echo "ERROR: Failed to create network"
        return 1
    fi

    echo "Network created successfully"
    return 0
}

# Create required directories
echo "Creating required directories..."
mkdir -p "/var/lib/pterodactyl/volumes/$UUID"
mkdir -p "/tmp/pterodactyl/$UUID"
mkdir -p "/etc/pterodactyl"
mkdir -p "/var/log/pterodactyl"

# Configure network
echo "Configuring network..."
if ! configure_network; then
    echo "ERROR: Network configuration failed"
    exit 1
fi

# Set ownership
echo "Setting directory permissions..."
chown -R 988:988 /tmp/pterodactyl /etc/pterodactyl /var/log/pterodactyl /var/lib/pterodactyl

# Restart pterodactyl-wings container
echo "Restarting pterodactyl-wings container..."
if ! docker restart pterodactyl-wings; then
    echo "WARNING: Failed to restart pterodactyl-wings container"
    echo "Please restart it manually using: docker restart pterodactyl-wings"
fi

echo "Setup completed successfully for UUID: $UUID"
