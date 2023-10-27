#!/bin/bash
# This script is for configuration of fresh bash on Debian

apt install git &&
apt install ranger &&
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf &&
~/.fzf/install
source ~/.bashrc

