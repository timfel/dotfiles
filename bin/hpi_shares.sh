#!/bin/bash
# fs3 -> lehrveranstaltungen
# fs2 -> studprofile2007$

## Defaults below

action="$1"
smb="fs2"
rdesktop="admin2"
nosmb=0
nordesktop=0
domainuser="tim.felgentreff"
dhcpuser="timfel"

## No edit below this line
smbparam=""
rdesktopparam=""
append=""
directdhcp=0

function usage {
	echo "Usage:"
	echo "hpi_shares.sh (start|stop) [--samba=SAMBA-SERVER] [--rdesktop=RDESKTOP-SERVER] [--no-smb] [--no-rdesktop] [--append=SSH-Option1] --append=[SSH-Option2] ..."
	echo
	echo "start|stop has to come first, others can be arbitary, but only one"
	echo "It will prompt for hpi domain password twice, and for dhcp-server password"
	echo "You have to detach from each screen manually (Usually \"C-a d\")"
	echo "You can append something to the DHCP-tunnel using the --append option"
	echo

	exit 0
}

function parse {
   var=$1
   if test $(echo "$var" | grep '\-\-samba=' ); then
      smb=$(echo "$var" | sed 's/--samba=//g')
   else if test $(echo "$var" | grep '\-\-rdesktop=' ); then
      rdesktop=$(echo "$var" | sed 's/--rdesktop=//g')
   else if test $(echo "$var" | grep '\-\-no\-smb' ); then
      nosmb=1
   else if test $(echo "$var" | grep '\-\-no\-rdesktop' ); then
      nordesktop=1
   else if test $(echo "$var" | grep '\-\-append=' ); then
      append="$append $(echo $var | sed 's/--append=//g')"
   fi
   fi
   fi
   fi
   fi
}

function usesmb {
   if [ $nosmb -eq 0 ]; then
      if test "$(ps -C smbd | grep smbd)"; then
         sudo /etc/init.d/samba stop
      fi
      smbparam="-L 139:$smb:139"
      echo "Starting tunnel to smb://$smb" 
   fi
}

function userdesktop {
   if [ $nordesktop -eq 0 ]; then
      rdesktopparam="-L 3389:$rdesktop:3389"
      echo "Starting tunnel to rdesktop://$rdesktop" 
   fi
}


function start {
   smb=$1
   rdesktop=$2

   usesmb
   userdesktop

      
   if test $(host dhcpserver | grep -o "Host.*:" | awk '{ print $1 }'); then
      # If we haven't got a route to dhcpserver, don't assume we're in HPI      
      if test -z $(screen -ls | grep -o "hpi-tunnel"); then
	 screen -S hpi-tunnel ssh -L 12345:placebo:22 "$domainuser"@ssh-stud.hpi.uni-potsdam.de
      fi
      if test -z $(screen -ls | grep -o "hpi-dhcp"); then
	 screen -S hpi-dhcp ssh -L 12346:dhcpserver:22 -p 12345 "$domainuser"@127.0.0.1
      fi
   else
      directdhcp=1
   fi
   startDhcp
}

function startDhcp {
   if [ $directdhcp -eq 0 ]; then
      if [ $nosmb -ne 1 ]; then
         # have to run this as root, 139 is a protected port
         eval sudo screen -S hpi-fs ssh "$append" "$smbparam" "$rdesktopparam" -p 12346 "$dhcpuser"@127.0.0.1
      else
         eval screen -S hpi-fs ssh "$append" "$rdesktopparam" -p 12346 "$dhcpuser"@127.0.0.1
      fi
   else
      if [ $nosmb -ne 1 ]; then
         # have to run this as root, 139 is a protected port
         eval sudo screen -S hpi-fs ssh "$append" "$smbparam" "$rdesktopparam" "$dhcpuser"@dhcpserver
      else
         eval screen -S hpi-fs ssh "$append" "$rdesktopparam" "$dhcpuser"@dhcpserver
      fi
   fi
}

function stop {
   echo "Stopping all tunnels"

   stopDhcp
   screen -S hpi-dhcp -X kill
   screen -S hpi-tunnel -X kill
}

function stopDhcp {
   screen -S hpi-fs -X kill
   if [ $? -ne 0 ]; then
      sudo screen -S hpi-fs -X kill
   fi
}

if [ $# -eq 0 ]; then
   usage
fi

for i in $@; do
   parse $i;
done

if [ "$action" = "start" ]; then
   if test "$(screen -ls | grep 'hpi')"; then
      echo "Tunnel already active. Replace? (y/n)"
      read answer
      if [ "$answer" = "y" ]; then
	 stopDhcp
      else
	 exit 0
      fi
   fi
   start $smb $rdesktop
else if [ "$action" = "stop" ]; then
      stop
   else
      usage
   fi
fi

