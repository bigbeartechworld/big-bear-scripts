# Big Bear Interactive Rsync

## Why?

This script provides an interactive way to select specific files and directories for rsync operations. Instead of syncing entire directories or writing complex rsync commands, you can visually select which items you want to sync.

## Features

- Interactive file/directory selection with size information
- Color-coded interface for better visibility
- Multiple file selection support
- File/directory size display
- Pattern-based file exclusion (e.g., _.tmp, _.log)
- Transfer confirmation and progress tracking
- Detailed transfer summary with success/failure reporting
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
   - Enter file patterns to exclude (optional)
   - Select items by entering their numbers (space-separated)
   - Type 'a' to select all items
   - Type 'q' to quit
   - Enter the destination path
   - Confirm the transfer

## Example

```bash
./run.sh ~/Documents
```

Example session:

```
1) document.pdf (1.2M)
2) images (2.3G)
3) notes.txt (45K)

Enter file patterns to exclude: *.tmp *.log
Enter numbers to select: 1 3
Selected items: 2
- document.pdf (1.2M)
- notes.txt (45K)

Enter destination: ~/backup
Start transfer? (y/n): y

Transfer Summary:
Successfully transferred: 2/2
```

## Requirements

- Bash shell
- rsync installed on your system

## One-line Installation

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/bigbeartechworld/big-bear-scripts/master/interactive-rsync/run.sh)"
```
