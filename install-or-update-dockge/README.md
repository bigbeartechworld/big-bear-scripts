## Why?

The script is a Bash script designed to facilitate the installation and management of Dockge, a containerized application. It begins by checking whether Docker CE 20+ or Podman is installed on the system and offers the user the option to install either of these container runtimes if they are not already present. It also checks the operating system version and architecture for compatibility.

If Dockge is not already installed or if the user chooses to update it, the script proceeds to set up Dockge. It creates directories, downloads the necessary configuration file (compose.yaml) from a remote source, and starts Dockge using the installed container runtime. Additionally, if Dockge is already installed, the script offers the user the option to update it by pulling the latest Docker images and restarting the application.

## How to use?

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/bigbeartechworld/big-bear-scripts/master/install-or-update-dockge/run.sh)"
```
