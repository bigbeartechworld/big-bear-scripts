#!/bin/bash

# Path where nextcloud directories are located
APP_DIR="/var/lib/casaos/apps"

# Find directories containing 'nextcloud' in their names
echo "Searching for Nextcloud directories in $APP_DIR..."
NEXTCLOUD_DIRS=($(find "$APP_DIR" -maxdepth 1 -type d -name "*nextcloud*" -exec basename {} \;))

# Check if any directories were found
if [ ${#NEXTCLOUD_DIRS[@]} -eq 0 ]; then
    echo "No Nextcloud directories found in $APP_DIR."
    exit 1
fi

# Allow user to pick a directory
echo "Please select a Nextcloud directory:"
select NEXTCLOUD_DIR in "${NEXTCLOUD_DIRS[@]}"; do
    [ -n "$NEXTCLOUD_DIR" ] && break
    echo "Invalid selection. Please try again."
done

# Default path for the PHP-FPM configuration
DEFAULT_PHP_FPM_CONF_PATH="$APP_DIR/$NEXTCLOUD_DIR/php-fpm.d/zz-pm.conf"

# Allow user to provide a custom path or use the default
read -p "Enter the PHP-FPM configuration file path or press enter to use default [$DEFAULT_PHP_FPM_CONF_PATH]: " PHP_FPM_CONF_PATH
PHP_FPM_CONF_PATH=${PHP_FPM_CONF_PATH:-$DEFAULT_PHP_FPM_CONF_PATH}

# Creating the PHP-FPM configuration file
echo "Creating PHP-FPM configuration at $PHP_FPM_CONF_PATH"
mkdir -p "$(dirname "$PHP_FPM_CONF_PATH")"
cat <<EOF > "$PHP_FPM_CONF_PATH"
[www]
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
EOF

# Check if Docker Compose file exists
DOCKER_COMPOSE_FILE="$APP_DIR/$NEXTCLOUD_DIR/docker-compose.yml"
echo "Checking if Docker Compose file exists at $DOCKER_COMPOSE_FILE"
if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
    echo "Docker Compose file not found at $DOCKER_COMPOSE_FILE"
    exit 1
fi

# Add the new volume to the 'nextcloud' service in the Docker Compose file
echo "Adding new volume to the 'nextcloud' service in the Docker Compose file"
sed -i '/nextcloud:/,/volumes:/!b;/volumes:/a \            - type: bind\n              source: '"$PHP_FPM_CONF_PATH"'\n              target: /usr/local/etc/php-fpm.d/zz-pm.conf' "$DOCKER_COMPOSE_FILE"

# Apply changes using casaos-cli
casaos-cli app-management apply "$NEXTCLOUD_DIR" --file="$DOCKER_COMPOSE_FILE"
echo "Applying changes to $NEXTCLOUD_DIR..."

echo "Script execution completed."
