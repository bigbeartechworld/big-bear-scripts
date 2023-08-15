#!/bin/bash

# Color variables
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Get the local IP
LOCAL_IP=$(hostname -I | awk '{print $1}')

# Get the subnet
SUBNET=$(ip -o -f inet addr show | awk '/scope global/ {split($4, a, "."); print a[1] "." a[2] "." a[3] ".0"}')

echo -e "${GREEN}Updating package index...${NC}"
sudo apt update

echo -e "\n${GREEN}Installing unbound...${NC}"
sudo apt install unbound -y

echo -e "\n${GREEN}Checking if unbound is enabled to start on boot...${NC}"
sudo systemctl is-enabled unbound

echo -e "\n${GREEN}Checking the status of unbound...${NC}"
sudo systemctl status unbound

echo -e "\n${GREEN}Adding configurations to unbound.conf.d/main.conf...${NC}"

# Header comment
echo "# Adding DNS-Over-TLS support" | sudo tee -a /etc/unbound/unbound.conf.d/main.conf

# Begin server configuration block
echo "server:" | sudo tee -a /etc/unbound/unbound.conf.d/main.conf

# Use syslog for logging
echo "    use-syslog: yes  # Log messages to syslog" | sudo tee -a /etc/unbound/unbound.conf.d/main.conf

# Set the username for the unbound service
echo "    username: \"unbound\"  # Run as the 'unbound' user" | sudo tee -a /etc/unbound/unbound.conf.d/main.conf

# Set the directory for unbound configurations
echo "    directory: \"/etc/unbound\"  # Directory for unbound configurations" | sudo tee -a /etc/unbound/unbound.conf.d/main.conf

# Set the certificate bundle for TLS
echo "    tls-cert-bundle: /etc/ssl/certs/ca-certificates.crt  # Certificate bundle for DNS-over-TLS" | sudo tee -a /etc/unbound/unbound.conf.d/main.conf

# Disable IPv6
echo "    do-ip6: no  # Disable IPv6" | sudo tee -a /etc/unbound/unbound.conf.d/main.conf

# Set the interface to the current local IP
echo "    interface: $LOCAL_IP  # Listen on the current local IP" | sudo tee -a /etc/unbound/unbound.conf.d/main.conf

# Specify the port for DNS queries
echo "    port: 53  # Default DNS port" | sudo tee -a /etc/unbound/unbound.conf.d/main.conf

# Enable prefetching of next DNS record
echo "    prefetch: yes  # Prefetch the next DNS record" | sudo tee -a /etc/unbound/unbound.conf.d/main.conf

# Specify root hints file
echo "    root-hints: /usr/share/dns/root.hints  # Root hints file" | sudo tee -a /etc/unbound/unbound.conf.d/main.conf

# Harden against certain DNSSEC threats
echo "    harden-dnssec-stripped: yes  # Harden against missing DNSSEC data" | sudo tee -a /etc/unbound/unbound.conf.d/main.conf

# Set cache TTL values
echo "    cache-max-ttl: 14400  # Maximum cache time-to-live" | sudo tee -a /etc/unbound/unbound.conf.d/main.conf
echo "    cache-min-ttl: 11000  # Minimum cache time-to-live" | sudo tee -a /etc/unbound/unbound.conf.d/main.conf

# Define private address spaces (not to be forwarded)
echo "    private-address: 192.168.0.0/16  # Private address space" | sudo tee -a /etc/unbound/unbound.conf.d/main.conf
# ... [similar lines for other private addresses]

# Control which clients are allowed to make queries
echo "    # Control which clients are allowed to make (recursive) queries" | sudo tee -a /etc/unbound/unbound.conf.d/main.conf
echo "    access-control: 127.0.0.1/32 allow_snoop  # Allow localhost to snoop" | sudo tee -a /etc/unbound/unbound.conf.d/main.conf
echo "    access-control: ::1 allow_snoop  # Allow IPv6 localhost to snoop" | sudo tee -a /etc/unbound/unbound.conf.d/main.conf
echo "    access-control: 127.0.0.0/8 allow  # Allow entire localhost subnet" | sudo tee -a /etc/unbound/unbound.conf.d/main.conf
echo "    access-control: $SUBNET/24 allow  # Allow current local subnet" | sudo tee -a /etc/unbound/unbound.conf.d/main.conf

# echo -e "\n${GREEN}Updating the sysctl configuration...${NC}"
# echo "net.core.rmem_max=8388608" | sudo tee -a /etc/sysctl.conf

echo -e "\n${GREEN}Applying sysctl changes...${NC}"
sudo sysctl -p

echo -e "\n${GREEN}Allowing OpenSSH and UDP port 53 through UFW...${NC}"
sudo ufw allow OpenSSH
sudo ufw allow 53/udp

echo -e "\n${GREEN}Restarting unbound server...${NC}"
sudo service unbound restart

echo -e "\n${GREEN}Script completed.${NC}"
