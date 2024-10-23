#!/usr/bin/env bash

# Default values
EMAIL=""
DISCORD_WEBHOOK=""
THRESHOLD=80

# Parse arguments
for ARG in "$@"
do
  case $ARG in
    --email=*)
      EMAIL="${ARG#*=}"
      ;;
    --discord=*)
      DISCORD_WEBHOOK="${ARG#*=}"
      ;;
    --threshold=*)
      THRESHOLD="${ARG#*=}"
      ;;
    *)
      # Unknown option
      ;;
  esac
done

# Prompt for email if not set
if [ -z "$EMAIL" ]; then
  read -p "Please enter your email address (or press Enter to skip): " EMAIL
fi

# Prompt for Discord webhook if not set
if [ -z "$DISCORD_WEBHOOK" ]; then
  read -p "Please enter your Discord webhook URL (or press Enter to skip): " DISCORD_WEBHOOK
fi

# Get disk usage
DISK_USAGE=$(df -h / | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{ print $5 }')
USAGE=$(echo $DISK_USAGE | sed 's/%//g')

# Display current disk usage
echo "Current disk usage is $DISK_USAGE."

# Check if usage exceeds threshold
if [ $USAGE -ge $THRESHOLD ]; then
    MESSAGE="Disk usage is at $DISK_USAGE - Time to clean up!"

    # Send email if an email address is provided
    if [ -n "$EMAIL" ]; then
        echo "$MESSAGE" | mail -s "Disk Usage Alert" "$EMAIL"
    fi

    # Send message to Discord webhook if a webhook URL is provided
    if [ -n "$DISCORD_WEBHOOK" ]; then
        curl -H "Content-Type: application/json" \
            -X POST \
            -d "{\"content\": \"$MESSAGE\"}" \
            "$DISCORD_WEBHOOK"
    fi
else
  MESSAGE="Disk usage is within acceptable limits."
fi

# Display the message
echo "$MESSAGE"
