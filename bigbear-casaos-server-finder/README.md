# BigBearCasaOS Server Finder

## Table of Contents
- [BigBearCasaOS Server Finder](#bigbearcasaos-server-finder)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Features](#features)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
    - [Quick Install](#quick-install)
    - [Manual Installation](#manual-installation)
  - [Usage](#usage)
  - [How It Works](#how-it-works)
  - [Troubleshooting](#troubleshooting)
    - [Common Issues](#common-issues)
  - [Example Output](#example-output)
    - [Successful Scan](#successful-scan)
    - [No Servers Found](#no-servers-found)
  - [Notes](#notes)

## Overview

This shell script helps you discover CasaOS servers on your local network. It scans for open web ports and checks for the presence of CasaOS on those ports.

## Features

- Automatically detects available subnets on your network
- Scans common web server ports (80, 8080, 8888, etc.)
- Identifies CasaOS instances by checking for the CasaOS signature
- Provides a clean, interactive interface with progress indicators
- Parallel processing for faster scanning
- Detailed logging for troubleshooting

## Prerequisites

- Linux system (Debian/Ubuntu recommended)
- `nmap` and `iproute2` packages installed
- Run with sufficient privileges to perform network scans
- Internet access for initial script download

## Installation

### Quick Install
```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/bigbeartechworld/big-bear-scripts/master/bigbear-casaos-server-finder/run.sh)"
```

### Manual Installation
1. Install required packages:
```bash
sudo apt-get update
sudo apt-get install nmap iproute2
```

2. Download the script:
```bash
wget https://raw.githubusercontent.com/bigbeartechworld/big-bear-scripts/master/bigbear-casaos-server-finder/run.sh
chmod +x run.sh
```

## Usage

Run the script with:
```bash
./run.sh
```

The script will:
1. Detect available networks
2. Prompt you to select a network to scan
3. Scan for open ports
4. Check each found service for CasaOS signature
5. Display results

## How It Works

1. The script first detects all available subnets on your system using `ip` command
2. You can choose to scan all networks or select a specific one
3. It performs a port scan on common web server ports using `nmap`
4. For each open port found, it checks for the CasaOS signature using `curl`
5. Displays all found CasaOS servers with their IP addresses and ports

## Troubleshooting

### Common Issues
1. **Missing dependencies**:
   ```bash
   sudo apt-get install nmap iproute2
   ```

2. **Permission denied**:
   Run the script with elevated privileges:
   ```bash
   sudo ./run.sh
   ```

3. **No networks found**:
   - Ensure your network interfaces are up
   - Check your network configuration with `ip addr`

4. **Slow scanning**:
   - Select a specific network instead of scanning all
   - Reduce the number of ports scanned by editing the `PORTS_TO_SCAN` variable in the script

## Example Output

### Successful Scan
```
Discovering available networks...
Found networks: 192.168.1.0/24 192.168.2.0/24
Do you want to select a specific network to scan? (Faster) (y/N): y
Available networks:
[1] 192.168.1.0/24
[2] 192.168.2.0/24
Select network to scan [1-2]: 1
Scanning network: 192.168.1.0/24
Scanning for open ports (80,81,8080,8888,8000,8001,8008,8081,8880,3000,5000,5050)...
Checking for CasaOS servers...
Found CasaOS server at: 192.168.1.100:8080
Found CasaOS server at: 192.168.1.150:8888
Scan complete!
```

### No Servers Found
```
Discovering available networks...
Found networks: 192.168.1.0/24
Do you want to select a specific network to scan? (Faster) (y/N): n
Scanning all discovered networks...
Scanning for open ports (80,81,8080,8888,8000,8001,8008,8081,8880,3000,5000,5050)...
Checking for CasaOS servers...
No CasaOS servers found.
Scan complete!
```

## Notes

- Network scanning may take some time depending on your network size
- Ensure your network allows port scanning
- The script only scans your local network(s)
- Results are logged to `/tmp/bigbear-casaos-server-finder.log` for debugging
