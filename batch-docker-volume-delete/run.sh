#!/usr/bin/env bash

# Function to list volumes and allow user selection
select_and_remove_volumes() {
    echo "Fetching volumes..."
    # Fetch all volumes and store them in an array, modify this if not using Docker
    mapfile -t volumes < <(docker volume ls -q)

    # Array to store selected volumes
    declare -a selected_volumes

    # Display volumes and handle user selection
    echo "Please select the volumes you want to remove (enter number again to unselect):"
    for i in "${!volumes[@]}"; do
        echo "$((i+1))) ${volumes[i]}"
    done

    while true; do
        echo "Enter selection (or 'done' to finish):"
        read input

        if [[ "$input" == "done" ]]; then
            break
        elif [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 1 ] && [ "$input" -le "${#volumes[@]}" ]; then
            # Calculate array index
            idx=$((input-1))

            # Toggle selection
            if [[ " ${selected_volumes[@]} " =~ " ${volumes[idx]} " ]]; then
                # Remove from list if already selected
                selected_volumes=("${selected_volumes[@]/${volumes[idx]}}")
                echo "Unselected: ${volumes[idx]}"
            else
                # Add to list if not already selected
                selected_volumes+=("${volumes[idx]}")
                echo "Selected: ${volumes[idx]}"
            fi
        else
            echo "Invalid input, please try again."
        fi
    done

    # Confirmation before removal
    if [ ${#selected_volumes[@]} -eq 0 ]; then
        echo "No volumes selected for removal."
    else
        echo "You have selected the following volumes for removal:"
        printf '%s\n' "${selected_volumes[@]}"
        echo "Are you sure you want to remove these volumes? (yes/no)"
        read confirmation

        if [ "$confirmation" == "yes" ]; then
            # Remove the selected volumes
            for volume in "${selected_volumes[@]}"; do
                docker volume rm "$volume"
                echo "Removed: $volume"
            done
        else
            echo "Volume removal cancelled."
        fi
    fi
}

# Main function
main() {
    echo "Multi-Volume Removal Script"
    select_and_remove_volumes
}

# Run the main function
main
