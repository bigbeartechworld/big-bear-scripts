# Big Bear Interactive Rsync

## Why?

This script provides an interactive way to select specific files and directories for rsync operations. Instead of syncing entire directories or writing complex rsync commands, you can visually select which items you want to sync.

## Features

- Interactive file/directory selection
- Color-coded interface for better visibility
- Multiple file selection support
- Progress indication during transfer
- Automatic destination directory creation
- Input validation and error handling

## How to use?

1. Make the script executable:

```bash
chmod +x run.sh
```

2. Run the script (optionally with a source directory):

```bash
./run.sh                    # Uses current directory as source
./run.sh /path/to/directory # Uses specified directory as source
```

3. Follow the interactive prompts:
   - Select items by entering their numbers (space-separated)
   - Type 'a' to select all items
   - Type 'q' to quit
   - Enter the destination path when prompted

## Example

```bash
./run.sh ~/Documents
```

## Requirements

- Bash shell
- rsync installed on your system

## One-line Installation

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/bigbeartechworld/big-bear-scripts/master/interactive-rsync/run.sh)"
```
