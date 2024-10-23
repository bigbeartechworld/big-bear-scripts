#!/usr/bin/env bash

# Define the apps directory
APPS_DIR="/var/lib/casaos/apps"

# Function to list all apps
list_apps() {
  if [ -d "$APPS_DIR" ] && [ "$(ls -A "$APPS_DIR")" ]; then
    apps=($(ls "$APPS_DIR"))
    echo "Available apps:"
    for i in "${!apps[@]}"; do
      echo "$((i+1)). ${apps[i]}"
    done
  else
    echo "No apps found in $APPS_DIR"
    exit 1
  fi
}

# Function to edit the docker-compose file with the chosen editor
edit_docker_compose() {
  local service_name=$1
  local editor_choice=$2
  local docker_compose_path="${APPS_DIR}/${service_name}/docker-compose.yml"

  if [[ ! -f "$docker_compose_path" ]]; then
    echo "Error: The docker-compose.yml file does not exist for the service: $service_name"
    exit 1
  fi

  # Check if the chosen editor is installed
  if ! command -v "$editor_choice" &> /dev/null; then
    echo "Error: $editor_choice is not installed. Please install it or choose another editor."
    exit 1
  fi

  # Open the editor
  "$editor_choice" "$docker_compose_path"

  # Apply the changes using casaos-cli
  if casaos-cli app-management apply "$service_name" --file="$docker_compose_path"; then
    echo "Changes applied successfully."
  else
    echo "Error: Failed to apply changes. Please check the docker-compose file for errors."
    exit 1
  fi
}

# Display Welcome message with links and support information
echo "-------------------"
echo "BigBearCasaOS App Editor V2.0"
echo "-------------------"
echo "Here are some links"
echo "https://community.bigbeartechworld.com"
echo "https://github.com/BigBearTechWorld"
echo "-------------------"
echo "If you would like to support me, please consider buying me a tea"
echo "https://ko-fi.com/bigbeartechworld"
echo ""

# List all apps for the user to choose from
list_apps

# Get the list of apps
apps=($(ls "$APPS_DIR"))

# Prompt the user for the app to edit
while true; do
  echo "Enter the number of the app you want to edit, or 'q' to quit:"
  read -p "> " choice
  if [[ "$choice" == "q" ]]; then
    echo "Exiting the script."
    exit 0
  elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#apps[@]}" ]; then
    SERVICE_NAME="${apps[$((choice-1))]}"
    break
  else
    echo "Invalid selection. Please try again."
  fi
done

# Ask the user to choose an editor
PS3="Select an editor (enter the number): "
options=("nano" "vim" "quit")
select EDITOR_CHOICE in "${options[@]}"
do
  case $EDITOR_CHOICE in
    "nano"|"vim")
      edit_docker_compose "$SERVICE_NAME" "$EDITOR_CHOICE"
      break
      ;;
    "quit")
      echo "Exiting the script."
      exit 0
      ;;
    *)
      echo "Invalid option. Please try again."
      ;;
  esac
done

echo "Editing complete."
