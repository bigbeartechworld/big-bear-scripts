# Setup Pterodactyl Wings

This script helps set up the network configuration and directories required for Pterodactyl Wings. It handles network conflict resolution, proper directory permissions, and container management automatically.

## Prerequisites

- Docker installed and running
- Root/sudo access
- wget installed

## Usage

You can run the script directly using wget:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/bigbeartechworld/big-bear-scripts/master/setup-pterodactyl-wings/run.sh)" -- <uuid>
```

Replace `<uuid>` with your server's UUID from the Pterodactyl panel.

Example:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/bigbeartechworld/big-bear-scripts/master/setup-pterodactyl-wings/run.sh)" -- 123e4567-e89b-12d3-a456-426614174000
```

## What the Script Does

1. Creates required Pterodactyl directories with proper permissions
2. Sets up Docker network `pterodactyl_nw` with proper IPv4/IPv6 configuration
3. Automatically resolves network conflicts:
   - Detects conflicting Docker networks
   - Removes unused conflicting networks
   - Provides clear instructions if manual intervention is needed
4. Restarts the pterodactyl-wings container to apply changes

## Network Configuration

The script automatically creates a Docker network with the following specifications:

- Network name: `pterodactyl_nw`
- IPv4 subnet: Automatically selected from available ranges (172.40-47.0.0/16)
- IPv4 gateway: Automatically configured based on selected subnet
- IPv6 subnet: fd00::/64
- IPv6 gateway: fd00::1
- Bridge name: pterodactyl0

The script intelligently:
1. Checks existing Docker networks and system routes for conflicts
2. Automatically selects an available subnet from a predefined list of private ranges
3. Reconfigures the network if conflicts are detected
4. Provides clear status messages during the setup process

## Troubleshooting

If you encounter issues, the script will provide clear error messages and instructions:

1. Network Configuration Issues:
   - The script will automatically try different subnet ranges
   - Clear messages show which subnet is being used
   - Detailed error messages if network creation fails

2. Container Restart Issues:
   - If the pterodactyl-wings container fails to restart, you'll get instructions for manual restart
   - Use `docker restart pterodactyl-wings` if needed

Common error messages and solutions:

- "Could not find available subnet": All predefined subnets are in use, contact support
- "Failed to create network": Check Docker logs and ensure Docker is running properly
- "Failed to restart pterodactyl-wings container": Ensure the container exists and try restarting manually

## Support

For issues or questions, please open an issue on [BigBearCommunity](https://community.bigbeartechworld.com/).
