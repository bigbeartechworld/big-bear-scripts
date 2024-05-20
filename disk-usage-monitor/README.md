## Why?

This is a handy script to monitor disk usage and send an email or Discord message if the usage exceeds a certain threshold (80% by default).

## Parmeters

The script accepts the following parameters:

- `--email=<email address>`: The email address to send the message to. If not provided, the script will prompt the user to enter the email address.
- `--discord=<webhook URL>`: The Discord webhook URL to send the message to. If not provided, the script will prompt the user to enter the webhook URL.
- `--threshold=<percentage>`: The percentage threshold for disk usage. The default value is 80.

## How to use?

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/bigbeartechworld/big-bear-scripts/master/disk-usage-monitor/run.sh)"
```
