#!/bin/bash

# Display Welcome
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

# Set the current directory
CURRENT_DIR=$(dirname "$0")

# Load settings from the configuration file or create a default one
SETTINGS_FILE="$CURRENT_DIR/settings.conf"
if [[ -f "$SETTINGS_FILE" ]]; then
    source "$SETTINGS_FILE"
else
    cat <<EOL > "$SETTINGS_FILE"
HOSTS_FILE="/etc/hosts"
CONFIG_FILE="$CURRENT_DIR/blocked_websites.conf"
DEFAULT_RESOLVER="127.0.0.1"
START_MARKER="# START blocked_websites by BigBearTechWorld"
END_MARKER="# END blocked_websites by BigBearTechWorld"
BACKUP_DIR="/tmp"
EOL
    source "$SETTINGS_FILE"
    echo "Created default settings.conf file."
fi

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
