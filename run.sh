#!/bin/bash

# Base URL for raw GitHub content
BASE_URL="https://raw.githubusercontent.com/Migacz85/shell-config/main"

# Function to display the script menu
show_menu() {
  echo "======================================"
  echo "Select a script to run:"
  echo "1) init.sh         - Set up Bash environment with essential tools"
  echo "2) fast-sftp.sh    - Configure jailed SFTP access"
  echo "3) wp_info.sh      - Get list of WordPress plugins pending updates"
  echo "4) wplamp.sh       - Install lamp with wordpress"
  echo "5) set-admin.sh    - Add additional administrator users + create priv link"
  echo "6) customers.sh    - Extract woocomerce customers"
  echo "q) Quit"
  echo "======================================"
}

# Main script logic
while true; do
  show_menu
  read -p "Enter selection: " choice
  
  case $choice in
    1) script="init.sh";;
    2) script="fast-sftp.sh";;
    3) script="wp_info.sh";;
    4) script="wplamp.sh";;
    5) script="set-admin.sh";;
    6) script="customers.sh";;
    q|Q) echo "Exiting."; exit 0;;
    *) echo "Invalid option. Try again."; continue;;
  esac

  echo "Running $script..."
  bash <(curl -s "$BASE_URL/$script")
  break
done
