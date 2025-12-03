#!/usr/bin/env bash


# Set text colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Function to print header
print_header() {
    echo "================================================"
    echo "$1"
    echo "================================================"
    echo
}

# Function to display menu
show_intro() {
    clear
    print_header "BigBearCasaOS Database Password Update Tool V0.0.1"

    echo "Here are some links:"
    echo "https://community.bigbeartechworld.com"
    echo "https://github.com/BigBearTechWorld"
    echo ""
    echo "If you would like to support me, please consider buying me a tea:"
    echo "https://ko-fi.com/bigbeartechworld"
    echo ""
    echo "===================="
}

# Show the intro
show_intro

# Set error handling
set -e

# Function to show password change instructions
show_instructions() {
    local container_type=$1
    echo -e "\nInstructions for updating password in docker-compose.yml:"
    echo "1. Look for the service configuration of your database container"
    if [[ $container_type == *"postgres"* ]]; then
        echo "2. Find the POSTGRES_PASSWORD environment variable"
        echo "   Example:"
        echo "   environment:"
        echo "     - POSTGRES_PASSWORD=your_new_password"
    elif [[ $container_type == *"mysql"* ]] || [[ $container_type == *"mariadb"* ]]; then
        echo "2. Find the MYSQL_ROOT_PASSWORD environment variable"
        echo "   Example:"
        echo "   environment:"
        echo "     - MYSQL_ROOT_PASSWORD=your_new_password"
    fi
    echo "3. Replace the old password with: $NEW_PASSWORD"
    echo "4. Save the file and exit the editor"
    echo -e "\nPress Enter to continue to editor..."
    read
}

# edit the docker compose
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

  # Show instructions before editing
  show_instructions "$container_name"

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

# Get list of running containers
containers=$(docker ps --format '{{.Names}}' | grep -E 'postgres|mysql|mariadb')

if [ -z "$containers" ]; then
    echo "No database containers found"
    exit 1
fi

# Display containers
echo -e "\nAvailable database containers:"
select container in $containers; do
    if [ -n "$container" ]; then
        break
    fi
    echo "Invalid selection"
done

# Get new password
read -sp "Enter new password: " NEW_PASSWORD
echo

# Update password based on container type
if [[ $container == *"postgres"* ]]; then
    echo "Updating PostgreSQL password..."
    docker exec -it $container psql -U postgres -c "ALTER USER postgres WITH PASSWORD '$NEW_PASSWORD';"
elif [[ $container == *"mysql"* ]] || [[ $container == *"mariadb"* ]]; then
    echo "Updating MySQL/MariaDB password..."
    docker exec -it $container mysql -u root -pDB_PASSWORD_CHANGEME -e "ALTER USER 'root'@'%' IDENTIFIED BY '$NEW_PASSWORD';"
fi

# Ask if user wants to edit docker-compose file
echo -e "\nWould you like to edit the docker-compose file? (y/n)"
read -r edit_choice

if [[ "$edit_choice" =~ ^[Yy]$ ]]; then
    # Ask the user to choose an editor
    PS3="Select an editor (enter the number): "
    options=("nano" "vim" "quit")
    select EDITOR_CHOICE in "${options[@]}"
    do
        case $EDITOR_CHOICE in
            "nano"|"vim")
                edit_docker_compose "$container" "$EDITOR_CHOICE"
                break
                ;;
            "quit")
                echo "Skipping docker-compose edit"
                break
                ;;
            *)
                echo "Invalid option. Please try again."
                ;;
        esac
    done
fi

echo -e "\nPassword updated successfully for $container"
