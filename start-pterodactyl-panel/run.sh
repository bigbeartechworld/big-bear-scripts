#!/usr/bin/env bash

LOG_FILE="pterodactyl_panel_log.txt"
CONTAINER_ID="pterodactyl-panel"
DB_CONTAINER_ID="big-bear-pterodactyl-panel-database-1"

log() {
    local message="$1"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $message" | tee -a $LOG_FILE
}

generate_key() {
    log "Generating key..."
    if ! docker exec -i $CONTAINER_ID php artisan key:generate --force; then
        log "ERROR: Key generation failed. Aborting."
        exit 1
    fi
    log "Key generated successfully."
}

optimize_cache() {
    log "Optimizing Laravel cache..."
    if ! docker exec -i $CONTAINER_ID php artisan optimize; then
        log "ERROR: Cache optimization failed. Aborting."
        exit 1
    fi
    log "Laravel cache optimized successfully."
}

fix_external_id() {
    log "Fixing external_id column for MariaDB compatibility..."
    if docker exec -i $DB_CONTAINER_ID mysql -u pterodactyl -pcasaos panel -e "ALTER TABLE users MODIFY external_id varchar(191) DEFAULT NULL;" 2>/dev/null; then
        log "external_id column fixed successfully."
    else
        log "WARNING: Could not fix external_id column. User creation may fail."
    fi
}

prompt_check_login() {
    echo "Please check your website URL to see if it shows the login." | tee -a $LOG_FILE
}

create_user() {
    read -p "Do you want to create a user now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Creating a user..."
        docker exec -it $CONTAINER_ID php artisan p:user:make
        log "User created successfully."
    fi
}

main() {
    log "Starting script..."
    generate_key
    optimize_cache
    fix_external_id
    prompt_check_login
    create_user
    log "Script finished."
}

main
