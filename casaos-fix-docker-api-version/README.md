# Fix Docker API Version Error for CasaOS

This script fixes common Docker errors with CasaOS including:
- `Error response from daemon: client version 1.43 is too old. Minimum supported API version is 1.44`
- `OCI runtime create failed: runc create failed: unable to start container process: error during container init: open sysctl net.ipv4.ip_unprivileged_port_start file: reopen fd 8: permission denied`
- Docker permission issues and corrupted overlay2 storage
- CVE-2025-52881 AppArmor issues in LXC/Proxmox environments

## The Problem

These errors commonly occur with **CasaOS** when:
1. Docker gets upgraded to a very recent version (API 1.44+) that is incompatible with CasaOS's older Docker client
2. Docker overlay2 filesystem permissions become corrupted
3. Container runtime state becomes inconsistent
4. **NEW**: containerd.io 1.7.28-2 or newer causes AppArmor permission errors in LXC/Proxmox containers

CasaOS uses Docker API 1.43, and when the system Docker gets auto-upgraded or the storage becomes corrupted, it breaks compatibility.

### Special Note for LXC/Proxmox Users

If you're running CasaOS or Docker in an LXC container (common with Proxmox), you may encounter the `permission denied` error after updating containerd. This is caused by **CVE-2025-52881** security patches that conflict with AppArmor profiles in nested containers.

**The error looks like:**
```
failed to create shim task: OCI runtime create failed: runc create failed: 
unable to start container process: error during container init: 
open sysctl net.ipv4.ip_unprivileged_port_start file: reopen fd 8: permission denied
```

This script automatically detects LXC environments and installs **containerd.io 1.7.28-1** (the last version before the breaking change) to prevent this issue.

**References:**
- GitHub Issue: https://github.com/opencontainers/runc/issues/4968
- Proxmox Forum: https://forum.proxmox.com/threads/docker-inside-lxc-net-ipv4-ip_unprivileged_port_start-error.175437/

## What does this script do?

- Detects your operating system (Debian/Ubuntu-based)
- **Detects LXC/Proxmox environment** and adjusts containerd version accordingly
- Checks if CasaOS is installed
- **Checks for and removes Snap Docker installations** that would conflict
- **Verifies Docker binary locations** to ensure no conflicts
- Stops CasaOS services temporarily (if installed)
- Cleans Docker runtime state and fixes permissions
- **Ensures all Docker processes are completely terminated** before upgrade
- Fixes overlay2 directory permissions
- Downgrades Docker to version 24.0.7 (compatible with both CasaOS and modern systems)
- **Verifies the dockerd binary version** after installation
- **Installs containerd.io 1.7.28-1** in LXC/Proxmox to avoid CVE-2025-52881 AppArmor issues
- Configures Docker daemon with proper settings
- Holds Docker packages to prevent automatic upgrades
- Removes standalone docker-compose if present
- Installs Docker Compose plugin
- **Ensures Docker daemon fully restarts with new binaries**
- **Verifies API version actually changed** after installation
- Restarts CasaOS services (if installed)
- **Intelligently detects and fixes** the sysctl permission denied error

## Run command

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/bigbeartechworld/big-bear-scripts/master/casaos-fix-docker-api-version/run.sh)"
```

## Testing the Script

A test script is available to verify the fix script works correctly. See [TEST-SCRIPT-README.md](TEST-SCRIPT-README.md) for details.

```bash
# Download and run the test script
wget https://raw.githubusercontent.com/bigbeartechworld/big-bear-scripts/master/casaos-fix-docker-api-version/test-script.sh
chmod +x test-script.sh

# Run the full test (upgrade Docker, then fix it)
./test-script.sh full

# Or check current status
./test-script.sh status
```

## Can't Resolve Domain

To resolve this issue, please follow these steps:

1. Copy the contents of run.sh from this repository.
2. Create a file named run.sh on your server.
3. Execute the following command on your server:

```bash
bash run.sh
```

## What causes these errors?

These errors occur when:
- Docker gets auto-upgraded to version 25+ or 26+ (API 1.44+)
- CasaOS still uses Docker API 1.43 in older versions
- There's a version mismatch between CasaOS's Docker client and the system's Docker daemon
- System updates automatically upgrade Docker without considering CasaOS compatibility
- Docker overlay2 storage permissions become corrupted
- Container runtime (runc/containerd) state becomes inconsistent
- Improper system shutdowns or Docker crashes leave stale state files
- **containerd.io 1.7.28-2 or newer** in LXC/Proxmox (CVE-2025-52881 AppArmor conflict)

## Requirements

- Debian or Ubuntu-based Linux distribution
- Sudo privileges or root access
- Active internet connection
- CasaOS installed (optional - script works without it too)

## After running the script

You can verify the fix by running:
```bash
docker version
```

Both the client and server API versions should now be compatible. The script installs Docker 24.0.7 which:
- Supports API version 1.43 (compatible with older CasaOS)
- Is stable and well-tested
- Is held at this version to prevent auto-upgrades

### If the API version didn't change

If you ran the script but `docker version` still shows a newer API version (1.45, 1.46, etc.), the script will display diagnostic information. Common causes and fixes:

1. **Docker daemon didn't restart properly**
   ```bash
   sudo systemctl stop docker
   sudo pkill -9 dockerd
   sudo systemctl start docker
   docker version
   ```

2. **Verify the dockerd binary was replaced**
   ```bash
   dockerd --version
   # Should show: Docker version 24.0.7
   ```

3. **Check for multiple Docker installations**
   ```bash
   which -a docker
   which -a dockerd
   # Should only show /usr/bin/docker and /usr/bin/dockerd
   ```

4. **Verify package versions**
   ```bash
   dpkg -l | grep docker-ce
   # Should show version 5:24.0.7-1~...
   ```

If the packages show the correct version (24.0.7) but `docker version` still shows a newer API:
- The dockerd process may not have fully restarted
- Try rebooting your system
- Check for lingering processes: `ps aux | grep dockerd`

## Preventing future issues

The script automatically holds Docker packages to prevent automatic upgrades:
```bash
sudo apt-mark hold docker-ce docker-ce-cli containerd.io
```

**Important for LXC/Proxmox users:** The script holds containerd.io at version 1.7.28-1 to prevent the CVE-2025-52881 AppArmor issue. Do not upgrade containerd until this issue is resolved upstream.

If you want to allow Docker upgrades in the future (after confirming CasaOS compatibility), run:
```bash
sudo apt-mark unhold docker-ce docker-ce-cli containerd.io
```

⚠️ **Warning for LXC users**: Before unholdingcontainerd.io, check if the AppArmor issue has been fixed:
- Check: https://github.com/opencontainers/runc/issues/4968
- Or test in a non-production environment first

## Version Information

- Docker CE: 24.0.7
- Docker API: 1.43 compatible
- containerd.io: 1.7.28-1 (for LXC/Proxmox environments)
- Works with CasaOS 0.4.x series

## Alternative Solutions for LXC/Proxmox (Advanced)

If you prefer not to downgrade containerd, you can modify the LXC container configuration on the Proxmox host:

**Option 1: Disable AppArmor for the container** (in `/etc/pve/lxc/$CTID.conf`):
```
lxc.apparmor.profile: unconfined
lxc.mount.entry: /dev/null sys/module/apparmor/parameters/enabled none bind 0 0
```

**Option 2: Wait for upstream fixes:**
- Proxmox/LXC to update their AppArmor profiles
- containerd/runc to implement workarounds

This script uses the downgrade approach as it's the safest and most reliable solution that doesn't require host-level configuration changes.
