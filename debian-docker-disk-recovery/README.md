## Why?

This script helps recover a Debian server when it runs out of disk space, specifically focusing on getting the Docker daemon running again. It takes an interactive, step-by-step approach to free up disk space without destructively removing Docker data.

## Safety First 🛡️

This script is designed to be safe and non-destructive:
- ✅ Preserves all container data
- ✅ Keeps all Docker images intact
- ✅ Maintains running containers
- ✅ Protects active Docker volumes
- ✅ Interactive process (asks before each action)
- ✅ Only cleans logs and temporary files

The script NEVER:
- ❌ Deletes container data
- ❌ Removes running containers
- ❌ Deletes Docker images
- ❌ Removes active Docker volumes
- ❌ Modifies container configurations

## Features

- Interactive cleanup process
- Safe, non-destructive operations
- Step-by-step disk space recovery
- Preserves Docker data while clearing logs
- Shows disk usage after each operation
- Docker cleanup integration (when daemon is running)
- Option to reinstall Docker if needed
- Docker Compose installation option
- Comprehensive cleanup statistics

## Complete Workflow

1. Initial System Cleanup:
   - Clear system journal logs
   - Clean package manager cache
   - Truncate Docker container logs
   - Clean individual container logs

2. If Docker Starts:
   - Option to run comprehensive Docker cleanup
   - Remove unused containers, images, volumes, and networks
   - View cleanup statistics

3. If Issues Persist:
   - Option to reinstall Docker
   - Option to install Docker Compose
   - Clear instructions for next steps

## How to use?

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/bigbeartechworld/big-bear-scripts/master/debian-docker-disk-recovery/run.sh)"
```

The script will guide you through various cleanup options and provide statistics and next steps along the way. Each step requires confirmation before proceeding.
