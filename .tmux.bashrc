#!/bin/bash
# export DBUS_SESSION_BUS_ADDRESS=$(tr '\0' '\n' < /proc/$(pgrep -U $(whoami) gnome-session)/environ|grep ^DBUS_SESSION_BUS_ADDRESS=|cut -d= -f2-)
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
   git clone https://github.com/tmux-plugins/tpm $HOME/.tmux/plugins/tpm
fi

