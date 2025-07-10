# Debian Bash Configuration Scripts

These scripts configure a Bash environment, set up servers, and manage WordPress installations on Debian systems.

## Available Scripts

- `init.sh` - Set up fresh Bash environment with essential tools
- `fast-sftp.sh` - Configure jailed SFTP access
- `wp_info.sh` - Get list of WordPress plugins pending updates
- `wplamp.sh` - Install LAMP stack with WordPress
- `set-admin.sh` - Add administrator users and create privileged access links
- `customers.sh` - Extract WooCommerce customer data
- `run.sh` - Interactive script selector

## Usage

To run the interactive menu:

```bash
bash <(curl -s https://raw.githubusercontent.com/Migacz85/shell-config/main/run.sh)
```

Select a script number from the menu to run it directly.
