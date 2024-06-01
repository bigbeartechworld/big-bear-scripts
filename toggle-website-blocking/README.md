# Run command

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/bigbeartechworld/big-bear-scripts/master/toggle-website-blocking/run.sh)"
```

## About

The distraction free script is designed to help you maintain a distraction-free work environment by blocking access to a specified list of websites. It achieves this by modifying your system's /etc/hosts file, redirecting requests to these websites to 127.0.0.1 (localhost).

### Features:

Toggle Blocking: The script can toggle the blocking of websites on and off. When the script is run, it will add the specified websites to the /etc/hosts file if they are not already present, and remove them if they are.

Automatic Prefix Addition: Users can list websites in a simple format without the need to manually add 127.0.0.1 or www.. The script automatically handles adding these prefixes where necessary.

Comprehensive List: The configuration file, blocked_websites.conf, includes a comprehensive list of popular social media and distraction-prone websites, which can be customized as needed.

Backup Hosts File: Before making any changes, the script creates a backup of the existing /etc/hosts file in a specified backup directory. This ensures you can restore the original file if needed. The backup location is configurable in the settings.conf file.
