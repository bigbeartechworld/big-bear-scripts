#!/bin/bash

# Function to convert memory from KB to MB
to_mb() {
    echo "scale=2; $1 / 1024" | bc
}

# Function to display memory in MB or GB as appropriate
display_memory() {
    local memory_mb=$1
    if (( $(echo "$memory_mb < 1024" | bc -l) )); then
        echo "${memory_mb} MB"
    else
        local memory_gb=$(echo "scale=2; $memory_mb / 1024" | bc)
        echo "${memory_gb} GB"
    fi
}

# Get total installed RAM in MB and display appropriately
total_ram_mb=$(free -m | awk '/^Mem:/ {print $2}')
total_ram_display=$(display_memory $total_ram_mb)

# Get total memory used by processes other than PHP-FPM
total_used_other_mb=$(ps --no-headers -e -o rss,comm | grep -v php-fpm | awk '{sum+=$1} END {print sum}' | xargs -I {} bash -c "echo $(to_mb {})")
total_used_other_mb=$(LC_NUMERIC=C printf "%.2f" $total_used_other_mb)  # Ensure correct formatting

# Detect PHP-FPM processes
php_fpm_versions=$(ps -eo comm | grep php-fpm | grep -v grep | sort | uniq)

if [[ -z "$php_fpm_versions" ]]; then
    echo "No PHP-FPM processes found."
    exit 1
fi

# Step 2: Allow user to select a version if multiple are found
array=($php_fpm_versions)
if [ ${#array[@]} -gt 1 ]; then
    echo "Multiple PHP-FPM versions detected. Please select one:"
    select version in "${array[@]}"; do
        if [[ " ${array[*]} " =~ " ${version} " ]]; then
            php_fpm_version=$version
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
else
    php_fpm_version=${array[0]}
fi

echo "Selected PHP-FPM version: $php_fpm_version"

# Try to find the PHP-FPM master process
php_fpm_pid=$(pgrep -f "php-fpm: master process" | head -n 1)
if [[ -z "$php_fpm_pid" ]]; then
    echo "Unable to find the PID for PHP-FPM master process. Estimations might be inaccurate."
else
    php_fpm_start_time=$(ps -o lstart= -p "$php_fpm_pid")
    php_fpm_up_seconds=$(date --date="$php_fpm_start_time" +%s)
    current_time=$(date +%s)
    php_fpm_uptime=$((current_time - php_fpm_up_seconds))

    # Convert uptime to days, hours, minutes, and seconds
    php_fpm_uptime_days=$((php_fpm_uptime / 86400))
    php_fpm_uptime_hours=$(( (php_fpm_uptime % 86400) / 3600 ))
    php_fpm_uptime_minutes=$(( (php_fpm_uptime % 3600) / 60 ))
    php_fpm_uptime_seconds=$((php_fpm_uptime % 60))

    echo "PHP-FPM master process uptime: $php_fpm_uptime_days days, $php_fpm_uptime_hours hours, $php_fpm_uptime_minutes minutes, $php_fpm_uptime_seconds seconds."

    # Warning if uptime is too short
    if [[ $php_fpm_uptime_hours -lt 1 && $php_fpm_uptime_days -eq 0 ]]; then
        echo "Warning: PHP-FPM master process has been up for less than 1 hour. Memory usage estimations might be inaccurate."
    fi
fi

# Step 3: Calculate average memory usage
avg_memory=$(ps --no-headers -o rss -C $php_fpm_version | awk '{sum+=$1; ++n} END {print sum/n/1024}')

echo "Average Memory Usage per process (MB): $avg_memory"

# Extract PHP version number from the selected PHP-FPM version
php_version=$(echo "$php_fpm_version" | sed -E 's/[^0-9]*([0-9]+\.[0-9]+).*/\1/')

# Step 4: Read PHP-FPM pool configuration (adjust the path to your php-fpm pool config)
pool_config="/etc/php/$php_version/fpm/pool.d/www.conf"  # Example path, change as needed
if [[ -f "$pool_config" ]]; then
    max_children=$(grep "^pm.max_children" $pool_config | cut -d "=" -f2 | xargs)
else
    echo "Pool configuration file not found."
    exit 1
fi

echo "Max children set in pool: $max_children"

# Calculate total memory requirement and display in MB or GB
total_memory=$(echo "$avg_memory * $max_children" | bc)
if (( $(echo "$total_memory < 1024" | bc -l) )); then
    echo "Total estimated memory required for all PHP-FPM processes: $total_memory MB"
else
    total_memory_gb=$(echo "$total_memory / 1024" | bc -l)
    printf "Total estimated memory required for all PHP-FPM processes: %.2f GB\n" $total_memory_gb
fi

# Total estimated memory including PHP-FPM
total_estimated_mb=$(echo "scale=2; $total_memory + $total_used_other_mb" | bc)
total_estimated_mb=$(LC_NUMERIC=C printf "%.2f" $total_estimated_mb)  # Ensure correct formatting
total_estimated_display=$(display_memory $total_estimated_mb)

# Check if total estimated memory exceeds total RAM
if (( $(echo "$total_estimated_mb > $total_ram_mb" | bc -l) )); then
    echo "Warning: Estimated memory usage ($total_estimated_display) exceeds total RAM ($total_ram_display)"
else
    echo "Server RAM is sufficient. Total RAM: $total_ram_display, Estimated usage: $total_estimated_display"
fi

# Optimization Suggestions
echo "Optimization Suggestions:"
if (( $(echo "$total_estimated_mb > $total_ram_mb" | bc -l) )); then
    echo "- Consider reducing 'pm.max_children' in your PHP-FPM pool configuration."
    echo "- Review and optimize your PHP application to lower memory usage per process."
else
    if (( $(echo "$total_estimated_mb / $total_ram_mb > 0.7" | bc -l) )); then
        echo "- While the current settings seem okay, it's close to the server's limit. Consider optimizing to provide more buffer."
    else
        echo "- Your current PHP-FPM configuration seems well-optimized for your server's RAM."
    fi
fi

# Check if the pool is set to static and suggest pm.max_children if necessary
pm_type=$(grep "^pm\s*=" $pool_config | awk '{print $3}')
if [[ "$pm_type" == "static" ]]; then
    optimal_max_children=$(echo "$total_ram_mb / $avg_memory" | bc)
    echo "Your PHP-FPM pool is configured to use a static process manager."
    echo "Based on the available RAM and average memory usage per process:"
    echo "- Optimal 'pm.max_children' could be around $optimal_max_children"
    echo "  (Consider keeping some buffer for the OS and other processes)"
# Suggestion for dynamic and ondemand
elif [[ "$pm_type" == "dynamic" || "$pm_type" == "ondemand" ]]; then
    optimal_max_children=$(echo "$total_ram_mb / $avg_memory" | bc)
    echo "For a 'dynamic' or 'ondemand' PHP-FPM pool configuration, consider the following settings:"
    echo "- pm.max_children: $optimal_max_children (Based on available RAM and average memory usage)"
    if [[ "$pm_type" == "dynamic" ]]; then
        start_servers=$(echo "$optimal_max_children / 4" | bc)  # Example calculation
        min_spare_servers=$(echo "$optimal_max_children / 8" | bc)  # Example calculation
        max_spare_servers=$(echo "$optimal_max_children / 2" | bc)  # Example calculation
        echo "- pm.start_servers: $start_servers"
        echo "- pm.min_spare_servers: $min_spare_servers"
        echo "- pm.max_spare_servers: $max_spare_servers"
    elif [[ "$pm_type" == "ondemand" ]]; then
        process_idle_timeout="10s"  # Example value
        echo "- pm.process_idle_timeout: $process_idle_timeout"
    fi
    echo "Adjust these values based on your application's load and performance testing."
else
    echo "Your PHP-FPM pool is set to an unknown process manager type: $pm_type."
fi

echo "- Regularly monitor performance and adjust settings as needed."
echo "- If further optimizations are not sufficient, upgrading your server's hardware might be necessary."

# Ask the user if they want to update the configuration file
read -p "Do you want to update the PHP-FPM pool configuration with these values? (y/N) " -n 1 -r
echo    # Move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Backup the original configuration file
    if sudo cp "$pool_config" "${pool_config}.bak"; then
        echo "Backup of the configuration file created."

        # Update configuration settings
        if [[ "$pm_type" == "static" ]]; then
            sudo sed -i "s/^pm.max_children = .*/pm.max_children = $optimal_max_children/" "$pool_config"
        elif [[ "$pm_type" == "dynamic" ]]; then
            sudo sed -i "s/^pm.max_children = .*/pm.max_children = $optimal_max_children/" "$pool_config"
            sudo sed -i "s/^pm.start_servers = .*/pm.start_servers = $start_servers/" "$pool_config"
            sudo sed -i "s/^pm.min_spare_servers = .*/pm.min_spare_servers = $min_spare_servers/" "$pool_config"
            sudo sed -i "s/^pm.max_spare_servers = .*/pm.max_spare_servers = $max_spare_servers/" "$pool_config"
        elif [[ "$pm_type" == "ondemand" ]]; then
            sudo sed -i "s/^pm.max_children = .*/pm.max_children = $optimal_max_children/" "$pool_config"
            sudo sed -i "s/^pm.process_idle_timeout = .*/pm.process_idle_timeout = $process_idle_timeout/" "$pool_config"
        fi

        echo "PHP-FPM pool configuration updated successfully."
        echo "Don't forget to restart your PHP-FPM service for these changes to take effect."
    else
        echo "Error: Failed to create a backup of the configuration file. No changes were made."
    fi
else
    echo "No changes were made to the PHP-FPM pool configuration."
fi

# Ask if the user wants to restart PHP-FPM service
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Do you want to restart the PHP-FPM service now? (y/N) " -n 1 -r
    echo    # Move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Attempt to restart PHP-FPM service
        echo "Restarting PHP-FPM service..."
        if sudo systemctl restart php${php_version}-fpm; then
            echo "PHP-FPM service restarted successfully."
        else
            echo "Failed to restart PHP-FPM service. Please restart the service manually."
        fi
    else
        echo "Remember to restart your PHP-FPM service manually for the changes to take effect."
    fi
fi
