#!/bin/bash

# Define the apps directory
APPS_DIR="/var/lib/casaos/apps"

# Function to list all apps
list_apps() {
  echo "Available apps:"
  ls "$APPS_DIR"
}

# Function to edit the docker-compose file with the chosen editor
edit_docker_compose() {
  local service_name=$1
  local editor_choice=$2
  local docker_compose_path="${APPS_DIR}/${service_name}/docker-compose.yml"

  if [[ ! -f "$docker_compose_path" ]]; then
    echo "The docker-compose.yml file does not exist for the service: $service_name"
    exit 1
  fi

  # Open the editor
  if [[ "$editor_choice" == "nano" ]]; then
    nano "$docker_compose_path"
  elif [[ "$editor_choice" == "vim" ]]; then
    vim "$docker_compose_path"
  else
    echo "Invalid editor choice. Please select 'nano' or 'vim'."
    exit 1
  fi

  # Apply the changes using casaos-cli
  casaos-cli app-management apply "$service_name" --file="$docker_compose_path"
}

# Main script starts here
echo "Welcome to the CasaOS App Editor."

# List all apps for the user to choose from
list_apps

# Prompt the user for the app to edit
read -p "Enter the name of the app you want to edit: " SERVICE_NAME

# Check if the service directory exists
if [[ ! -d "${APPS_DIR}/${SERVICE_NAME}" ]]; then
  echo "The selected app does not exist. Please try again."
  exit 1
fi

# Ask the user to choose an editor
echo "Please select an editor:"
echo "1. nano"
echo "2. vim"
read -p "Enter your choice (1 or 2): " EDITOR_CHOICE

case $EDITOR_CHOICE in
  1)
    edit_docker_compose "$SERVICE_NAME" "nano"
    ;;
  2)
    edit_docker_compose "$SERVICE_NAME" "vim"
    ;;
  *)
    echo "Invalid choice. Please enter 1 for nano or 2 for vim."
    exit 1
    ;;
esac

echo "Editing complete."
