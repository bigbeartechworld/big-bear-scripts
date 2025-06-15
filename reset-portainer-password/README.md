# Reset Portainer Password

This script helps you easily reset the administrator password for your Portainer instance using the official [Portainer helper-reset-password](https://github.com/portainer/helper-reset-password) container.

## Features

- **Automatic Detection**: Automatically finds your Portainer container and data volume
- **Multiple Deployment Support**: Works with containers, services, and stacks
- **Safe Operation**: Properly stops and restarts Portainer during the reset process
- **Clear Output**: Displays the new password clearly for easy copying
- **Error Handling**: Comprehensive error checking and recovery

## Prerequisites

- Docker must be installed and running
- Portainer must be installed with a persistent data volume
- Root or sudo access may be required

## Usage

Run the script directly from GitHub:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/bigbeartechworld/big-bear-scripts/master/reset-portainer-password/run.sh)"
```

Or with curl:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/bigbeartechworld/big-bear-scripts/master/reset-portainer-password/run.sh)"
```

## What the Script Does

1. **Checks Docker Status**: Verifies Docker is running and accessible
2. **Finds Portainer**: Automatically locates your Portainer container
3. **Detects Data Volume**: Identifies the Portainer data volume
4. **Determines Deployment Type**: Detects if running as container, service, or stack
5. **Stops Portainer**: Safely stops the Portainer instance
6. **Resets Password**: Uses the official Portainer helper to reset the admin password
7. **Restarts Portainer**: Brings Portainer back online
8. **Displays New Password**: Shows the new randomly generated password

## Supported Deployments

- **Standard Container**: `docker run` deployments
- **Docker Services**: `docker service` deployments
- **Docker Stacks**: Stack-based deployments

## Important Notes

- ⚠️ **This will temporarily stop your Portainer instance** during the reset process
- 🔐 **Save the new password immediately** - it's randomly generated and cannot be recovered
- 👤 **Resets the original admin account** (UserID == 1) - if removed, creates a new admin user
- 📝 **Works with persistent volumes only** - bind mounts and named volumes are supported

## Troubleshooting

### Container Not Found

If the script can't find your Portainer container, ensure:

- Portainer is installed and the container exists
- The container name contains "portainer"

### Volume Not Found

If the data volume can't be located:

- Verify Portainer has a persistent data volume mounted to `/data`
- Check that the volume exists with `docker volume ls`

### Permission Errors

If you encounter permission errors:

- Run the script with `sudo`
- Ensure your user is in the `docker` group

## Security

This script uses the official Portainer helper container (`portainer/helper-reset-password`) which:

- Only resets the password for the original administrator account
- Generates a secure random password
- Does not expose or store credentials

## Support

If you find this script helpful, please consider supporting BigBearTechWorld:

- ☕ [Ko-fi](https://ko-fi.com/bigbeartechworld)
- 🐻 [BigBearTechWorld](https://bigbeartechworld.com)

## Related Scripts

- [Update Portainer CE](../update-portainer-ce/) - Update your Portainer installation
- [Install Docker](../install-docker/) - Install Docker on your system
