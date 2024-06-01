#!/bin/bash

# Display Welcome
echo "-------------------"
echo "BigBearWebsiteBlocker"
echo "-------------------"
echo "Here is some links"
echo "https://community.bigbeartechworld.com"
echo "https://github.com/BigBearTechWorld"
echo "-------------------"
echo "If you would like to support me, please consider buying me a tea"
echo "https://ko-fi.com/bigbeartechworld"
echo ""

# Load settings from the configuration file
source ./settings.conf

# Function to read entries from the configuration file
read_entries() {
    if [[ -f $CONFIG_FILE ]]; then
        HOSTS_ENTRIES=()
        while IFS= read -r line; do
            [[ $line =~ ^#.*$ || -z $line ]] && continue  # Skip comments and empty lines
            if [[ $line == $DEFAULT_RESOLVER* ]]; then
                HOSTS_ENTRIES+=("$line")
                domain=$(echo "$line" | awk '{print $2}')
            else
                HOSTS_ENTRIES+=("$DEFAULT_RESOLVER $line")
                domain=$line
            fi
            # Add www. prefix if not already present
            if [[ $domain != www.* && $domain != $DEFAULT_RESOLVER* ]]; then
                HOSTS_ENTRIES+=("$DEFAULT_RESOLVER www.$domain")
            fi
        done < "$CONFIG_FILE"
    else
        echo "Configuration file $CONFIG_FILE not found."
        exit 1
    fi
}

# Function to create a backup of the hosts file
backup_hosts_file() {
    BACKUP_FILE="$BACKUP_DIR/hosts_backup_$(date +%s)"
    sudo cp "$HOSTS_FILE" "$BACKUP_FILE"
    echo "Backup of hosts file created at $BACKUP_FILE"
}

# Function to add entries to /etc/hosts
add_entries() {
    {
        echo "$START_MARKER"
        for entry in "${HOSTS_ENTRIES[@]}"; do
            echo "$entry"
        done
        echo "$END_MARKER"
    } | sudo tee -a "$HOSTS_FILE" > /dev/null
    echo "Entries added."
}

# Function to remove entries from /etc/hosts
remove_entries() {
    sudo sed -i.bak "/$START_MARKER/,/$END_MARKER/d" "$HOSTS_FILE"
    echo "Entries removed."
}

# Function to toggle entries
toggle_entries() {
    if grep -q "$START_MARKER" "$HOSTS_FILE"; then
        remove_entries
    else
        backup_hosts_file
        add_entries
    fi
}

# Main function
main() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root"
        exit 1
    fi

    read_entries
    toggle_entries
}

main "$@"
