# Install Cursor (Cross-Platform Installer)

Easily download and install any version of [Cursor](https://www.cursor.com/) on **macOS**, **Linux**, or **Windows** from the command line.  
This script is part of the [big-bear-scripts](https://github.com/bigbeartechworld/big-bear-scripts) collection.

---

## Features

- **Interactive version picker** – choose any available Cursor version, or install the latest by default.
- **Cross-platform** – supports macOS (Intel & Apple Silicon), Linux (x86_64 & ARM64), and Windows.
- **Security checks** – verifies download sources and (on macOS) checks app signature and notarization.
- **Automatic installation** – handles mounting, copying, and permissions for you.
- **Safe cleanup** – removes temporary files after installation.

---

## Quick Start

Run the installer directly from your terminal:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/bigbeartechworld/big-bear-scripts/master/install-cursor/run.sh)"
```

Or, using `curl`:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/bigbeartechworld/big-bear-scripts/master/install-cursor/run.sh)"
```

---

## Prerequisites

- **curl** (for downloading files)
- **jq** (for parsing JSON)
- **wget** (optional, for the quick start command)
- **macOS only:**
  - `hdiutil`, `codesign`, `spctl`, and `sudo` (for DMG mounting, signature, and notarization checks)

---

## How It Works

1. **Fetches** the latest Cursor version list from the official source.
2. **Prompts** you to pick a version (or defaults to the latest).
3. **Detects** your platform and downloads the correct binary.
4. **Verifies** the download source for safety.
5. **Installs** Cursor:
   - **macOS:** Mounts DMG, verifies signature, installs to `/Applications`.
   - **Linux:** Saves AppImage to `~/Applications/`.
   - **Windows:** Saves installer to `~/Downloads/` (run manually).
6. **Cleans up** all temporary files.

---

## Example Output

```
📥 Fetching version list...
🧭 Available Cursor Versions:
1) Latest (default)
2) 0.22.2
3) 0.22.1
#? 1
🆕 Using latest version: 0.22.2
🔗 Downloading: https://downloads.cursor.com/...
💿 Mounting DMG...
🔍 Verifying app signature...
✅ App is properly signed and verified.
🛡️ Checking notarization status with spctl...
✅ App is notarized and passes Gatekeeper checks.
🔐 Requesting admin rights to install to /Applications...
✅ Installed Cursor 0.22.2 to /Applications
🎉 Done!
```

---

## Security

- **Download host and JSON source are validated** before proceeding.
- **macOS:** App signature and notarization are checked for extra safety.
- **Linux/Windows:** No signature check; always verify the source if you have concerns.

---

## Testing Status

| Platform | Testing Status |
| -------- | -------------- |
| macOS    | Fully Tested   |
| Windows  | Not Tested     |
| Linux    | Not Tested     |

---

## Troubleshooting

- **Missing dependencies?**  
  Install them with:
  - macOS: `brew install jq`
  - Linux: `sudo apt-get install jq`
- **Permission denied?**  
  On macOS, you may be prompted for your password to install to `/Applications`.
- **Unsupported OS or architecture?**  
  The script will exit with a clear error message.

If you encounter any issues, particularly on Windows or Linux, please let us know by opening an issue or visiting the community forum.

---

## License

MIT License

---

## Credits

Script by [BigBearTechWorld](https://github.com/bigbeartechworld) community contributors.
Special thanks to the [oslook/cursor-ai-downloads](https://github.com/oslook/cursor-ai-downloads) repository for providing the Cursor version history data.
Not affiliated with Cursor.

---

## Support

If this script is helpful to you, consider supporting the project on [Ko-fi](https://ko-fi.com/bigbeartechworld)!

---

**Enjoy your new Cursor install!**  
For issues, suggestions, or support, please visit the [BigBearTechWorld Community Forum](https://community.bigbeartechworld.com) or open an issue in the [big-bear-scripts repo](https://github.com/bigbeartechworld/big-bear-scripts/issues).
