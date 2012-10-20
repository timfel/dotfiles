#!/bin/bash
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
x11vnc -clip xinerama1 -viewonly -wf -wcr always -scr always -nopw -solid -cursor some -ncache -wait_ui 4 -display $DISPLAY
xrandr --output VIRTUAL --off
