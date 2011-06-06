#!/bin/bash

homedir=`pwd`
devdir="$HOME/Devel/projects"

if [[ -e "${homedir}/welcome.sh" ]]; then
  source "${homedir}/welcome.sh"
fi

function welcome_sync_projects {
   echo "Pull from all repositories in $pwd"
   for i in *; do
      if [[ -d "$i" ]]; then
	 cd "$i"
	 echo "$i"
	 git pull
	 cd ..
      fi
   done
}

function welcome_update_homebrew {
   echo "Update homebrew and all installed formulae"
   brew update
   for i in $(brew outdated | cut -f1); do
      brew install $i
   done
}

function welcome_sync_rubies {
   echo "Sync rubies from default ruby to current"
   GEMS="$(rvm default gem list | cut -d' ' -f1 | tr '\n' ' ')"
   echo "$GEMS"
   gem install $GEMS --no-ri --no-rdoc
}

function welcome_update_rvm {
   rvm update --head
   rvm reload
}

function welcome_update_gems {
   rvm gem update
}

function usage {
   WELCOME_FUNCTIONS=`declare -F | cut -d" " -f3 | grep "welcome_"`
   echo "Available functions:"; echo
   for i in $WELCOME_FUNCTIONS; do
      WELCOME_HELP=`declare -f | grep -PA2 "^$i ()" | grep -P "^\s*\""`
      SPACELENGTH=`expr "$WELCOME_HELP" : '\s*echo "'`
      WELCOME_HELP="${WELCOME_HELP:$SPACELENGTH}"
      WELCOME_HELP="${WELCOME_HELP%;}"
      WELCOME_HELP="${WELCOME_HELP%\"}"
      if test "" = "$WELCOME_HELP"; then
	 WELCOME_HELP="No help text given"
      fi
      PADDING="                        "
      NAME=${i//welcome_/}
      echo "   $NAME ${PADDING:${#NAME}:${#PADDING}}$WELCOME_HELP"
      unset WELCOME_HELP
   done
   unset WELCOME_FUNCTIONS
   exit
}

function run {
   COLOR_GREEN="\[\033[32;40m\]"
   COLOR_NONE="\[\033[0m\]"
   COMMAND="welcome_$1"

   echo
   echo "${COLOR_GREEN}Running $1${COLOR_NONE}"
   echo

   $COMMAND
}

if [ $# -eq 1 ]; then
   case $1 in
      "-h")
      	 usage ;;
      "--help")
      	 usage ;;
   esac
   run $1
   exit
fi

usage

