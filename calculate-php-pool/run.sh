#!/usr/bin/env bash

# Colors and styling
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Unicode characters
CHECK_MARK='\u2714'
CROSS_MARK='\u2718'
RIGHT_ARROW='\u2192'
INFO_MARK='\u2139'

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}${BOLD}══════ $1 ══════${NC}\n"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}${CHECK_MARK} $1${NC}"
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}${INFO_MARK} $1${NC}"
}

# Function to print error messages
print_error() {
    echo -e "${RED}${CROSS_MARK} $1${NC}"
}

# Display Welcome message with links and support information
print_header "BigBearPHPFPMMemoryAnalyzer V2.0"

echo -e "${BOLD}Community Links:${NC}"
echo -e "${RIGHT_ARROW} https://community.bigbeartechworld.com"
echo -e "${RIGHT_ARROW} https://github.com/BigBearTechWorld"

echo -e "\n${BOLD}Support:${NC}"
echo -e "If you would like to support me, please consider buying me a tea"
echo -e "${RIGHT_ARROW} https://ko-fi.com/bigbeartechworld"

print_header "Analysis Start"

# Function to convert memory from KB to MB
to_mb() {
    echo "scale=2; $1 / 1024" | bc
}

# Function to display memory in MB or GB as appropriate
display_memory() {
    local memory_mb=$1
    if (( $(echo "$memory_mb < 1024" | bc -l) )); then
        printf "%.2f MB" $memory_mb
    else
        printf "%.2f GB" $(echo "scale=2; $memory_mb / 1024" | bc)
    fi
}

print_header "PHP-FPM Memory Analyzer and Optimizer"

# Get total installed RAM in MB and display appropriately
total_ram_mb=$(free -m | awk '/^Mem:/ {print $2}')
total_ram_display=$(display_memory $total_ram_mb)
echo -e "${BOLD}Total RAM:${NC} $total_ram_display"

# Get total memory used by processes other than PHP-FPM
total_used_other_mb=$(ps --no-headers -e -o rss,comm | grep -v php-fpm | awk '{sum+=$1} END {print sum/1024}')
total_used_other_mb=$(LC_NUMERIC=C printf "%.2f" $total_used_other_mb)
echo -e "${BOLD}Memory used by other processes:${NC} $(display_memory $total_used_other_mb)"

# Detect PHP-FPM processes
php_fpm_versions=$(ps -eo comm | grep php-fpm | grep -v grep | sort | uniq)

if [[ -z "$php_fpm_versions" ]]; then
    print_error "No PHP-FPM processes found."
    exit 1
fi

# Allow user to select a version if multiple are found
array=($php_fpm_versions)
if [ ${#array[@]} -gt 1 ]; then
    echo -e "\n${BOLD}Multiple PHP-FPM versions detected. Please select one:${NC}"
    select version in "${array[@]}"; do
        if [[ " ${array[*]} " =~ " ${version} " ]]; then
            php_fpm_version=$version
            break
        else
            print_error "Invalid selection. Please try again."
        fi
    done
else
    php_fpm_version=${array[0]}
fi

print_success "Selected PHP-FPM version: $php_fpm_version"

# Find the PHP-FPM master process and calculate uptime
php_fpm_pid=$(pgrep -f "php-fpm: master process" | head -n 1)
if [[ -n "$php_fpm_pid" ]]; then
    php_fpm_start_time=$(ps -o lstart= -p "$php_fpm_pid")
    php_fpm_uptime=$(($(date +%s) - $(date --date="$php_fpm_start_time" +%s)))
    printf "${BOLD}PHP-FPM master process uptime:${NC} %d days, %02d:%02d:%02d\n" $((php_fpm_uptime/86400)) $((php_fpm_uptime%86400/3600)) $((php_fpm_uptime%3600/60)) $((php_fpm_uptime%60))

    if [[ $php_fpm_uptime -lt 3600 ]]; then
        print_warning "PHP-FPM master process has been up for less than 1 hour. Memory usage estimations might be inaccurate."
    fi
else
    print_warning "Unable to find the PID for PHP-FPM master process. Uptime information unavailable."
fi

# Calculate average memory usage
avg_memory=$(ps --no-headers -o rss -C $php_fpm_version | awk '{sum+=$1; ++n} END {print sum/n/1024}')
echo -e "${BOLD}Average Memory Usage per process:${NC} $(display_memory $avg_memory)"

# Extract PHP version number and read PHP-FPM pool configuration
php_version=$(echo "$php_fpm_version" | sed -E 's/[^0-9]*([0-9]+\.[0-9]+).*/\1/')
pool_config="/etc/php/$php_version/fpm/pool.d/www.conf"

if [[ ! -f "$pool_config" ]]; then
    print_error "Pool configuration file not found at $pool_config"
    exit 1
fi

max_children=$(awk '/^pm.max_children/ {print $3}' "$pool_config")
echo -e "${BOLD}Max children set in pool:${NC} $max_children"

print_header "Memory Requirements"

# Calculate and display total memory requirements
total_memory=$(echo "$avg_memory * $max_children" | bc)
echo -e "${BOLD}Total estimated memory for PHP-FPM:${NC} $(display_memory $total_memory)"

total_estimated_mb=$(echo "scale=2; $total_memory + $total_used_other_mb" | bc)
total_estimated_mb=$(LC_NUMERIC=C printf "%.2f" $total_estimated_mb)
total_estimated_display=$(display_memory $total_estimated_mb)

echo -e "${BOLD}Total estimated memory usage:${NC} $total_estimated_display"

# Check if total estimated memory exceeds total RAM
if (( $(echo "$total_estimated_mb > $total_ram_mb" | bc -l) )); then
    print_warning "Estimated memory usage ($total_estimated_display) exceeds total RAM ($total_ram_display)"
else
    print_success "Server RAM is sufficient. (Total RAM: $total_ram_display, Estimated usage: $total_estimated_display)"
fi

print_header "Optimization Suggestions"

memory_usage_ratio=$(echo "scale=2; $total_estimated_mb / $total_ram_mb" | bc)
if (( $(echo "$memory_usage_ratio > 1" | bc -l) )); then
    print_warning "Reduce 'pm.max_children' in your PHP-FPM pool configuration."
    print_warning "Review and optimize your PHP application to lower memory usage per process."
elif (( $(echo "$memory_usage_ratio > 0.7" | bc -l) )); then
    print_warning "Current settings are close to the server's limit. Consider optimizing to provide more buffer."
else
    print_success "Your current PHP-FPM configuration seems well-optimized for your server's RAM."
fi

# Check pool type and provide specific suggestions
pm_type=$(awk '/^pm\s*=/ {print $3}' "$pool_config")
optimal_max_children=$(echo "$total_ram_mb / $avg_memory * 0.8" | bc)

echo -e "\n${BOLD}Current pool type:${NC} $pm_type"
echo -e "${BOLD}Recommended settings:${NC}"
echo -e "${RIGHT_ARROW} pm.max_children = $optimal_max_children"

if [[ "$pm_type" == "dynamic" ]]; then
    start_servers=$(echo "$optimal_max_children / 4" | bc)
    min_spare_servers=$(echo "$optimal_max_children / 8" | bc)
    max_spare_servers=$(echo "$optimal_max_children / 2" | bc)
    echo -e "${RIGHT_ARROW} pm.start_servers = $start_servers"
    echo -e "${RIGHT_ARROW} pm.min_spare_servers = $min_spare_servers"
    echo -e "${RIGHT_ARROW} pm.max_spare_servers = $max_spare_servers"
elif [[ "$pm_type" == "ondemand" ]]; then
    echo -e "${RIGHT_ARROW} pm.process_idle_timeout = 10s"
fi

echo -e "\n${BOLD}Additional recommendations:${NC}"
echo -e "${RIGHT_ARROW} Regularly monitor performance and adjust settings as needed."
echo -e "${RIGHT_ARROW} Consider implementing PHP opcache and application-level caching."
echo -e "${RIGHT_ARROW} If further optimizations are insufficient, consider upgrading server hardware."

# Prompt user to update configuration
echo
read -p "Do you want to update the PHP-FPM pool configuration with these values? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if sudo cp "$pool_config" "${pool_config}.bak"; then
        print_success "Backup of the configuration file created."

        sudo sed -i "s/^pm.max_children = .*/pm.max_children = $optimal_max_children/" "$pool_config"
        if [[ "$pm_type" == "dynamic" ]]; then
            sudo sed -i "s/^pm.start_servers = .*/pm.start_servers = $start_servers/" "$pool_config"
            sudo sed -i "s/^pm.min_spare_servers = .*/pm.min_spare_servers = $min_spare_servers/" "$pool_config"
            sudo sed -i "s/^pm.max_spare_servers = .*/pm.max_spare_servers = $max_spare_servers/" "$pool_config"
        elif [[ "$pm_type" == "ondemand" ]]; then
            sudo sed -i "s/^pm.process_idle_timeout = .*/pm.process_idle_timeout = 10s/" "$pool_config"
        fi

        print_success "PHP-FPM pool configuration updated successfully."

        echo
        read -p "Do you want to restart the PHP-FPM service now? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if sudo systemctl restart php${php_version}-fpm; then
                print_success "PHP-FPM service restarted successfully."
            else
                print_error "Failed to restart PHP-FPM service. Please restart manually."
            fi
        else
            print_warning "Remember to restart your PHP-FPM service manually for changes to take effect."
        fi
    else
        print_error "Failed to create a backup of the configuration file. No changes were made."
    fi
else
    print_warning "No changes were made to the PHP-FPM pool configuration."
fi

print_header "Analysis Complete"
