#!/bin/bash

# This script runs a Docker command to retrieve the traccar.xml configuration file
# from a specified traccar Docker image tag and save it to a specified location on the host's system.

# Explanation of Docker flags:
# --rm: Automatically remove the container when it exits
# --entrypoint cat: Override the default entrypoint of the image to use 'cat'

# Ask the user which Docker tag to use.
echo "Which Docker tag would you like to use? (Default: latest)"
read docker_tag

# If no tag is provided, default to "latest".
if [ -z "$docker_tag" ]; then
    docker_tag="latest"
fi

# Inform the user about the chosen tag.
echo "Using Docker tag: $docker_tag"

# Ask the user where to save the configuration on the host.
echo "Where would you like to save the traccar.xml on the host? (Default: /DATA/AppData/big-bear-traccar/traccar.xml)"
read host_path

# If no path is provided, default to /DATA/AppData/big-bear-traccar/traccar.xml.
if [ -z "$host_path" ]; then
    host_path="/DATA/AppData/big-bear-traccar/traccar.xml"
fi

# Extract the directory part from the provided path
host_dir=$(dirname "$host_path")

# Create the directory if it does not exist
mkdir -p "$host_dir"

# If the directory exists, ask the user if they want to remove it.
# Otherwise, exit without removing the directory.
if [ -d "$host_path" ]; then
    echo "Error: $host_path is a directory."
    echo "Do you want to remove this directory? (yes/no)"
    read remove_decision

    if [ "$remove_decision" == "yes" ]; then
        rm -r "$host_path"
        if [ $? -ne 0 ]; then
            echo "Failed to remove the directory. Exiting."
            exit 1
        fi
    else
        echo "Exiting without removing the directory."
        exit 1
    fi
fi

# Inform the user about the chosen path.
echo "Saving traccar.xml to $host_path"

# Run the Docker command and save the configuration to the specified path.
docker run \
  --rm \
  --entrypoint cat \
  traccar/traccar:$docker_tag \
  /opt/traccar/conf/traccar.xml > "$host_path"
