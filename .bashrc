# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
test "$PS1" || return 1

if test -z "$BASH_PROFILE_LOADED"; then
    # If bash_profile wasn't loaded, load it This is an optimization, as
    # Cygwin loads bash_profile once, and then only runs through bashrc
    # for new terminals and screens. Because fork is slow on Cygwin, we do
    # most of the forking in bash_profile, making creating new terminals
    # fast on Cygwin. On some Linux systems, each new screen gets a fresh
    # environment and thus has to reload bash_profile
    source ~/.bash_profile
    return 0
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
fi

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
      EXITCODE="${COLOR_GREEN_BOLD}"
   else
      EXITCODE="${COLOR_RED_BOLD}"
   fi
   EXITCODE="${EXITCODE}>${COLOR_NONE}"

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
             MACHINE="${MACHINE}->"
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

   if [ -n "${VIRTUAL_ENV_PROMPT}" ]; then
       PS1="$PS1 🐍${VIRTUAL_ENV_PROMPT}"
   else
       PS1="$PS1 "
   fi

   if [ -n "${CONDA_PREFIX}" ]; then
       PS1="$PS1 ⊙${CONDA_PROMPT_MODIFIER}"
   fi

   # Show the current branch
   VCS=`echo -e $(__prompt_command)`
   if [ -z "$VCS" ]; then
      EXITCODE="${EXITCODE}"
   else
      VCS="🌿[${VCS}] "
   fi
   PS1="$PS1$VCS"
   if [ -n "${TERM#screen*}" ]; then
      PS1="$PS1$EXITCODE "
   else
      PS1='\[\033k\033\\\]'"$PS1$EXITCODE "
   fi

   history -a
}

function rvm_env {
    # rvm-install added line:
    if [[ -n $NORVM ]]; then
        echo "No rvm"
    else
        if [ -n "$LINUX" ]; then
            if [[ -s "$HOME"/.rvm/scripts/rvm ]] ; then
                source "$HOME"/.rvm/scripts/rvm
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

        function rbenv-use {
	    if [ $# -eq 0 ]; then
		echo $RBENV_VERSION
	    else
		export RBENV_VERSION=$1
	    fi
        }

        function __use-ruby-completion {
            COMPREPLY=()
            local word="${COMP_WORDS[COMP_CWORD]}"
            COMPREPLY=( $(compgen -W "$(ls ~/.rbenv/versions/)" -- "$word") )
        }

        complete -F __use-ruby-completion rbenv-use
    fi
}

function pyenv_setup {
    if [ ! -e "$HOME/.pyenv" ]; then
        printf "Install pyenv? (Y/n)"
        read answer
        if [ $answer == "y" -o $answer == "Y" ]; then
            git clone https://github.com/pyenv/pyenv.git "$HOME/.pyenv"
        else
            touch "$HOME/.pyenv"
        fi
        unset answer
    fi

    if [ -d "$HOME/.pyenv/bin" ]; then
        export PYENV_ROOT="$HOME"/.pyenv
        export PATH="$PYENV_ROOT"/bin:"$PATH"
        if command -v pyenv 1>/dev/null 2>&1; then
            eval "$(pyenv init --path)"
            eval "$(pyenv init -)"
        fi
    fi
}

function nvm_setup {
    if [ ! -e "$HOME/.nvm" ]; then
        printf "Install nvm? (Y/n)"
        read answer
        if [ $answer == "y" -o $answer == "Y" ]; then
	    git clone https://github.com/creationix/nvm.git ~/.nvm
	    pushd ~/.nvm
	    git checkout `git describe --abbrev=0 --tags`
	    popd
        else
            touch "$HOME/.nvm"
        fi
        unset answer
    fi
    export NVM_DIR="/home/tim/.nvm"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
       source "$NVM_DIR/nvm.sh"
       # alias node="unalias npm && unalias node && source $NVM_DIR/nvm.sh && node"
       # alias npm="unalias npm && unalias node && source $NVM_DIR/nvm.sh && npm"
    fi
}

function graalenv_setup {
    if [ ! -d "$HOME/.graalenv" ]; then
	git clone https://github.com/timfel/graalenv $HOME/.graalenv
        pushd $HOME/.graalenv
        mkdir products
        git remote set-url origin git@github.com:timfel/graalenv.git
        popd
    fi
    source ~/.graalenv/graalenv
    graalenv use latest

    export MX_PYTHON_VERSION=3
    export MX_COMPDB=default
    export MX_BUILD_SHALLOW_DEPENDENCY_CHECKS=true
    export MX_OUTPUT_ROOT_INCLUDES_CONFIG=true
    # export MX_BUILD_EXPLODED=true
    # export LINKY_LAYOUT="*.jar"
    export LATEST_JAVA_HOME="$HOME/.mx/jdks/labsjdk-ce-latest/"
    export TOOLS_JAVA_HOME="$HOME/.mx/jdks/labsjdk-ce-21/"
}

function mx_fetch_latest_jdk {
    mx -p ../graal/vm fetch-jdk -A --jdk-id labsjdk-ce-latest
    export JAVA_HOME="$HOME/.mx/jdks/labsjdk-ce-latest/"
}

function system_tweaks {
   if [ -n "$LINUX" ]; then
      function session_reload {
        export DBUS_SESSION_BUS_ADDRESS=$(tr '\0' '\n' < /proc/$(pgrep -U $(whoami) gnome-session)/environ|grep ^DBUS_SESSION_BUS_ADDRESS=|cut -d= -f2-)

	export GNOME_KEYRING_CONTROL=/run/usr/$(whoami)/$(ls -c /run/user/$(whoami)/ | grep keyring- | head -1)
        export GNOME_KEYRING_PID=$(ps x | grep /usr/bin/gnome-keyring | grep -v grep | cut -f 1 -d' ')

	new_ICE_session=$(ls -c /tmp/.ICE-unix/ | head -1)
	export SESSION_MANAGER=$(echo $SESSION_MANAGER | sed "s#.ICE-unix/[0-9]*#.ICE-unix/${new_ICE_session}#g")
	unset new_ICE_session
      }

      if [[ -n "$DISPLAY" ]]; then
         if ( which xcalib 2>&1 > /dev/null ); then
           true 
           # xcalib $HOME/.ColorLCD.icc
         fi
	 if [ -f $HOME/.Xresources ]; then
	   if ( which xrdb 2>&1 >/dev/null ); then
             xrdb -merge $HOME/.Xresources 2>&1 >/dev/null
	   fi
	 fi
      fi
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
    export GEMSTONE_GLOBAL_DIR="$MAGLEV_HOME"

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
		echo $STONENAME
		echo $MAGLEV_OPTS
	    else
		nostone=`echo "$MAGLEV_OPTS" | sed 's/--stone [^ ]*//'`
		export STONENAME="$1"
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

function bash_options {
    # don't put duplicate lines in the history. See bash(2) for more options
    # ... and ignore same sucessive entries.
    export HISTCONTROL="ignoreboth"

    # check the window size after each command and, if necessary,
    # update the values of LINES and COLUMNS.
    shopt -s checkwinsize
 
    # enable programmable completion features (you don't need to enable
    # this, if it's already enabled in /etc/bash.bashrc and /etc/profile
    # sources /etc/bash.bashrc).
    if [ -f /etc/bash_completion ]; then
        source /etc/bash_completion
    fi
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        source /usr/share/bash-completion/bash_completion
    fi
 
    # One-TAB-Completion
    set show-all-if-ambiguous on
}

function bin_options {
   # make less more friendly for non-text input files, see lesspipe(1)
   [ -x /usr/bin/lesspipe ] && eval "$(lesspipe)"

   # enable color support of ls and also add handy aliases
   if [ -z "$SOLARIS" ] && [ "$TERM" != "dumb" ]; then
       if [ -x /usr/bin/dircolors ]; then
           eval "`dircolors -b`"
       fi
       if [ -e ~/.dircolors ]; then
           eval "`dircolors ~/.dircolors`"
       fi
       if [ -z "$DARWIN" ]; then
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

   # alias vi="$EDITOR"
   # alias em="$EMACS -n"

   alias ac='asciinema play -s 1.5 -i 2'
   alias srccat="source-highlight -f esc -i"

   # RVM shortcuts
   alias rvm_isolate="rvm gemset create \$(basename \`pwd\`); echo 'rvm gemset use \$(basename \`pwd\`)' >> .rvmrc; cd ../\$(basename \`pwd\`)"

   # Work shortcuts
   alias swa_hiwi="cd ~/Documents/HPI/SWA-HiWi"
   alias maglevh="source ~/bin/maglev-head"
   alias jrubyh="source ~/bin/jruby-head"

   alias dia="dia --integrated"

   alias w3m="w3m -o auto_image=TRUE -graph -F"
}

function sproxy {
    local proxy="$(gsettings get org.gnome.system.proxy.http host)"
    local proxy4https="${proxy}"    
    proxy=$(eval echo ${proxy}) # getting rid of quotes

    if [ -z "$proxy" ]; then
        echo "No proxy, checking wpad"

        local wpad="$(curl -s wpad)"
        if [ $? -eq 0 ]; then
            proxy=`echo ${wpad} | grep -m1 -oP "PROXY \K([\w\-\.:]+)" | head -1`
            proxy4https="${proxy}"
        fi
    fi

    if [ -n "$proxy" ]; then
        if [[ $proxy = *:* ]]; then
            # already got a port
            echo "Proxy set with port"
        else
            proxy4https="${proxy}:443"
            proxy="${proxy}:80"
        fi

        if [[ $proxy = http* ]]; then
            # already got a schema
            echo "Proxy set with schema"
        else
            if [[ $proxy4https = *:80 ]]; then
                proxy4https="http://${proxy}"
            else
                proxy4https="https://${proxy}"
            fi
            proxy="http://${proxy}"
        fi
    fi

    httpurl=${proxy#*://}
    httpport=${httpurl##*:}
    httpurl=${httpurl%%:*}

    httpsurl=${proxy4https#*://}
    httpsport=${httpsurl##*:}
    httpsurl=${httpsurl%%:*}

    if [ -z "$proxy" ]; then
        echo "Unsetting proxy"
        unset http_proxy
        unset https_proxy
        unset HTTP_PROXY
        unset HTTPS_PROXY
        unset no_proxy
        unset NO_PROXY
        MAVEN_OPTS="$__prev_sproxy_MAVEN_OPTS"
        GRADLE_OPTS="$__prev_sproxy_GRADLE_OPTS"
        unset MX_URLREWRITES
    else
        echo "Setting http_proxy=${proxy} and https_proxy=${proxy4https}"
        export __prev_sproxy_MAVEN_OPTS="$MAVEN_OPTS"
        export http_proxy=${proxy}
        export https_proxy=${proxy4https}
        export HTTP_PROXY=${proxy}
        export HTTPS_PROXY=${proxy4https}
        export no_proxy="localhost,127.0.0.1,*.oraclecorp.com,oraclecorp.com,*.oraclecloud.com,oraclecloud.com,*.oracle.com,oracle.com"
        export NO_PROXY="$no_proxy"
        non_proxy_hosts=`echo $no_proxy | sed 's/,/|/g'`
        java_opts="-Dhttp.proxyHost=${httpurl} -Dhttp.proxyPort=${httpport} -Dhttps.proxyHost=${httpsurl} -Dhttps.proxyPort=${httpsport} -Dhttp.nonProxyHosts=${non_proxy_hosts} -Dhttp.nonProxyHosts=${non_proxy_hosts}"
        export MAVEN_OPTS="${MAVEN_OPTS} ${java_opts}"
        export GRADLE_OPTS="${GRADLE_OPTS} ${java_opts}"
        # Update ~/.urlrewrites if older than 2 days
        if test -z `find ~/.urlrewrites -mtime -2 -print`; then
            curl --silent --connect-timeout 2 --output ~/.urlrewrites https://graalvm.oraclecorp.com/urlrewrites
            touch ~/.urlrewrites
        fi
        export MX_URLREWRITES=`cat $HOME/.urlrewrites`
    fi
}

function wsl_setup {
    if ( which wsl.exe 2>&1 > /dev/null ); then
        export WSL=true
    fi
}

function wslpath_add {
    windows_path=$(wslvar PATH)
    unix_paths=()
    IFS=';' read -r -a windows_path_array <<< "$windows_path"
    for path in "${windows_path_array[@]}"; do
        unix_path=$(wslpath -u "$path")
        unix_paths+=("$unix_path")
    done
    combined_path=$(IFS=':' ; echo "${unix_paths[*]}")
    echo "$combined_path"
    export PATH="$PATH:$combined_path"
}

function full {
    ex -c 'g/^.*\(\<[0-9]\+\)\/.*$/ya|pu|s::readlink /proc/\1/exe:|.!sh' -c 'g/^\//-ya|pu|-2s/^\(.*\<[0-9]\+\)\/[^[:space:]]*\(.*\)$/\1/|+2s//\2/|-2j!3' -c%p -c 'q!' /dev/stdin
}

bash_options
system_tweaks
if [ -d "$HOME/.rvm" ]; then
    rvm_env
else
    rbenv_setup
fi
pyenv_setup
nvm_setup
maglev_setup
graalenv_setup
bin_options
wsl_setup

source "$HOME"/bin/bash_vcs.sh
PROMPT_COMMAND=prompt

# added by travis gem
[ -f /home/tim/.travis/travis.sh ] && source /home/tim/.travis/travis.sh



# >>> mamba initialize >>>
# !! Contents within this block are managed by 'mamba init' !!
export MAMBA_EXE="/home/tim/.local/bin/micromamba";
export MAMBA_ROOT_PREFIX="/home/tim/micromamba";
__mamba_setup="$('/home/tim/.local/bin/micromamba' shell hook --shell bash --prefix '/home/tim/micromamba' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__mamba_setup"
else
    if [ -f "/home/tim/micromamba/etc/profile.d/micromamba.sh" ]; then
        . "/home/tim/micromamba/etc/profile.d/micromamba.sh"
    else
        export  PATH="/home/tim/micromamba/bin:$PATH"  # extra space after export prevents interference from conda init
    fi
fi
unset __mamba_setup
# <<< mamba initialize <<<
if [ -e "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
fi

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
