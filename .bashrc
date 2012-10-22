# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
if [[ -n $PS1 ]]; then

# Start tmux
if [[ $TERM != screen* ]]; then
    if which tmux 2>&1 >/dev/null; then
        # if no session is started, start a new session
	test -z ${TMUX} && (tmux attach || tmux new-session)
    fi
fi

#define all colors
if [ $(uname) != "SunOS" ] && [ "$TERM" != "dumb" ]; then
   COLOR_RED="\[\033[31;40m\]"
   COLOR_GREEN="\[\033[32;40m\]"
   COLOR_YELLOW="\[\033[33;40m\]"
   COLOR_BLUE="\[\033[34;40m\]"
   COLOR_MAGENTA="\[\033[35;40m\]"
   COLOR_CYAN="\[\033[36;40m\]"
   COLOR_RED_BOLD="\[\033[31;1m\]"
   COLOR_GREEN_BOLD="\[\033[32;1m\]"
   COLOR_YELLOW_BOLD="\[\033[33;1m\]"
   COLOR_BLUE_BOLD="\[\033[34;1m\]"
   COLOR_MAGENTA_BOLD="\[\033[35;1m\]"
   COLOR_CYAN_BOLD="\[\033[36;1m\]"
   COLOR_NONE="\[\033[0m\]"
   if [ "$TERM" == "xterm" ]; then
      export TERM="xterm-256color"
   fi
fi

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

   SPWD=${PWD#$HOME}
   if [ ${#SPWD} -le ${#PWD} ]; then
      SPWD="~${PWD#$HOME}"
   else
      SPWD=${PWD}
   fi
   if [ ${#SPWD} -gt $(($LENGTH)) ]; then
      echo "${SPWD:0:1}...${SPWD:$((${#SPWD}-$LENGTH+3)):$LENGTH}"
   else
      echo "$SPWD"
   fi
}

function path {
   export PATH=$PATH:/usr/GNUstep/System/Tools:/usr/local/bin:/usr/local/sbin:/usr/local/share/npm/bin
   export PATH="$HOME"/bin/:/var/lib/gems/1.8/bin/:/opt/bin/:/sbin/:$PATH
   if [ $(uname) == "SunOS" ]; then
      export PATH=/opt/csw/bin:/opt/sfw/bin:$PATH
   fi
   if [[ -e "$HOME/Devel/projects/git-hg/bin" ]]; then
      export PATH=$PATH:$HOME/Devel/projects/git-hg/bin
   fi
   if [[ -e "$HOME/homebrew/bin" ]]; then
      export PATH=$HOME/homebrew/bin:$PATH
   fi
}

function environment {
   #export DISTCC_POTENTIAL_HOSTS='localhost uerbe9ws01 uerbe9ws02 uerbe9ws03 uerbe9ws04 uerbe9ws05 uerbe9ws06 uerbe9ws07 uerbe9ws08 uerbe9ws09'
   #source /usr/GNUstep/System/Library/Makefiles/GNUstep.sh
   #source /usr/share/GNUstep/Makefiles/GNUstep.sh

   # don't put duplicate lines in the history. See bash(1) for more options
   export HISTCONTROL=ignoredups

   # ... and ignore same sucessive entries.
   export HISTCONTROL=ignoreboth

   export BIBINPUTS=".:~/texmf/bibliography/:~/Dropbox/Papers/:$BIBINPUTS"

   # export RUBYOPT="rubygems"
   # export MAGLEV_OPTS="-rubygems"

   export EMACS="emacsclient -f ${HOME}/.emacs.d/server/server -c"
   export EDITOR="$EMACS"
   export ALTERNATE_EDITOR=""
   alias vi=$EDITOR
   alias em="$EMACS -n"

   if [ -n $TMUX ]; then
       refresh-dbus
   fi
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

   USER=$(whoami)
   if [ -z $HOSTNAME ]; then
      export HOSTNAME=`hostname -s`
   fi
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
       if [ $(whoami) = root ]; then
           PS1="${MACHINE}${COLOR_RED_BOLD}\w${COLOR_NONE}"
       else
           PS1="${MACHINE}${COLOR_BLUE_BOLD}\$(spwd)${COLOR_NONE}"
       fi
   else
       PS1='${debian_chroot:+($debian_chroot)}$MACHINE:\w '
   fi
   unset color_prompt

   # SHOW RUBY VERSION
   if (which rvm-prompt 2>&1 > /dev/null); then
       PS1="$PS1 \$(rvm-prompt u)"
   else
       if (which rbenv 2>&1 > /dev/null); then
           PS1="$PS1 \$(rbenv version-name)"
       fi
   fi

   # SHOW VIRTUALENV
   if test -n "$VIRTUALENV"; then
       PS1="$PS1 ⟆${VIRTUAL_ENV#$HOME/.virtualenvs/}"
   fi

   # Show the current branch
   source "$HOME"/bin/bash_vcs.sh
   VCS=`echo -e $(__prompt_command)`
   if [ -z "$VCS" ]; then
      EXITCODE=" ${EXITCODE}"
   else
      VCS=" ❰${VCS}❱ "
   fi
   PS1="$PS1$VCS"
   PS1="$PS1$EXITCODE "

   # Finally, see if there's a timEnv file and source it, if we haven't already
   if [ -e timEnv ]; then
       if [[ ! "$ACTIVE_TIM_ENVS" =~ .*:"$pwd".* ]]; then
          echo "Sourcing timEnv"
          export ACTIVE_TIM_ENVS="$ACTIVE_TIM_ENVS:$(pwd)"
          source timEnv
       fi
   fi
}

function bin_options {
   # make less more friendly for non-text input files, see lesspipe(1)
   [ -x /usr/bin/lesspipe ] && eval "$(lesspipe)"

   # enable color support of ls and also add handy aliases
   if [ $(uname) != "SunOS" ] && [ "$TERM" != "dumb" ]; then
       if [ -x /usr/bin/dircolors ]; then
           eval "`dircolors -b`"
       fi
       if [ -e ~/.dircolors ]; then
           eval "`dircolors ~/.dircolors`"
       fi
       if [ $(uname) != "Darwin" ]; then
          alias ls='ls --color=auto'
          alias dir='ls --color=auto --format=vertical'
          alias vdir='ls --color=auto --format=long'

          alias grep='grep --color=auto'
          alias fgrep='fgrep --color=auto'
          alias egrep='egrep --color=auto'
       else
          alias ls='ls -G'
          alias dir='ls -G'
          alias vdir='ls -G -l'

          alias grep='grep --color=auto'
          alias fgrep='fgrep --color=auto'
          alias egrep='egrep --color=auto'
       fi
   fi

   # some more ls aliases
   alias ll='ls -l'
   alias la='ls -A'
   alias l='ls -CF'
   alias pdflatex='pdflatex -shell-escape'
   alias sudo='sudo -E'
   # alias vi='RUBYOPTS="$RUBYOPTS -W0" vim'
   alias sshx='ssh -X -C -c blowfish-cbc'
   alias gitpp="git pull && git push"
   alias sc="env RAILSCONSOLE=1 script/console"
   alias ss="script/server"
   alias rb_uses="grep -h -o 'rb_[^ )(,]*' *.cpp *.c *.h | grep -v 'rb_.*\.[hc]' | sort | uniq"

   # Git aliases
   alias gitss="git submodule init && git submodule sync && git submodule update"
   alias gitcp="git cherry-pick"
   alias gitrb="git rebase -i"
   alias gitap="git add --patch"
   alias gitciam="git commit --amend -m"
   alias gitcim="git commit -m"

   # RVM shortcuts
   alias rvm_isolate="rvm gemset create \$(basename \`pwd\`); echo 'rvm gemset use \$(basename \`pwd\`)' >> .rvmrc; cd ../\$(basename \`pwd\`)"

   # Work shortcuts
   alias swa_hiwi="cd ~/Documents/HPI/SWA-HiWi"
   alias maglevh="source ~/bin/maglev-head"
   alias jrubyh="source ~/bin/jruby-head"

   alias dia="dia --integrated"
}

function rvm_env {
    # rvm-install added line:
    if [[ -n $NORVM ]]; then
        echo "No rvm"
    else
        if [ "Linux" == `uname` ]; then
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
   if [ "Linux" == `uname` ]; then
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
	VIRTUALENVWRAPPER_HOOK_DIR=$HOME/.virtualenvs
	VIRTUALENVWRAPPER_LOG_DIR=$HOME/.virtualenvs
	. $HOME/.venvburrito/startup.sh
    fi
}

system_tweaks
path
environment
bash_options
bin_options
if [ -d "$HOME/.rvm" ]; then
    rvm_env
else
    rbenv_setup
fi
python_virtualenv_setup
PROMPT_COMMAND=prompt

fi # closing fi if not run in interactive mode
