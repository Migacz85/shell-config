#!/bin/bash

# Get latest helper file from repo
download_helper_file() {
    helper_url="https://raw.githubusercontent.com/Migacz85/shell-config/main/.bash_helpers"
    helper_path="$HOME/.bash_helpers"

    echo "Downloading latest bash helpers..."
    if ! curl -fsSL -o "$helper_path" "$helper_url"; then
        echo "ERROR: Failed to download helper file. Manual configuration required"
        exit 1
    fi
    echo "Successfully updated helper file"
}

# Install all tools at once
apt install -y ranger vim xsel fzf

# Update bash configuration to include helper file
trap 'echo "Update cancelled"; exit' SIGINT

echo -e "\n\033[1;36mUpdating bash configuration...\033[0m"

config_line='[ -f ~/.bash_helpers ] && . ~/.bash_helpers'
bashrc_path="$HOME/.bashrc"

# Add helper file source if missing
if ! grep -qF "$config_line" "$bashrc_path"; then
    echo -e "\n# Source helper functions if they exist\n$config_line" >> "$bashrc_path"
    echo "Added helper source to $bashrc_path"
fi

# Always replace with latest helper file
get_helper_file

echo -e "\033[1;32mAll done! Press Ctrl+R to browse history.\033[0m"
echo "Run: source ~/.bashrc to refresh"
