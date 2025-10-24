#!/usr/bin/env bash

# Function to print headers
print_header() {
    echo "========================================="
    echo "  $1"
    echo "========================================="
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (sudo). Exiting."
   exit 1
fi

# Display Welcome
print_header "Big Bear Thread Border Router Communication Setup V0.0.1"
echo "Here are some links:"
echo "https://community.bigbeartechworld.com"
echo "https://github.com/BigBearTechWorld"
echo ""
echo "If you would like to support me, please consider buying me a tea:"
echo "https://ko-fi.com/bigbeartechworld"
echo ""

# Check kernel configuration for IPV6_ROUTER_PREF
if grep -q "CONFIG_IPV6_ROUTER_PREF=y" "/boot/config-$(uname -r)" 2>/dev/null; then
    echo "✅ CONFIG_IPV6_ROUTER_PREF is enabled"
else
    echo "❌ CONFIG_IPV6_ROUTER_PREF might not be enabled in kernel"
fi

# Check kernel configuration for IPV6_ROUTE_INFO
if grep -q "CONFIG_IPV6_ROUTE_INFO=y" "/boot/config-$(uname -r)" 2>/dev/null; then
    echo "✅ CONFIG_IPV6_ROUTE_INFO is enabled"
else
    echo "❌ CONFIG_IPV6_ROUTE_INFO might not be enabled in kernel"
fi

# Check IPv6 forwarding status
ipv6_forwarding=$(sysctl -n net.ipv6.conf.all.forwarding)
if [ "$ipv6_forwarding" -eq 0 ]; then
    echo "✅ IPv6 forwarding is disabled (recommended)"
else
    echo "⚠️  IPv6 forwarding is enabled (not recommended for Thread communication)"
    read -r -p "Would you like to disable IPv6 forwarding? (y/N): " disable_forwarding
    if [[ $disable_forwarding =~ ^[Yy]$ ]]; then
        sysctl -w net.ipv6.conf.all.forwarding=0
        
        # Update /etc/sysctl.conf idempotently
        if grep -q "^[[:space:]]*#*[[:space:]]*net\.ipv6\.conf\.all\.forwarding" /etc/sysctl.conf 2>/dev/null; then
            # Replace existing line (commented or uncommented)
            sed -i.bak 's/^[[:space:]]*#*[[:space:]]*net\.ipv6\.conf\.all\.forwarding.*/net.ipv6.conf.all.forwarding=0/' /etc/sysctl.conf
        else
            # Append if not found
            echo "net.ipv6.conf.all.forwarding=0" >> /etc/sysctl.conf
        fi
        
        echo "IPv6 forwarding has been disabled"
    fi
fi

# Check NetworkManager version if installed
if command -v networkctl &> /dev/null; then
    echo "systemd-networkd is being used"
elif command -v nmcli &> /dev/null; then
    nm_version=$(nmcli --version | awk '{print $4}')
    echo "NetworkManager version: $nm_version"
    if [[ $(echo "$nm_version" | awk -F. '{ print ($1 * 100 + $2) }') -lt 142 ]]; then
        echo "⚠️  Warning: NetworkManager version is below 1.42. Upgrade recommended."
    else
        echo "✅ NetworkManager version is 1.42 or higher"
    fi
else
    echo "Neither NetworkManager nor systemd-networkd detected"
fi

# Get list of network interfaces and show details
network_interfaces=$(ip -brief link show | awk '{print $1}' | grep -v 'lo')

if [ -n "$network_interfaces" ]; then
    echo "Available network interfaces:"
    echo "----------------------------"
    i=1
    declare -A interface_map
    for interface in $network_interfaces; do
        # Get base interface name (strip @if part)
        base_interface=${interface%@*}
        
        # Get interface status and addresses
        state=$(ip -brief link show "$base_interface" | awk '{print $2}')
        ipv6_addr=$(ip -6 addr show dev "$base_interface" 2>/dev/null | grep "inet6" | grep -v "fe80" | awk '{print $2}')
        ipv6_ll_addr=$(ip -6 addr show dev "$base_interface" 2>/dev/null | grep "inet6" | grep "fe80" | awk '{print $2}')
        ra_status=$(sysctl -n "net.ipv6.conf.$base_interface.accept_ra" 2>/dev/null || echo "N/A")

        echo "$i) $base_interface"
        echo "   Status: $state"
        if [[ "$state" == *"UP"* ]]; then
            echo "   ✅ Interface is active"
        else
            echo "   ❌ Interface is down"
        fi
        if [ -n "$ipv6_addr" ]; then
            echo "   IPv6 Global: $ipv6_addr"
        elif [ -n "$ipv6_ll_addr" ]; then
            echo "   IPv6 Link-Local: $ipv6_ll_addr"
            echo "   ⚠️  No global IPv6 address assigned"
        else
            echo "   ❌ No IPv6 addresses found"
        fi
        echo "   Router Advertisements: $([ "$ra_status" = "1" ] && echo "Enabled" || echo "Disabled")"
        echo "----------------------------"
        
        interface_map[$i]=$base_interface
        ((i++))
    done
    echo "Recommendation: Choose interfaces that are UP and have IPv6 addresses"
    echo "Enter the number(s) of interfaces to configure (e.g., '1' or '1 2 3'):"
    read -r selected_numbers
    
    for num in $selected_numbers; do
        # Validate numeric input
        if ! [[ $num =~ ^[0-9]+$ ]]; then
            echo "❌ Invalid selection: '$num' (not a number)"
            continue
        fi
        
        # Check if interface exists in map
        if [[ -z "${interface_map[$num]}" ]]; then
            echo "❌ Invalid selection: $num (no interface with this number)"
            continue
        fi
        
        interface="${interface_map[$num]}"
        echo "Configuring IPv6 RA settings for $interface..."
        
        # Apply settings immediately
        sysctl -w "net.ipv6.conf.$interface.accept_ra=1"
        sysctl -w "net.ipv6.conf.$interface.accept_ra_rt_info_max_plen=64"
        
        # Ask about persistence
        read -r -p "Would you like to make these settings persistent across reboots? (y/N): " persist
        if [[ $persist =~ ^[Yy]$ ]]; then
            # Check and add accept_ra setting idempotently
            if ! grep -Fxq "net.ipv6.conf.$interface.accept_ra=1" /etc/sysctl.conf 2>/dev/null; then
                echo "net.ipv6.conf.$interface.accept_ra=1" >> /etc/sysctl.conf
            fi
            
            # Check and add accept_ra_rt_info_max_plen setting idempotently
            if ! grep -Fxq "net.ipv6.conf.$interface.accept_ra_rt_info_max_plen=64" /etc/sysctl.conf 2>/dev/null; then
                echo "net.ipv6.conf.$interface.accept_ra_rt_info_max_plen=64" >> /etc/sysctl.conf
            fi
            
            echo "✅ Settings made persistent in /etc/sysctl.conf"
        fi
        
        echo "✅ Configured $interface"
    done
else
    echo "❌ No network interfaces detected"
fi
# Apply sysctl changes
sysctl -p

print_header "Setup Complete"
echo "Please review any warnings above and make necessary adjustments."
echo "If using NetworkManager < 1.42, consider upgrading for better Thread support."
