## Why?

This script helps you update the root/admin password for running database containers (PostgreSQL, MySQL, or MariaDB) and automatically updates the corresponding .env file.

## Features

- Automatically detects running database containers
- Supports PostgreSQL, MySQL, and MariaDB
- Interactive container selection
- Secure password input
- Updates both database password and .env file

## How to use?

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/bigbeartechworld/big-bear-scripts/master/casaos-update-database-password/run.sh)"
```
