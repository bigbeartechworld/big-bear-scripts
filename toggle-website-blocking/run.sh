#!/usr/bin/env bash

# Display Welcome message with links and support information
echo "-------------------"
echo "BigBearWebsiteBlocker"
echo "-------------------"
echo "Here are some links"
echo "https://community.bigbeartechworld.com"
echo "https://github.com/BigBearTechWorld"
echo "-------------------"
echo "If you would like to support me, please consider buying me a tea"
echo "https://ko-fi.com/bigbeartechworld"
echo ""

# Set the current directory where the script is located
CURRENT_DIR=$(dirname "$0")

# Load settings from the configuration file or create a default one if it doesn't exist
SETTINGS_FILE="$CURRENT_DIR/settings.conf"
if [[ -f "$SETTINGS_FILE" ]]; then
    # Load existing settings.conf file
    source "$SETTINGS_FILE"
else
    # Create a default settings.conf file if it doesn't exist
    cat <<EOL > "$SETTINGS_FILE"
HOSTS_FILE="/etc/hosts"
CONFIG_FILE="$CURRENT_DIR/blocked_websites.conf"
DEFAULT_RESOLVER="127.0.0.1"
START_MARKER="# START blocked_websites by BigBearTechWorld"
END_MARKER="# END blocked_websites by BigBearTechWorld"
BACKUP_DIR="/tmp"
EOL
    # Load the newly created settings.conf file
    source "$SETTINGS_FILE"
    echo "Created default settings.conf file."
fi

# Ensure CONFIG_FILE uses the correct path
CONFIG_FILE="$CURRENT_DIR/$(basename $CONFIG_FILE)"

# Create a default blocked_websites.conf file if it doesn't exist
if [[ ! -f "$CONFIG_FILE" ]]; then
    cat <<EOL > "$CONFIG_FILE"
x.com
twitter.com
instagram.com
facebook.com
linkedin.com
snapchat.com
tiktok.com
reddit.com
pinterest.com
tumblr.com
flickr.com
quora.com
wechat.com
wechatapp.com
vk.com
ok.ru
viber.com
line.me
telegram.org
whatsapp.com
youtube.com
news.ycombinator.com
nytimes.com
discord.com
discordapp.com
discord.gg
twitch.tv
EOL
    echo "Created default blocked_websites.conf file."
fi

# Function to read entries from the configuration file
read_entries() {
    if [[ -f $CONFIG_FILE ]]; then
        HOSTS_ENTRIES=()  # Initialize an empty array to store host entries
        while IFS= read -r line; do  # Read each line from the configuration file
            [[ $line =~ ^#.*$ || -z $line ]] && continue  # Skip comments and empty lines
            if [[ $line == $DEFAULT_RESOLVER* ]]; then
                HOSTS_ENTRIES+=("$line")  # If line starts with the default resolver, add it directly
                domain=$(echo "$line" | awk '{print $2}')  # Extract the domain name
            else
                HOSTS_ENTRIES+=("$DEFAULT_RESOLVER $line")  # Prepend the default resolver
                domain=$line  # Set the domain to the current line
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
    BACKUP_FILE="$BACKUP_DIR/hosts_backup_$(date +%s)"  # Set the backup file name with a timestamp
    sudo cp "$HOSTS_FILE" "$BACKUP_FILE"  # Copy the current hosts file to the backup location
    echo "Backup of hosts file created at $BACKUP_FILE"  # Inform the user about the backup location
}

# Function to add entries to /etc/hosts
add_entries() {
    {
        echo "$START_MARKER"  # Add the start marker
        for entry in "${HOSTS_ENTRIES[@]}"; do  # Iterate over each entry
            echo "$entry"  # Add each entry
        done
        echo "$END_MARKER"  # Add the end marker
    } | sudo tee -a "$HOSTS_FILE" > /dev/null  # Append entries to the hosts file
    echo "Entries added."  # Inform the user that entries have been added
}

# Function to remove entries from /etc/hosts
remove_entries() {
    sudo sed -i.bak "/$START_MARKER/,/$END_MARKER/d" "$HOSTS_FILE"  # Remove entries between the markers
    echo "Entries removed."  # Inform the user that entries have been removed
}

# Function to toggle entries in /etc/hosts
toggle_entries() {
    if grep -q "$START_MARKER" "$HOSTS_FILE"; then
        remove_entries  # If entries are present, remove them
    else
        backup_hosts_file  # Create a backup before adding entries
        add_entries  # Add entries to the hosts file
    fi
}

# Main function to execute the script
main() {
    if [[ $EUID -ne 0 ]]; then  # Check if the script is run as root
        echo "This script must be run as root"
        exit 1
    fi

    read_entries  # Read entries from the configuration file
    toggle_entries  # Toggle the entries in the hosts file
}

main "$@"
