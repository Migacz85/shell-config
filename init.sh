#!/bin/bash

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

# Ensure helper function exists
helper_path="$HOME/.bash_helpers"

    cat << EOF > "$helper_path"
# fzf-based reverse history search
__fzf_history_search() {
  local selected=\$(HISTTIMEFORMAT= history | fzf +s --tac | sed 's/ *[0-9]* *//')
  if [ -n "\$selected" ]; then
    READLINE_LINE="\$selected"
    READLINE_POINT=\${#READLINE_LINE}
  fi
}

bind -x '"\C-r": __fzf_history_search'

# --- Colors for better output ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'

# --- Utility Functions ---
info() { echo -e "${C_BLUE}INFO:${C_RESET} $1" >&2; }
warn() { echo -e "${C_YELLOW}WARN:${C_RESET} $1" >&2; }
error() { echo -e "${C_RED}ERROR:${C_RESET} $1" >&2; exit 1; }
success() { echo -e "${C_GREEN}SUCCESS:${C_RESET} $1" >&2; }

find_wp_installations() {
  info "Searching for WordPress installations..."
  local search_paths=("/var/www" "/srv/www" "/usr/share/nginx" "$HOME")
  local found_paths
  found_paths=$(find "${search_paths[@]}" -maxdepth 4 -type f -name "wp-settings.php" -printf "%h\n" 2>/dev/null | sort -u)
  if [[ -z "$found_paths" ]]; then
    warn "Standard search failed. Trying 'wp find-installations'..."
    found_paths=$(wp find-installations --skip-packages --quiet 2>/dev/null | awk '{print $2}')
  fi
  echo "$found_paths"
}

EOF
    echo "Created helper file at $helper_path"

echo -e "\033[1;32mAll done! Press Ctrl+R to browse history.\033[0m"
echo "Run: source ~/.bashrc to refresh"
