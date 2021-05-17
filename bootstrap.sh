#!/bin/bash
dir=`readlink -f $(dirname $0)`
ln -sf "$dir"/.bash_profile $HOME/.bash_profile
ln -sf "$dir"/.bashrc $HOME/.bashrc
mkdir $HOME/bin
echo "Just run with it, there'll be some errors, but we just want to get rbenv and install some ruby"
read
source .bashrc

