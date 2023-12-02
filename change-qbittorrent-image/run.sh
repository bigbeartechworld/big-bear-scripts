#!/bin/bash

# Path to the docker-compose.yml file
COMPOSE_FILE="/var/lib/casaos/apps/qbittorrent/docker-compose.yml"

# Update the docker-compose.yml file
sed -i 's/hotio\/qbittorrent:release-4.6.1/hotio\/qbittorrent:release-4.6.2/' "$COMPOSE_FILE"

# Apply changes using casaos-cli
casaos-cli app-management apply "qbittorrent" --file="$COMPOSE_FILE"

# Wait for the container to reload
echo "Waiting for qBittorrent to restart..."
sleep 10  # Adjust the sleep time if needed

# Extract and echo required information from Docker logs
docker logs qbittorrent 2>&1 | grep -A 5 "******** Information ********" | while read -r line; do
    echo "$line"
done
