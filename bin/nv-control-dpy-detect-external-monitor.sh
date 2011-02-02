#!/bin/bash

# Set the display we are looking for here.
# I am interested in a CRT monitor being attached, but this could be TV-0 or something

LAPTOP_DISPLAY="DFP-0"
EXTERNAL_DISPLAY="DFP-1"

function associate_target_bitmask {
   # See if device is currently enabled
   # nv-control-dpy basically returns a list of the associated displays as bitwise values
   # Then outputs a final device mask which indicates which of those displays are being used
   # So if my CRT-0 has a value of 0x00000001 and internal display DFP-0 is 0x00010000
   # then a device mask of 0x00010000 would indicate the CRT is not enabled, but 0x00010001
   # means they're both enabled.
    
   NVOUTPUT=`nv-control-dpy --get-associated-dpys`
   EXTERNAL_DISPLAY_BITMASK=`expr "$NVOUTPUT" : ".*$DISPLAY_TARGET (\(..........\)"`
   DISPLAY_LAPTOP_BITMASK=`expr "$NVOUTPUT" : ".*$LAPTOP_DISPLAY (\(..........\)"`
   DISPLAY_ALLOLD_BITMASK=`expr "$NVOUTPUT" : ".*device mask: \(..........\)"`
   DISPLAY_ALLNEW_BITMASK=$(($DISPLAY_ALLOLD_BITMASK | $EXTERNAL_DISPLAY_BITMASK))
   DISPLAY_NONEW_BITMASK=$(($DISPLAY_LAPTOP_BITMASK))

   if [[ -z $EXTERNAL_DISPLAY_BITMASK ]]; then
      # echo 2>&1 'INFO: Could not discover the display "'$EXTERNAL_DISPLAY'". Switching to single screen ...'
      bitmask=$DISPLAY_NONEW_BITMASK
   else if [ $DISPLAY_ALLNEW_BITMASK = $(($DISPLAY_ALLOLD_BITMASK)) ] ; then
      # echo 2>&1 'INFO: Twin-view already enabled, toggling to single screen ...'
      bitmask=$DISPLAY_NONEW_BITMASK
   else
      bitmask=$DISPLAY_ALLNEW_BITMASK
   fi fi

   nv-control-dpy --set-associated-dpys $bitmask > /dev/null 2>&1

   if [ $? -gt 0 ] ; then
     echo 1>&2 'Error: There was a problem enabling the display'
     exit 1
   fi

   # The way we can enable the screen is to add the display as a metamode and get xrandr to switch to it
   # Any display with a value of 'nvidia-auto-select' means it is part of the mode
   # Any display set to NULL means it is not part of the mode
   # This line needs to be modified for every user's particular needs,
   # especially the coordinates.
   if [ $bitmask == $DISPLAY_ALLNEW_BITMASK ]; then
      echo "$LAPTOP_DISPLAY: nvidia-auto-select +0+0"
   else
      echo "$LAPTOP_DISPLAY: nvidia-auto-select +0+0, $EXTERNAL_DISPLAY: nvidia-auto-select +1280+0"
   fi
}

function toggle_view {
   #metamode_line=$(associate_target_bitmask)
   NVOUTPUT=`nv-control-dpy --dynamic-twinview`

   if [ $? -gt 0 ] ; then
      nv-control-dpy --probe-dpys | grep $EXTERNAL_DISPLAY > /dev/null 2>&1
      if [ $? -gt 0 ] ; then
	 echo 1>&2 'Could not discover the display "'$EXTERNAL_DISPLAY'". Switching to single-screen.'
	 # Get the modeline that has only a single nvidia-auto-select for the laptop
	 modeline=`nv-control-dpy --print-metamodes | grep -m1 -P "$LAPTOP_DISPLAY: nvidia-auto-select[^(nvidia-auto-select)]*$"`
      else
	 # Get the modeline that has only two nvidia-auto-select for the laptop and external display
	 modeline=`nv-control-dpy --print-metamodes | grep -m1 -P "$LAPTOP_DISPLAY: nvidia-auto-select.*, $EXTERNAL_DISPLAY: nvidia-auto-select"`
      fi
      if [[ -z $modeline ]]; then
	 echo 1>&2 'Could retrieve a valid modeline'
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
   echo "Switching to $RESOLUTION@$REFRESHID"
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

