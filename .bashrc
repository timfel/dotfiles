# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

#define all colors
COLOR_RED="\e[31;40m"
COLOR_GREEN="\e[32;40m"
COLOR_YELLOW="\e[33;40m"
COLOR_BLUE="\e[34;40m"
COLOR_MAGENTA="\e[35;40m"
COLOR_CYAN="\e[36;40m"
COLOR_RED_BOLD="\e[31;1m"
COLOR_GREEN_BOLD="\e[32;1m"
COLOR_YELLOW_BOLD="\e[33;1m"
COLOR_BLUE_BOLD="\e[34;1m"
COLOR_MAGENTA_BOLD="\e[35;1m"
COLOR_CYAN_BOLD="\e[36;1m"
COLOR_NONE="\e[0m"

function titlebar {
   BAR="\033[41;1m${PWD} - ${COLOR_GREEN_BOLD}$USER@$HOSTNAME${COLOR_NONE}"
   echo -ne "\033[s\033[0;0H"
   COLS=$1
   for i in `seq 1 $RESTLINE`; do
      echo -ne "\033[41;1m "
   done
   echo -ne "\033[0;0H$BAR\033[u"
}

function spwd {
   LENGTH="20"
   HALF="$(($LENGTH/2))"

   SPWD=${PWD#$HOME}
   if [ ${#SPWD} -le ${#PWD} ]; then
      SPWD="~${PWD#$HOME}"
   else
      SPWD=${PWD}
   fi
   if [ ${#PWD} -gt $(($LENGTH)) ]; then
      echo "${SPWD:0:$(($HALF-3))}...${SPWD:$((${#SPWD}-$HALF)):$HALF}"
   else
      echo "$SPWD"
   fi
}

function path {
   export PATH=$PATH:/usr/GNUstep/System/Tools:/usr/local/bin
   export PATH=$HOME/bin/:/var/lib/gems/1.8/bin/:/opt/bin/:/sbin/:$PATH
}

function environment {
   #export DISTCC_POTENTIAL_HOSTS='localhost uerbe9ws01 uerbe9ws02 uerbe9ws03 uerbe9ws04 uerbe9ws05 uerbe9ws06 uerbe9ws07 uerbe9ws08 uerbe9ws09'
   #source /usr/GNUstep/System/Library/Makefiles/GNUstep.sh
   #source /usr/share/GNUstep/Makefiles/GNUstep.sh

   # don't put duplicate lines in the history. See bash(1) for more options
   export HISTCONTROL=ignoredups

   # ... and ignore same sucessive entries.
   export HISTCONTROL=ignoreboth
}

function bash_options {
   # check the window size after each command and, if necessary,
   # update the values of LINES and COLUMNS.
   shopt -s checkwinsize

   # enable programmable completion features (you don't need to enable
   # this, if it's already enabled in /etc/bash.bashrc and /etc/profile
   # sources /etc/bash.bashrc).
   if [ -f /etc/bash_completion ]; then
       . /etc/bash_completion
   fi

   # One-TAB-Completion
   set show-all-if-ambiguous on
}

function prompt {

   # Show last commands exit-code by smiley
   if [ $? = 0 ]; then 
      EXITCODE="${COLOR_GREEN_BOLD}✔"
   else 
      EXITCODE="${COLOR_RED_BOLD}✘"
   fi
   EXITCODE=$EXITCODE${COLOR_NONE}

   # set variable identifying the chroot you work in (used in the prompt below)
   if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
       debian_chroot=$(cat /etc/debian_chroot)
   fi

   PS1="${debian_chroot:+($debian_chroot)}"
   #TIMESTAMP="${COLOR_MAGENTA_BOLD}($(date +%T))${COLOR_NONE}"

   if [ -n "$SSH_TTY" ]; then
      # set user and host
      if [ $USER == "root" ]; then
	 MACHINE="${COLOR_RED_BOLD}"
      else
	 MACHINE="${COLOR_GREEN_BOLD}"
      fi
      if [ "$USER" == "tim" ]; then
	 MACHINE="${MACHINE}➔"
      else if [ "$USER" == "timfel" ]; then
	 MACHINE="${MACHINE}➔"
      else if [ "$USER" == "tim.felgentreff" ]; then
	 MACHINE="${MACHINE}➔"
      else if [ "$USER" == "timme" ]; then
	 MACHINE="${MACHINE}➔"
      else
	 MACHINE="${MACHINE}${USER}@"
      fi fi fi fi
      MACHINE="$MACHINE$HOST${COLOR_NONE}:"
   fi

   # Have a fancy coloured prompt
   color_prompt=yes
   if [ "$color_prompt" = yes ]; then
       if [ $(whoami) = root ]; then 
	   PS1="${PS1}${MACHINE}$TIMESTAMP\[\033[01;34m\]\w\[\033[00m\]"
       else
	   PS1="${PS1}${MACHINE}$TIMESTAMP${COLOR_BLUE_BOLD}\$(spwd)${COLOR_NONE}"
       fi
   else
       PS1='${debian_chroot:+($debian_chroot)}$MACHINE:\w '
   fi
   unset color_prompt 

   # If this is an xterm set the title to user@host:dir
   case "$TERM" in
   xterm*|rxvt*)
       echo -ne "\033]0;${MACHINE}: ${PWD/$HOME/~}\007"
       ;;
   *)
       ;;
   esac

   # Put a nice topbar
   # titlebar $COLUMNS

   # Show the current branch
   source $HOME/bin/bash_vcs.sh
   VCS=`echo -e $(__prompt_command)`
   if [ -z "$VCS" ]; then  
      EXITCODE=" ${EXITCODE}"
   else
      VCS=" ❰$VCS❱ "
   fi
   PS1="$PS1$VCS"
   PS1="$PS1$EXITCODE "
}

function bin_options {
   # make less more friendly for non-text input files, see lesspipe(1)
   [ -x /usr/bin/lesspipe ] && eval "$(lesspipe)"

   # enable color support of ls and also add handy aliases
   if [ "$TERM" != "dumb" ] && [ -x /usr/bin/dircolors ]; then
       eval "`dircolors -b`"
       alias ls='ls --color=auto'
       alias dir='ls --color=auto --format=vertical'
       alias vdir='ls --color=auto --format=long'

       alias grep='grep --color=auto'
       alias fgrep='fgrep --color=auto'
       alias egrep='egrep --color=auto'
   fi

   # some more ls aliases
   alias ll='ls -l'
   alias la='ls -A'
   alias l='ls -CF'
   alias pdflatex='pdflatex -shell-escape'
   alias sudo='sudo -E'
   alias vi='vim'
}

path
environment
bash_options
bin_options
PROMPT_COMMAND=prompt

