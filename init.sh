#!/bin/bash

# Install useful tools
apt install -y ranger vim xsel fzf

# Create helper file path
HELPER_FILE="$HOME/.bash_helpers"

# Check if helper file exists and contains function
if [ ! -f "$HELPER_FILE" ] || ! grep -q "__fzf_history_search" "$HELPER_FILE"; then
  echo "Creating helper file at $HELPER_FILE..."
  
  # Write the function and binding to the helper file (preserve existing content)
  if [ -f "$HELPER_FILE" ]; then
    # Append if file exists but doesn't have the function
    cat << 'EOF' >> "$HELPER_FILE"

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
  else
    # Create new file if it doesn't exist
    cat << 'EOF' > "$HELPER_FILE"
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
else
  echo "Helper function already present in $HELPER_FILE"
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
