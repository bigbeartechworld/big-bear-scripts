#!/bin/bash

#########################################################################################
#                                                                                       #
# Script: upgrade immich vectors                                                        #
# ---------------------------------                                                     #
#                                                                                       #
# Description: This script upgrade immich vectors to a new version                      #
# How to Use: ./run.sh -u casaos -p 0.1.11 -n 0.2.0                                     #
#                                                                                       #
# Author: Guilherme Araujo aka Gartisk                                                  #
#         https://github.com/gartisk                                                    #
#                                                                                       #
# Date: 2024-03-16                                                                      #
# Version: 1.0                                                                          #
#                                                                                       #
# Reference: Thanks to Glitch3dPenguin for the solution in the discussion below:        #
# - https://github.com/immich-app/immich/discussions/7310#discussioncomment-8647872     #
#                                                                                       #
#########################################################################################

restartContainers(){
    local containers=("$@")

    for container in "${containers[@]}"
    do
        if docker inspect -f '{{.State.Running}}' $container >/dev/null 2>&1; then
            echo "$container is running, stopping..."
            docker restart $container
            echo "$container has been restarted."
        else
            echo "$container is not running."
        fi
    done
}

waitContainers(){    
    # Wait for containers to start
    local containers=("$@")
    for container in "${containers[@]}"
    do
        while ! docker inspect -f '{{.State.Running}}' $container >/dev/null 2>&1; do
            echo "$container is not running yet, waiting..."
            sleep 5
        done
        echo "$container is running."
    done
}

# INIT HERE
declare -a containers=("immich-machine-learning" "immich-postgres" "immich-server" "immich-microservices" "immich-redis")

# Parse command line arguments
while getopts ":u:p:n:" opt; do
  case $opt in
    u) PSQL_USERNAME="$OPTARG";;
    p) PREVIOUS_VERSION="$OPTARG";;
    n) NEW_VERSION="$OPTARG";;
    \?) echo "Invalid option -$OPTARG" >&2; exit 1;;
    :) echo "Option -$OPTARG requires an argument." >&2; exit 1;;
  esac
done

# Check if required arguments are provided
if [ -z "$PSQL_USERNAME" ] || [ -z "$PREVIOUS_VERSION" ] || [ -z "$NEW_VERSION" ]; then
  echo "Usage: $0 -u <username> -v <previous_version> -V <new_version>" >&2
  exit 1
fi

# Step 1: Log into the Docker container hosting PostgreSQL and Run the SQL commands
docker exec -i immich-postgres psql -U $PSQL_USERNAME -d immich <<EOF
CREATE SCHEMA IF NOT EXISTS vectors;
UPDATE pg_catalog.pg_extension SET extversion = '$PREVIOUS_VERSION' WHERE extname = 'vectors';
UPDATE pg_catalog.pg_extension SET extrelocatable = true WHERE extname = 'vectors';
CREATE EXTENSION vectors;
ALTER EXTENSION vectors SET SCHEMA vectors;
UPDATE pg_catalog.pg_extension SET extrelocatable = false WHERE extname = 'vectors';
ALTER EXTENSION vectors UPDATE TO '$NEW_VERSION';
SELECT pgvectors_upgrade();
\q
EOF

# Step 2: Restart containers
restartContainers "${containers[@]}"
waitContainers "${containers[@]}"

# Step 3: Run the final SQL command
docker exec -i immich-postgres psql -U $PSQL_USERNAME -d immich <<EOF
UPDATE pg_catalog.pg_extension SET extversion = '$NEW_VERSION' WHERE extname = 'vectors';
\q
EOF

echo "Finished"