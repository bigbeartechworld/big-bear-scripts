#!/usr/bin/env bash

LOG_FILE="pterodactyl_panel_log.txt"
CONTAINER_ID="pterodactyl-panel"

log() {
    local message="$1"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $message" | tee -a $LOG_FILE
}

generate_key() {
    log "Generating key..."
    docker exec -it $CONTAINER_ID php artisan key:generate --force
    log "Key generated successfully."
}

optimize_cache() {
    log "Optimizing Laravel cache..."
    docker exec -it $CONTAINER_ID php artisan optimize
    log "Laravel cache optimized successfully."
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
    prompt_check_login
    create_user
    log "Script finished."
}

main
