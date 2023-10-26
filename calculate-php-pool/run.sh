#!/bin/bash

# Step 1: Find running PHP-FPM processes
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
