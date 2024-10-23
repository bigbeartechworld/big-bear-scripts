#!/usr/bin/env bash

# This script restores the original DNS settings and re-enables systemd-resolved

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

resolv_conf="/etc/resolv.conf"
backup_resolv_conf="/etc/resolv.conf.bak"

# Restore the original resolv.conf from backup if it exists
if [ -f "$backup_resolv_conf" ]; then
    echo "Restoring the original DNS settings from backup..."
    cp "$backup_resolv_conf" "$resolv_conf"
    echo "Restored /etc/resolv.conf:"
    cat "$resolv_conf"
else
    echo "No backup found. Cannot restore the original DNS settings."
    exit 1
fi

# Re-enable and start systemd-resolved if it was disabled
if systemctl is-enabled systemd-resolved.service | grep -q 'disabled'; then
    echo "Re-enabling and starting systemd-resolved..."
    systemctl enable systemd-resolved.service
    systemctl start systemd-resolved.service
else
    echo "systemd-resolved was not disabled by the script, no action needed."
fi

echo "Script reversal complete."
