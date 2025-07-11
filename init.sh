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

#add ctrl + r for history to shell
BASHRC="$HOME/.bashrc"
FZF_BINDING_FUNCTION="__fzf_history_search"
FZF_BINDING_LINE='bind -x '"'"'\C-r": __fzf_history_search'"'"''

# Check if the function is already in .bashrc
if ! grep -q "$FZF_BINDING_FUNCTION" "$BASHRC"; then
  echo "Adding fzf Ctrl+R binding to $BASHRC..."

  cat << 'EOF' >> "$BASHRC"

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


  echo "Done. Please run: source ~/.bashrc"
else
  echo "fzf Ctrl+R binding already present in $BASHRC"
fi



source ~/.bashrc


echo "All done, git, ranger, vim and fzf autocompletion is installed. Press ctrl+R to browse history"
