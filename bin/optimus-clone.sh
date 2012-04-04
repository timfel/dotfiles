#!/bin/bash
echo "Clone [s]creen or clone [w]indow?"
read answer
if [ "$answer" == "w" ]; then
    WINDOWID=$(xwininfo | grep "Window id:" | grep -oP "(0x[0-9a-f]*)")
    WINDOWID="-i $WINDOWID"
else if [ "$answer" == "s" ]; then
    WINDOWID=""
else
    echo "Please choose [s]creen or [w]indow"
    exit 1
fi fi

TMPFILE="/tmp/$(date +%s)_nvidia_clone.sh"
echo "
xrandr
nvidia-settings -c :8
echo 'Enter resolution for laptop'
read answer
xrandr -s \$answer
xset -display :8 s off # disable screen blanking
xset -display :8 dpms 0 0 0 # disable screen power saving
echo 'Running windump, interrupt with Ctrl+C to stop cloning ...'
windump :0 :8 $WINDOWID" > $TMPFILE

chmod +x $TMPFILE
optirun $TMPFILE
rm $TMPFILE
