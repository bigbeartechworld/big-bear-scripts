#!/bin/bash

CONFIG_PATH="/DATA/AppData/frigate/config/config.yml"

# Ensure the directory exists
mkdir -p $(dirname $CONFIG_PATH)

# Write the content to config.yml
cat > $CONFIG_PATH <<EOL
mqtt:
  host: mqtt.server.com
cameras:
  back:
    ffmpeg:
      inputs:
        - path: rtsp://viewer:change_password@10.0.10.10:554/cam/realmonitor?channel=1&subtype=2
          roles:
            - detect
    detect:
      width: 1280
      height: 720
EOL

echo "Configuration written to $CONFIG_PATH"
