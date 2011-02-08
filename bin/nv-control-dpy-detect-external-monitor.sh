#!/bin/bash

# Set the display we are looking for here.
# I am interested in a CRT monitor being attached, but this could be TV-0 or something

LAPTOP_DISPLAY="DFP-0"
EXTERNAL_DISPLAY="DFP-[1|2]"

function toggle_view {
   CURRENT_RESOLUTION=`xrandr 2>&1 | grep -P "[0-9]+\.[0-9]\*" | awk '{print $1}'`
   CURRENT_REFRESHRATE=`xrandr 2>&1 | grep -P "[0-9]+\.[0-9]\*" | awk '{print $2}'`
   nv-control-dpy --dynamic-twinview 2>&1 > /dev/null
   nv-control-dpy --add-metamode "$LAPTOP_DISPLAY: nvidia-auto-select +0+0, $EXTERNAL_DISPLAY: nvidia-auto-select +0+0" > /dev/null 2>&1

   nv-control-dpy --probe-dpys | grep $EXTERNAL_DISPLAY > /dev/null 2>&1
   if [ $? -gt 0 ] ; then
      # Get the modeline that has only a single nvidia-auto-select for the laptop
      NOTIFICATION="Could not discover the display '$EXTERNAL_DISPLAY'. "
      first_display="$LAPTOP_DISPLAY: nvidia-auto-select.*, "
      second_display="$EXTERNAL_DISPLAY: NULL"
   else
      # Get the modeline that has only nvidia-auto-select for the laptop and external display, and doesn't have the currently used id
      first_display="^\s+id=(?!${CURRENT_REFRESHRATE}).*$LAPTOP_DISPLAY: nvidia-auto-select.*, "
      second_display="$EXTERNAL_DISPLAY: nvidia-auto-select"
      modeline=`nv-control-dpy --print-metamodes | grep -m1 -P "''"`
   fi
   grepline="$first_display$second_display"
   modeline=`nv-control-dpy --print-metamodes | grep -m1 -P "$grepline"`
   if [[ -z $modeline ]]; then
      NOTIFICATION="${NOTIFICATION}Could retrieve a valid modeline. "
      exit 1
   fi
   # The output from nv-control-dpy includes the refresh rate of the new mode.
   # This acts as a kind of unique id for the entry
   REFRESHID=`expr "$modeline" : ".*id=\([0-9]*\)"`

   # Now we have the id, we just need to get the list of available modes from xrandr
   # and extract the new resolution of all of the enabled displays which can be identified alongside the refresh rate 
   MODES=`xrandr 2>&1`
   RESOLUTION=`expr "$MODES" : ".* \([0-9]*x[0-9]*\)[ 0-9\.0]*$REFRESHID\.0"`

   # Now activate it!
   notify-send -t 1 "${NOTIFICATION}Switching to $RESOLUTION@$REFRESHID."
   xrandr -r "$REFRESHID" -s "$RESOLUTION" 2>&1 > /dev/null
}

# We need to build the modepool for all displays, if this has not been done already
nv-control-dpy --build-modepool > /dev/null 2>&1
if [ $? -gt 0 ] ; then
  echo 1>&2 'Error: Could not build modepools'
  exit 1
fi

# I have my laptop display (DFP-0) on the left, and I want it to be the 'primary' display
# then CRT, then TV. This way, when I enable the screen, the gnome panel won't jump over to the CRT
# as a new primary monitor
nv-control-dpy --assign-twinview-xinerama-info-order 'DFP-0,DFP-1,CRT,TV' > /dev/null 2>&1

# Now run the code
toggle_view

