#!/bin/bash

# This script is for configuration of fresh bash on Debian

# Here is example how you can run bash script that is held in github repository
# Run script with: 
# git clone --depth 1 https://github.com/Migacz85/shell-config && chmod +x -R shell-config/ && ./shell-config/init.sh

##### Config starts here:

apt update &&
apt upgrade &&

apt install ranger &&
apt install vim &&

git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf &&
~/.fzf/install
source ~/.bashrc

rm -R shell-confi 

echo "All done, git, ranger, vim and fzf autocompletion is installed. Press ctrl+R to browse history"
