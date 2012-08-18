#!/bin/bash
SCREENCLONE="$HOME/Devel/intel_screenclone/hybrid-screenclone/screenclone"
TMPFILE="/tmp/$(date +%s)_nvidia_clone.sh"

echo "
xset -display :8 s off      # disable screen blanking
xset -display :8 dpms 0 0 0 # disable screen power saving
DISPLAY=:8 xrandr

xrandr
printf 'Choose VIRTUAL monitor resolution: '
read answer

echo '[l]eft'
echo '[r]ight'
echo '[t]op'
echo '[b]ottom'
echo '[c]lone'
printf 'Choose position: '
read position
case \$position in
    l)
	position='--left-of LVDS1'
	;;
    r)
	position='--right-of LVDS1'
	;;
    t)
	position='--above LVDS1'
	;;
    b)
	position='--below LVDS1'
	;;
    c)
	position='--same-as LVDS1'
	;;
    *)
	echo 'Error: invalid position'
	exit 1
esac

xrandr --output LVDS1 --auto --output VIRTUAL --mode \$answer \$position

$SCREENCLONE -d :8 -x 1" > $TMPFILE

chmod +x $TMPFILE
optirun $TMPFILE
xrandr --output VIRTUAL --off
rm $TMPFILE
