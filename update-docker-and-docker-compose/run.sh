#!/usr/bin/env bash

# Function to remove standalone Docker Compose if it exists
remove_standalone_docker_compose() {
  if command -v docker-compose &>/dev/null; then
    echo "docker-compose found. Checking installation method..."

    # Check if docker-compose was installed via apt-get
    if dpkg -l | grep -qw docker-compose; then
      echo "docker-compose was installed via apt-get. Removing..."
      sudo apt-get remove -y docker-compose
    else
      echo "docker-compose was not installed via apt-get. Removing binary..."
      sudo rm $(which docker-compose)
    fi
  else
    echo "docker-compose not found. Skipping removal..."
  fi
}


# Update the system and install Docker if not already installed
update_and_install_docker() {
  echo "Updating system packages..."
  sudo apt-get update

  echo "Installing or Updating Docker..."
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io

  echo "Ensuring Docker starts on boot..."
  sudo systemctl enable docker

  echo "Starting Docker service..."
  sudo systemctl start docker
}

# Main function to orchestrate updates
main() {
  remove_standalone_docker_compose
  update_and_install_docker

  # Verifying the installation
  echo "Verifying Docker and Docker Compose versions..."
  docker --version
  docker compose version
}

# Execute the main function
main
