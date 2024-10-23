#!/usr/bin/env bash

# This script modifies the DNS settings and disables systemd-resolved

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Define package manager and utility-to-package mapping for Ubuntu/Debian
PKG_MANAGER="apt-get"
pkg_map=( ["netstat"]="net-tools" )

# Update package manager
echo "Updating package manager..."
$PKG_MANAGER update -y

# Check for required utilities and install if missing
for cmd in "systemctl" "lsof" "netstat" "nslookup" "awk" "grep" "sed"; do
  if ! command -v $cmd &> /dev/null; then
    echo "$cmd is required but not installed. Attempting to install..."
    case $cmd in
      "netstat") sudo apt-get install -y net-tools ;;
      "lsof") sudo apt-get install -y lsof ;;
      "nslookup") sudo apt-get install -y dnsutils ;;
      *) echo "$cmd is not a package or is already installed" ;;
    esac
  fi
done

resolv_conf="/etc/resolv.conf"

echo "List of processes with port 53 open:"
lsof -i :53 || netstat -tulpn | grep ":53 "

read -p "This will display processes using port 53 and then disable systemd-resolved. Continue? (y/n): " choice
if [[ ! "$choice" =~ [yY] ]]; then
    echo "Aborted."
    exit 0
fi

echo "Disabling and stopping systemd-resolved..."
systemctl disable systemd-resolved.service
systemctl stop systemd-resolved.service

echo "Checking if port 53 is clear..."
if lsof -i :53 | grep -q '.'; then
    echo "Port 53 is still in use."
else
    echo "Port 53 is clear."
fi

current_dns=$(grep '^nameserver' "$resolv_conf" | awk '{print $2}')
echo "Current DNS: $current_dns"

read -p "Enter new DNS (default is 1.1.1.1): " dns_server
dns_server=${dns_server:-1.1.1.1}

if nslookup bigbeartechworld.com "$dns_server" &> /dev/null; then
    echo "$dns_server can resolve correctly."
else
    echo "$dns_server cannot resolve. Exiting."
    exit 1
fi

# Backup
if [ ! -f "$resolv_conf.bak" ]; then
    cp "$resolv_conf" "$resolv_conf.bak"
else
    echo "Backup already exists, skipping backup."
fi

sed -i "s/nameserver.*/nameserver $dns_server/" "$resolv_conf"

echo "Updated /etc/resolv.conf:"
cat "$resolv_conf"
