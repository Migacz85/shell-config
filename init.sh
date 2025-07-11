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
if ! grep -q "__fzf_history_search" "$helper_path" 2>/dev/null; then
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
EOF
    echo "Created helper file at $helper_path"
fi

echo -e "\033[1;32mAll done! Press Ctrl+R to browse history.\033[0m"
echo "Run: source ~/.bashrc to refresh"
