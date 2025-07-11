#!/bin/bash

# Install useful tools
apt install -y ranger vim xsel fzf

# Create helper file path
HELPER_FILE="$HOME/.bash_helpers"

# Only add function if not already present
if grep -q "__fzf_history_search" "$HELPER_FILE" 2>/dev/null; then
  echo "Helper function already present in $HELPER_FILE"
else
  # Create or update helper file
  echo "Updating helper file at $HELPER_FILE..."
  
  # Add function with marker comments
  cat << 'EOF' > "$HELPER_FILE"

# Automatically added function - DO NOT EDIT BELOW THIS LINE
# fzf-based reverse history search
__fzf_history_search() {
  local selected=$(HISTTIMEFORMAT= history | fzf +s --tac | sed 's/ *[0-9]* *//')
  if [ -n "$selected" ]; then
    READLINE_LINE="$selected"
    READLINE_POINT=${#READLINE_LINE}
  fi
}

bind -x '"\C-r": __fzf_history_search'
EOF
fi

# Update .bashrc to source the helper file
BASHRC="$HOME/.bashrc"
SOURCE_HELPER_LINE='[ -f ~/.bash_helpers ] && . ~/.bash_helpers'

# Add sourcing command if not present
if grep -q "$SOURCE_HELPER_LINE" "$BASHRC"; then
  echo "Helper file sourcing already present in $BASHRC"
else
  echo "Adding sourcing of helper file to $BASHRC..."
  echo -e "\n# Source helper functions if they exist\n$SOURCE_HELPER_LINE" >> "$BASHRC"
  echo "Done. Please run: source ~/.bashrc to reload your configuration."
fi

echo "All done! Press ctrl+R to browse history."
