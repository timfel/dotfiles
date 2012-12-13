# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
test "$PS1" || return 0

if [ -n "${TERM#screen*}" ]; then
    $PROF_SCREEN_CMD
fi

if [ "$TERM" == "dumb" ]; then
    unset COLOR_RED
    unset COLOR_RED
    unset COLOR_GREEN
    unset COLOR_YELLOW
    unset COLOR_BLUE
    unset COLOR_MAGENTA
    unset COLOR_CYAN
    unset COLOR_RED_BOLD
    unset COLOR_GREEN_BOLD
    unset COLOR_YELLOW_BOLD
    unset COLOR_BLUE_BOLD
    unset COLOR_MAGENTA_BOLD
    unset COLOR_CYAN_BOLD
    unset COLOR_NONE
else if [ "$TERM" == "xterm" ]; then
    export TERM="xterm-256color"
fi fi

function spwd {
   LENGTH="20"

   SPWD=${PWD#$HOME}
   if [ ${#SPWD} -le ${#PWD} ]; then
      SPWD="~${PWD#$HOME}"
   else
      SPWD=${PWD}
   fi
   if [ ${#SPWD} -gt $(($LENGTH)) ]; then
      export SPWD="${SPWD:0:1}...${SPWD:$((${#SPWD}-$LENGTH+3)):$LENGTH}"
   else
      export SPWD
   fi
}

function prompt {
   # Show last commands exit-code by smiley
   if [ $? = 0 ]; then
      EXITCODE="${COLOR_GREEN_BOLD}✔"
   else
      EXITCODE="${COLOR_RED_BOLD}✘"
   fi
   EXITCODE=$EXITCODE${COLOR_NONE}

   if test -z "$CYGWIN"; then
       # set variable identifying the chroot you work in (used in the prompt below)
       if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
           debian_chroot=$(cat /etc/debian_chroot)
       fi
    
       PS1="${debian_chroot:+($debian_chroot)}"
    
       USER="$(whoami)"
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
          else if [ "$USER" == "timfelgentreff" ]; then
             MACHINE="${MACHINE}➔"
          else if [ "$USER" == "timme" ]; then
             MACHINE="${MACHINE}➔"
          else
             MACHINE="${MACHINE}${USER}@"
          fi fi fi fi fi
          MACHINE="${MACHINE}${HOSTNAME}${COLOR_NONE}:"
       else
          MACHINE=""
       fi
    
       # Have a fancy coloured prompt
       color_prompt=yes
       if [ "$color_prompt" = yes ]; then
           if [ "$USER" = root ]; then
               PS1="${MACHINE}${COLOR_RED_BOLD}\w${COLOR_NONE}"
           else
	       spwd
               PS1="${MACHINE}${COLOR_BLUE_BOLD}${SPWD}${COLOR_NONE}"
           fi
       else
           PS1='${debian_chroot:+($debian_chroot)}$MACHINE:\w '
       fi
       unset color_prompt
    else
       spwd
       PS1="${COLOR_BLUE_BOLD}${SPWD}${COLOR_NONE}"
    fi

   # SHOW RUBY VERSION
   if test -z "$CYGWIN"; then
       if (which rvm-prompt 2>&1 > /dev/null); then
           PS1="$PS1 \$(rvm-prompt u)"
       else
           PS1="$PS1 ${RBENV_VERSION:-system}"
       fi
    else
       PS1="$PS1 ${RBENV_VERSION:-system}"
    fi

   # SHOW VIRTUALENV
   if test -n "$VIRTUALENV"; then
       PS1="$PS1 ⟆${VIRTUAL_ENV#$HOME/.virtualenvs/}"
   fi

   # Show the current branch
   VCS=`echo -e $(__prompt_command)`
   if [ -z "$VCS" ]; then
      EXITCODE=" ${EXITCODE}"
   else
      VCS=" ❰${VCS}❱ "
   fi
   PS1="$PS1$VCS"
   PS1="$PS1$EXITCODE "
}

function rvm_env {
    # rvm-install added line:
    if [[ -n $NORVM ]]; then
        echo "No rvm"
    else
        if [ -n "$LINUX" ]; then
            if [[ -s "$HOME"/.rvm/scripts/rvm ]] ; then
                source "$HOME"/.rvm/scripts/rvm
                rvm use ree
            fi
        else
            echo
         # if [[ -s "/usr/local/lib/rvm" ]] ; then source "/usr/local/lib/rvm" ; fi
        fi
    fi
}

function rbenv_setup {
    if [ ! -e "$HOME/.rbenv" ]; then
        printf "Install rbenv? (Y/n)"
        read answer
        if [ $answer == "y" -o $answer == "Y" ]; then
            git clone https://github.com/sstephenson/rbenv.git "$HOME/.rbenv"
            git clone https://github.com/sstephenson/ruby-build.git "$HOME/.ruby-build"
        else
            touch "$HOME/.rbenv"
        fi
        unset answer
    fi

    if [ -d "$HOME/.rbenv/bin" ]; then
        export PATH="$HOME"/.rbenv/bin:"$HOME"/.rbenv/shims:"$HOME"/.ruby-build/bin:$PATH
        source ~/.rbenv/completions/rbenv.bash
        rbenv rehash

        function use {
            export RBENV_VERSION=$1
        }

        function __use-ruby-completion {
            COMPREPLY=()
            local word="${COMP_WORDS[COMP_CWORD]}"
            COMPREPLY=( $(compgen -W "$(ls ~/.rbenv/versions/)" -- "$word") )
        }

        complete -F __use-ruby-completion use
    fi
}

function system_tweaks {
   if [ -n "$LINUX" ]; then
      function dbus_reload {
        export DBUS_SESSION_BUS_ADDRESS=$(tr '\0' '\n' < /proc/$(pgrep -U $(whoami) gnome-session)/environ|grep ^DBUS_SESSION_BUS_ADDRESS=|cut -d= -f2-)
      }
      alias refresh-dbus=dbus_reload

      if [[ -n "$DISPLAY" ]]; then
         if ( which xcalib 2>&1 > /dev/null ); then
           true 
           # xcalib $HOME/.ColorLCD.icc
         fi
      fi

      # Better desktop responsiveness. See http://www.webupd8.org/2010/11/alternative-to-200-lines-kernel-patch.html
      # if [ "$PS1" ] ; then
      #    mkdir -p -m 0700 /dev/cgroup/cpu/user/$$ # > /dev/null 2>&1
      #    echo $$ > /dev/cgroup/cpu/user/$$/tasks
      #    echo "1" > /dev/cgroup/cpu/user/$$/notify_on_release
      # fi
   else
      function refresh-dbus {
          true
      }
   fi
}

function python_virtualenv_setup {
    # startup virtualenv-burrito
    if [ -f $HOME/.venvburrito/startup.sh ]; then
	export VIRTUALENVWRAPPER_HOOK_DIR=$HOME/.virtualenvs
	export VIRTUALENVWRAPPER_LOG_DIR=$HOME/.virtualenvs
	. $HOME/.venvburrito/startup.sh
    fi
}

function maglev_setup {
    export MAGLEV_HOME="$HOME/.rbenv/versions/maglev"
    if [ -d "$MAGLEV_HOME" ]; then

	function gss {
	    if [ $# -eq 0 ]; then
		echo $GEMSTONE
	    else
		export GEMSTONE=`cd "$1" ; pwd`
	    fi
	}

        function __use-gss-completion {
	    releasevms="$(find $MAGLEV_HOME/../ -maxdepth 1 -executable -name "GemStone-*")"
	    buildvms="$(find $MAGLEV_HOME/../ -mindepth 3 -maxdepth 3 -executable -name "product")"
	    vms="$buildvms $releasevms"

            COMPREPLY=()
            local word="${COMP_WORDS[COMP_CWORD]}"
            COMPREPLY=( $(compgen -W "$vms" -- "$word") )
        }

        complete -F __use-gss-completion gss

        function gemstone {
	    if [ $# -eq 0 ]; then
		echo $MAGLEV_OPTS
	    else
		nostone=`echo "$MAGLEV_OPTS" | sed 's/--stone [^ ]*//'`
		export MAGLEV_OPTS="$nostone --stone $1"
	    fi
        }

        function __use-gemstone-completion {
            COMPREPLY=()
            local word="${COMP_WORDS[COMP_CWORD]}"
            COMPREPLY=( $(compgen -W "$(ls $MAGLEV_HOME/etc/conf.d | sed 's/.conf//')" -- "$word") )
        }

        complete -F __use-gemstone-completion gemstone
    fi
}

system_tweaks
if [ -d "$HOME/.rvm" ]; then
    rvm_env
else
    rbenv_setup
fi
maglev_setup

source "$HOME"/bin/bash_vcs.sh
PROMPT_COMMAND=prompt
