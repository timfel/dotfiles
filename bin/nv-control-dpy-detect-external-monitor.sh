#!/bin/bash

# Set the display we are looking for here.
# I am interested in a CRT monitor being attached, but this could be TV-0 or something

LAPTOP_DISPLAY="DFP-0"
EXTERNAL_DISPLAY="DFP-1"

function toggle_view {
   NVOUTPUT=`nv-control-dpy --dynamic-twinview`

   if [ $? -gt 0 ] ; then
      nv-control-dpy --probe-dpys | grep $EXTERNAL_DISPLAY > /dev/null 2>&1
      if [ $? -gt 0 ] ; then
	 NOTIFICATION="Could not discover the display '$EXTERNAL_DISPLAY'. "
	 # Get the modeline that has only a single nvidia-auto-select for the laptop
	 modeline=`nv-control-dpy --print-metamodes | grep -m1 -P "$LAPTOP_DISPLAY: nvidia-auto-select[^(nvidia-auto-select)]*$"`
      else
	 # Get the modeline that has only two nvidia-auto-select for the laptop and external display
	 modeline=`nv-control-dpy --print-metamodes | grep -m1 -P "$LAPTOP_DISPLAY: nvidia-auto-select.*, $EXTERNAL_DISPLAY: nvidia-auto-select"`
      fi
      if [[ -z $modeline ]]; then
	 NOTIFICATION="${NOTIFICATION}Could retrieve a valid modeline. "
	 exit 1
      fi
      # The output from nv-control-dpy includes the refresh rate of the new mode.
      # This acts as a kind of unique id for the entry
      REFRESHID=`expr "$modeline" : ".*id=\([0-9]*\)"`
   else
      REFRESHID=`expr "$NVOUTPUT" : ".*id.*is \([0-9]*\);.*"`
   fi


   # Now we have the id, we just need to get the list of available modes from xrandr
   # and extract the new resolution of all of the enabled displays which can be identified alongside the refresh rate 
   MODES=`xrandr 2>&1`
   RESOLUTION=`expr "$MODES" : ".* \([0-9]*x[0-9]*\)[ ]*$REFRESHID.0"`

   # Now activate it!
   notify-send -t 1 "${NOTIFICATION}Switching to $RESOLUTION@$REFRESHID."
   xrandr -s "$RESOLUTION@$REFRESHID"
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

