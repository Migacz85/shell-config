#!/bin/bash

# Function to display the script menu
show_menu() {
  echo "======================================"
  echo "Select a script to run:"
  echo "1) init.sh         - Set up fresh Bash environment with essential tools"
  echo "2) fast-sftp.sh    - Configure jailed SFTP access"
  echo "3) wp_info.sh      - Get list of WordPress plugins pending updates"
  echo "4) wplamp.sh       - Manage WordPress LAMP environments"
  echo "5) set-admin.sh    - Configure administrator users"
  echo "6) customers.sh    - Manage customer accounts"
  echo "q) Quit"
  echo "======================================"
}

# Main script logic
while true; do
  show_menu
  read -p "Enter selection: " choice
  
  case $choice in
    1) script_to_run="init.sh"
       description="Setting up Bash environment...";;
    2) script_to_run="fast-sftp.sh"
       description="Configuring jailed SFTP...";;
    3) script_to_run="wp_info.sh"
       description="Checking WordPress updates...";;
    4) script_to_run="wplamp.sh"
       description="Managing WordPress LAMP...";;
    5) script_to_run="set-admin.sh"
       description="Configuring admins...";;
    6) script_to_run="customers.sh"
       description="Managing customers...";;
    q|Q) echo "Exiting."; exit 0;;
    *) echo "Invalid option. Try again."; continue;;
  esac

  if [[ -f "$script_to_run" ]]; then
    echo "$description"
    exec ./"$script_to_run"
    break
  else
    echo "Error: Script $script_to_run not found!"
  fi
done
