#!/usr/bin/env bash

# Define PostgreSQL connection parameters
POSTGRES_CONTAINER="immich-postgres"
POSTGRES_DB="immich"
POSTGRES_USER="casaos"
POSTGRES_PASSWORD="casaos"  # Ensure this matches your actual password

# Command to create the extension
CREATE_EXTENSION_COMMAND="CREATE EXTENSION IF NOT EXISTS vectors;"

# Connect to the PostgreSQL container and execute the command
docker exec -it $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d $POSTGRES_DB -c "$CREATE_EXTENSION_COMMAND"
