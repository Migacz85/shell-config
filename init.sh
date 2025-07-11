#!/bin/bash

# This script is for configuration of fresh bash on Debian

# Here is example how you can run bash script that is held in github repository
# Run script with: 
# git clone --depth 1 https://github.com/Migacz85/shell-config && chmod +x -R shell-config/ && ./shell-config/init.sh

##### Config starts here:

apt install -y ranger &&
apt install -y vim &&
apt install -y xsel &&
apt install -y fzf 

# Create helper file for bash functions and bindings
HELPER_FILE="$HOME/.bash_helpers"
echo "Creating helper file at $HELPER_FILE..."

# Write the function and binding to the helper file
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

# Now, update .bashrc to source the helper file
BASHRC="$HOME/.bashrc"
SOURCE_HELPER_LINE='[ -f ~/.bash_helpers ] && . ~/.bash_helpers'

# Check if the line is already in .bashrc
if ! grep -q "$SOURCE_HELPER_LINE" "$BASHRC"; then
  echo "Adding sourcing of helper file to $BASHRC..."
  echo "" >> "$BASHRC"
  echo "# Source helper functions if they exist" >> "$BASHRC"
  echo "$SOURCE_HELPER_LINE" >> "$BASHRC"
  echo "Done. Please run: source ~/.bashrc to reload your configuration."
else
  echo "Helper file sourcing already present in $BASHRC"
fi

echo "All done, git, ranger, vim and fzf autocompletion is installed. Press ctrl+R to browse history"
