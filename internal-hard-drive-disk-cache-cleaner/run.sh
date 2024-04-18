#!/bin/bash

MESSAGE="Made by BigBearTechWorld"

# Function to print a decorative line
print_decorative_line() {
    printf "%s\n" "------------------------------------------------------"
}

# Print the introduction message with decorations
echo
print_decorative_line
echo "Big Bear Internal Hard Drive Disk Cache Cleaner"
print_decorative_line
echo
echo "$MESSAGE"
echo
print_decorative_line
echo
echo "If this is useful, please consider supporting my work at: https://ko-fi.com/bigbeartechworld"
echo
print_decorative_line

# Function to clear cache
clear_cache() {
    echo -e "\e[1;32mSynchronizing disks...\e[0m"
    sync  # Ensures that all pending changes are written to disk
    echo -e "\e[1;32mClearing page cache, dentries, and inodes...\e[0m"
    echo 3 > /proc/sys/vm/drop_caches  # Clears the page cache, dentries, and inodes
    echo -e "\e[1;32mCache cleared successfully!\e[0m"
}

# Ask the user for confirmation to proceed
read -p "Do you wish to proceed with clearing the cache? (y/n) " answer
case $answer in
    [Yy]* ) clear_cache;;  # If yes, clear the cache
    [Nn]* ) echo "Operation aborted."; exit;;  # If no, exit the script
    * ) echo "Please answer yes or no."; exit;;  # If invalid response, exit
esac

# End of script
echo -e "\e[1;36mThank you for using the Big Bear Internal HDD Cache Cleaner. Goodbye!\e[0m"
