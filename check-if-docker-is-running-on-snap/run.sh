#!/bin/bash

# Check if Docker is installed via Snap
if snap list docker &> /dev/null; then
    echo "Docker is installed via Snap."
else
    echo "Docker is not installed via Snap, or Snap is not installed."
fi
