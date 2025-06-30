[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](../LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/bigbeartechworld/big-bear-scripts)](https://github.com/bigbeartechworld/big-bear-scripts/commits/master)

# 🚀 BigBear Ubuntu/Debian Server Update Script v2.0.0

## 📑 Table of Contents

- [Features](#features)
  - [Core Functionality](#core-functionality)
  - [Safety & Security](#safety--security)
  - [Monitoring & Reporting](#monitoring--reporting)
  - [Configuration Management](#configuration-management)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Command Line Options](#command-line-options)
- [Configuration](#configuration)
- [System Health Checks](#system-health-checks)
- [Security Features](#security-features)
- [Performance & Monitoring](#performance--monitoring)
- [Email Notifications](#email-notifications)
- [Automation & Scheduling](#automation--scheduling)
- [File Locations](#file-locations)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)
- [Support](#support)
- [Version History](#version-history)

## ⚠️ Security Notice

**This script requires root/sudo privileges and performs critical system changes.**

- Review the script before running, especially if downloaded from the internet.
- Only use on trusted systems and environments.
- Ensure you have recent backups before proceeding.
- Use caution when running in unattended or automated modes.

## 🛑 Disclaimer

This script is provided “as is”, without warranty of any kind, express or implied. Big Bear Enterprises, LLC. and contributors are not liable for any damages or data loss resulting from the use of this script. Use at your own risk. Always review scripts and ensure you have backups before running on production systems.

---

A comprehensive, enterprise-grade system update script for Ubuntu and Debian servers with advanced features, health monitoring, configuration management, and automated notifications.

## ✨ Features

### 🎯 Core Functionality

- **Automated Package Management**: Update package lists, upgrade packages, perform full upgrades
- **Intelligent Cleanup**: Remove unnecessary packages and clean package cache
- **Interactive & Unattended Modes**: Run interactively with prompts or silently in automation
- **Visual Progress**: Beautiful UI with colors, progress bars, and Unicode symbols

### 🛡️ Safety & Security

- **System Health Checks**: Monitor disk space, system load, memory usage, and running processes
- **Security Update Detection**: Identify and prioritize security updates
- **Package Exclusion**: Configure packages to exclude from updates
- **Backup Creation**: Optional system backup before major operations
- **Retry Logic**: Automatic retry for failed operations with configurable attempts

### 📊 Monitoring & Reporting

- **Performance Tracking**: Monitor execution time, network usage, and system resources
- **Detailed Statistics**: Track packages upgraded/removed, disk space freed, security updates
- **Enhanced Logging**: Standard and JSON log formats for integration with monitoring tools
- **Email Notifications**: Automated email reports for unattended operations
- **Comprehensive Summary**: Beautiful terminal summary with all operation results

### ⚙️ Configuration Management

- **Configuration File**: Persistent settings for automation preferences
- **Maintenance Windows**: Schedule updates during specific time periods
- **Parallel Downloads**: Support for apt-fast for faster package downloads
- **Command Line Options**: Full control via command-line arguments

## 📋 Prerequisites

- Ubuntu 18.04+ or Debian 9+
- Bash 4.0+
- Root/sudo privileges
- Optional: `bc` for mathematical calculations (auto-installed if missing)
- Optional: `apt-fast` for parallel downloads
- Optional: `mail` or `sendmail` for email notifications

### Automatic Dependency Installation

The script automatically detects and offers to install missing dependencies:

- **bc**: Required for precise load average and memory calculations
- **apt-fast**: Optional for faster parallel package downloads
- **mailutils**: Optional for email notifications

## 🚀 Quick Start

### Basic Usage

```bash
# Download and run the script
curl -sSL https://raw.githubusercontent.com/bigbeartechworld/big-bear-scripts/master/update-ubuntu-or-debian-server/run.sh | bash
```

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/bigbeartechworld/big-bear-scripts.git
cd big-bear-scripts/update-ubuntu-or-debian-server

# Make executable and run
chmod +x run.sh
./run.sh
```

## 🔧 Command Line Options

```bash
./run.sh [OPTIONS]

Options:
  --unattended    Run without user prompts (uses configuration file settings)
  --force         Force update despite health check warnings
  --config        Open configuration file editor
  --help          Show help message and exit
```

### Usage Examples

```bash
# Interactive mode (default)
./run.sh

# Unattended mode for automation
./run.sh --unattended

# Force update despite health warnings
./run.sh --force

# Edit configuration
./run.sh --config

# Unattended with force override
./run.sh --unattended --force
```

## ⚙️ Configuration

The script creates a configuration file at `~/.bigbear-update.conf` on first run.

### Configuration Options

```bash
# Automatic operation settings
auto_update_package_list=true      # Auto-update package lists in unattended mode
auto_upgrade_packages=true         # Auto-upgrade packages in unattended mode
auto_full_upgrade=true             # Auto-perform full upgrade in unattended mode
auto_remove_unnecessary=true       # Auto-remove unnecessary packages in unattended mode
auto_clean_cache=true              # Auto-clean package cache in unattended mode

# Email notifications
enable_email_notifications=false   # Enable email notifications
email_address=""                   # Email address for notifications

# Package management
exclude_packages=""                # Comma-separated list of packages to exclude
parallel_downloads=true            # Use apt-fast if available for parallel downloads

# Safety settings
min_disk_space_percent=20          # Minimum free disk space required (%)
max_load_average=2.0               # Maximum system load average allowed
backup_before_upgrade=false        # Create backup before major operations
retry_count=3                      # Number of retry attempts for failed operations

# Security
check_security_updates=true        # Check and report security updates

# Scheduling
maintenance_window_start="02:00"   # Start of maintenance window (24-hour format)
maintenance_window_end="04:00"     # End of maintenance window (24-hour format)
```

### Configuration Management

```bash
# Edit configuration file
./run.sh --config

# Manual editing
nano ~/.bigbear-update.conf

# View current configuration
cat ~/.bigbear-update.conf
```

## 📊 System Health Checks

The script performs comprehensive health checks before starting updates:

### Health Check Items

- **Disk Space**: Ensures minimum free space (configurable, default 20%)
- **System Load**: Checks current load average (configurable, default 2.0)
- **Memory Usage**: Monitors memory consumption (warns if >90%)
- **Process Conflicts**: Detects running package managers
- **Maintenance Window**: Validates update timing for unattended mode

### Health Check Behavior

- **Interactive Mode**: Prompts user to continue despite warnings
- **Unattended Mode**: Continues with warnings logged, exits on critical issues
- **Force Mode**: Bypasses all health checks (use with caution)

## 🔐 Security Features

### Security Update Detection

- Identifies available security updates
- Prioritizes security patches in reporting
- Integrates with `unattended-upgrades` if available

### Package Management Security

- **Package Exclusion**: Prevent specific packages from being updated
- **Hold Packages**: Automatically hold excluded packages
- **Backup Integration**: Optional system backup before major changes

### Audit Trail

- **Comprehensive Logging**: All operations logged with timestamps
- **JSON Logging**: Machine-readable logs for monitoring integration
- **Email Notifications**: Automated reporting for unattended operations

## 📈 Performance & Monitoring

### Performance Tracking

- **Execution Time**: Total script runtime and per-step timing
- **Resource Monitoring**: Memory and network usage tracking
- **Disk Space Analysis**: Before/after disk usage comparison
- **Package Statistics**: Count of upgraded/removed packages

### Logging System

- **Standard Logs**: Human-readable logs in `/var/log/bigbear/`
- **JSON Logs**: Structured logs for monitoring tools
- **Email Reports**: Automated summaries for unattended runs

### Integration Ready

- **Monitoring Tools**: JSON logs compatible with ELK, Splunk, etc.
- **CRON Integration**: Perfect for scheduled automated updates
- **CI/CD Pipeline**: Suitable for infrastructure automation

## 📧 Email Notifications

Configure email notifications for unattended operations:

### Setup Email Notifications

1. **Install mail client**:

   ```bash
   # Ubuntu/Debian
   sudo apt update && sudo apt install mailutils
   ```

2. **Configure email in script**:

   ```bash
   ./run.sh --config
   # Set enable_email_notifications=true
   # Set email_address="your-email@domain.com"
   ```

3. **Test notification**:
   ```bash
   # Run a test update to verify email delivery
   ./run.sh --unattended
   ```

### Email Content

- **Subject**: Includes hostname and operation status
- **Summary**: Package counts, execution time, disk space freed
- **Status**: Success/failure indication with error details
- **Log Location**: Path to detailed log files

## 🗓️ Automation & Scheduling

### CRON Integration

```bash
# Edit crontab
crontab -e

# Example: Run daily at 2 AM
0 2 * * * /path/to/big-bear-scripts/update-ubuntu-or-debian-server/run.sh --unattended

# Example: Run weekly on Sunday at 3 AM
0 3 * * 0 /path/to/big-bear-scripts/update-ubuntu-or-debian-server/run.sh --unattended

# Example: Run with email on completion
0 2 * * * /path/to/big-bear-scripts/update-ubuntu-or-debian-server/run.sh --unattended 2>&1 | mail -s "Update Report" admin@domain.com
```

### Systemd Timer (Alternative to CRON)

Create systemd service and timer files:

```bash
# Create service file
sudo nano /etc/systemd/system/bigbear-update.service
```

```ini
[Unit]
Description=BigBear System Update
After=network.target

[Service]
Type=oneshot
ExecStart=/path/to/big-bear-scripts/update-ubuntu-or-debian-server/run.sh --unattended
User=root
StandardOutput=journal
StandardError=journal
```

```bash
# Create timer file
sudo nano /etc/systemd/system/bigbear-update.timer
```

```ini
[Unit]
Description=Run BigBear System Update Daily
Requires=bigbear-update.service

[Timer]
OnCalendar=daily
RandomizedDelaySec=30m
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
# Enable and start timer
sudo systemctl enable bigbear-update.timer
sudo systemctl start bigbear-update.timer

# Check status
sudo systemctl status bigbear-update.timer
```

## 📁 File Locations

### Configuration & Logs

```
~/.bigbear-update.conf              # Main configuration file
~/.config/bigbear/                  # Configuration directory
/var/log/bigbear/                   # Log directory (with fallback to ~/.local/log/bigbear/)
/var/log/bigbear/big-bear-update-ubuntu-server.log      # Standard log
/var/log/bigbear/big-bear-update-ubuntu-server.json     # JSON log
```

### Backup Location

```
/var/backups/bigbear-YYYYMMDD-HHMMSS/    # System backups (if enabled)
/tmp/bigbear-backup-location             # Backup location tracker
```

## 🔧 Advanced Usage

### Custom Package Exclusions

```bash
# Edit configuration to exclude specific packages
./run.sh --config

# Add packages to exclude (comma-separated)
exclude_packages="kernel-image,docker-ce,nginx"
```

### Backup Integration

```bash
# Enable backup before upgrades
./run.sh --config

# Set backup_before_upgrade=true
backup_before_upgrade=true
```

### Maintenance Window Scheduling

```bash
# Configure maintenance window for unattended runs
./run.sh --config

# Set maintenance window (24-hour format)
maintenance_window_start="02:00"
maintenance_window_end="04:00"
```

### Parallel Downloads

```bash
# Install apt-fast for parallel downloads
sudo add-apt-repository ppa:apt-fast/stable
sudo apt update && sudo apt install apt-fast

# Enable in configuration
parallel_downloads=true
```

## 🐛 Troubleshooting

### Common Issues

1. **Log Directory Permission Errors**

   ```bash
   # Error: "tee: /root/.local/log/bigbear/...: No such file or directory"
   # Solution: The script will automatically create fallback directories
   # Or manually create the directory:
   mkdir -p ~/.local/log/bigbear
   ```

2. **Missing bc Command**

   ```bash
   # Error: "bc: command not found"
   # Solution: The script will offer to install it automatically
   # Or install manually:
   sudo apt update && sudo apt install bc
   ```

3. **Permission Denied**

   ```bash
   # Ensure script is executable
   chmod +x run.sh

   # Run with sudo if needed
   sudo ./run.sh
   ```

4. **Configuration Not Loading**

   ```bash
   # Check configuration file exists and is readable
   ls -la ~/.bigbear-update.conf

   # Recreate configuration
   rm ~/.bigbear-update.conf
   ./run.sh  # Will create new default config
   ```

5. **Email Notifications Not Working**

   ```bash
   # Test mail system
   echo "Test" | mail -s "Test Subject" your-email@domain.com

   # Install mail client if missing
   sudo apt install mailutils
   ```

6. **Health Check Failures**

   ```bash
   # Check disk space
   df -h /

   # Check system load
   uptime

   # Check memory usage
   free -h

   # Force update despite health issues
   ./run.sh --force
   ```

### Debug Mode

```bash
# Run with verbose output
bash -x ./run.sh

# Check log files for details
tail -f /var/log/bigbear/big-bear-update-ubuntu-server.log
```

### Log Analysis

```bash
# View recent operations
tail -n 50 /var/log/bigbear/big-bear-update-ubuntu-server.log

# Search for errors
grep -i error /var/log/bigbear/big-bear-update-ubuntu-server.log

# View JSON logs for monitoring
jq '.' /var/log/bigbear/big-bear-update-ubuntu-server.json
```

## 🤝 Contributing

We welcome contributions!

### Development Setup

```bash
# Clone repository
git clone https://github.com/bigbeartechworld/big-bear-scripts.git
cd big-bear-scripts/update-ubuntu-or-debian-server

# Create test environment
vagrant up  # If using Vagrant

# Test changes
./run.sh --help
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

## 🌟 Support

- **Documentation**: This README and inline help (`./run.sh --help`)
- **Issues**: [Issues](https://community.bigbeartechworld.com/c/big-bear-scripts/9)
- **Discussions**: [BigBearTechWorld Community](https://community.bigbeartechworld.com)
- **Support the Project**: [Ko-fi](https://ko-fi.com/bigbeartechworld)

## 🔄 Version History

### v2.0.0 (Current)

- ✨ Complete rewrite with enterprise features
- 🛡️ System health monitoring
- ⚙️ Configuration file management
- 📧 Email notifications
- 📊 Performance tracking and statistics
- 🔐 Enhanced security features
- 🎯 Backup and recovery options
- 🚀 Parallel download support
- 📋 Comprehensive logging

### v1.0.0

- 🎯 Basic update functionality
- 💻 Interactive and unattended modes
- 🎨 Enhanced visual interface
- 📝 Basic logging

---

**Made with ❤️ by [BigBearTechWorld](https://ko-fi.com/bigbeartechworld)**

_This script is part of the BigBear Scripts collection - making server management easier, one script at a time!_

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/bigbeartechworld/big-bear-scripts/master/update-ubuntu-or-debian-server/run.sh)"
```
