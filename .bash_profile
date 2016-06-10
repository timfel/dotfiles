ps aux | grep -v grep | grep X 2>&1 >/dev/null
if [ $? -eq 1 ] && [ -z "$DISPLAY" ] && [ $(tty) == /dev/tty2 ]; then
    exec startx
fi

export BASH_PROFILE_LOADED=1

function determine_os {
    case "$(uname)" in
	CYGWIN*)
	    export CYGWIN=1
	    ;;
	SunOS)
	    export SOLARIS=1
	    ;;
	Darwin)
	    export DARWIN=1
	    ;;
	Linux)
	    export LINUX=1
	    if [ "$(uname -n)" == "speedLinux" ]; then
		export SPEEDLINUX=1
		export DISPLAY=192.168.0.1:0.0
	    fi
	    if [ -d /mnt/c/Windows ]; then
		export DISPLAY=:0.0
		return
	    fi
	    lsmod | grep vboxguest 2>&1 >/dev/null 
	    if [ $? -eq 0 ]; then
		ps aux | grep -v grep | grep X 2>&1 >/dev/null
		if [ $? -eq 1 ]; then
		    # Virtualbox without X
		    export DISPLAY=10.0.2.2:0.0
		else
		    if [ -z $DISPLAY ]; then
			export DISPLAY=:0
		    fi
		fi
	    fi
	    ;;
	*)
	    ;;
    esac
}

function screen_select {
    if [ -n "$CYGWIN" ]; then
	if where /Q screen; then
	    export PROF_SCREEN_CMD="screen -xRR"
	fi
    else
	# if which tmux 2>&1 >/dev/null; then
        # if no session is started, start a new session
	#     export PROF_SCREEN_CMD="test -z ${TMUX} && (tmux attach || tmux new-session)"
	# else if which screen 2>&1 >/dev/null; then
	if which screen 2>&1 >/dev/null; then
	    export PROF_SCREEN_CMD="screen -xRR"
	# fi fi
        fi
    fi
}

function export_colors {
    if [ -z "$SOLARIS" ]; then
	export COLOR_RED="\[\033[31;40m\]"
	export COLOR_GREEN="\[\033[32;40m\]"
	export COLOR_YELLOW="\[\033[33;40m\]"
	export COLOR_BLUE="\[\033[34;40m\]"
	export COLOR_MAGENTA="\[\033[35;40m\]"
	export COLOR_CYAN="\[\033[36;40m\]"
	export COLOR_RED_BOLD="\[\033[31;1m\]"
	export COLOR_GREEN_BOLD="\[\033[32;1m\]"
	export COLOR_YELLOW_BOLD="\[\033[33;1m\]"
	export COLOR_BLUE_BOLD="\[\033[34;1m\]"
	export COLOR_MAGENTA_BOLD="\[\033[35;1m\]"
	export COLOR_CYAN_BOLD="\[\033[36;1m\]"
	export COLOR_NONE="\[\033[0m\]"
    fi
}

function path {
    export PATH=$PATH:/usr/GNUstep/System/Tools:/usr/local/bin:/usr/local/sbin:/usr/local/share/npm/bin
    export PATH="$HOME"/bin/:/var/lib/gems/1.8/bin/:/opt/bin/:/sbin/:$PATH
    if [ -n "$SOLARIS" ]; then
	export PATH=/opt/csw/bin:/opt/sfw/bin:$PATH
    fi
    if [ -n "$CYGWIN" ]; then
	export PATH=/opt/emacs/bin:$PATH
    fi
    if [[ -e "$HOME/Devel/projects/git-hg/bin" ]]; then
	export PATH=$PATH:$HOME/Devel/projects/git-hg/bin
    fi
    if [[ -e "/usr/local/texlive/2014/bin/x86_64-linux/" ]]; then
	export PATH=$PATH:/usr/local/texlive/2014/bin/x86_64-linux/
    fi
    if [[ -e "$HOME/homebrew/bin" ]]; then
	export PATH=$HOME/homebrew/bin:$PATH
    fi

    if [[ -e "/usr/local/heroku" ]]; then
	export PATH="/usr/local/heroku/bin:$PATH"
    fi
}

function environment {
    export BIBINPUTS=".:~/texmf/bibliography/:~/Dropbox/Papers/:$BIBINPUTS"

    # export RUBYOPT="rubygems"
    # export MAGLEV_OPTS="-rubygems"

    if [ -n "$CYGWIN" ]; then
        export EMACS="emacsclient -f $(cygpath -m ${HOME}/.emacs.d/server/server) -c"
    else
        export EMACS="emacsclient -f ${HOME}/.emacs.d/server/server -c"
    fi
    export EDITOR="$EMACS"
    export ALTERNATE_EDITOR=""

    export VISUALWORKS=/media/Data/Applications/vw79public
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
 
    # One-TAB-Completion
    set show-all-if-ambiguous on
}

function prepare_prompt_variables {
    if [ -z $HOSTNAME ]; then
        export HOSTNAME=`hostname -s`
    fi
}

function rupypy_setup {
    if [ -e "$HOME/.rbenv/versions/rupypy" ]; then
        rupypy=$(readlink -f "$HOME/.rbenv/versions/rupypy")
        rupypy_parent=$(cd $rupypy ; cd .. ; pwd)
        export PYTHONPATH=$rupypy_parent/pypy:$rupypy_parent/pypy/pypy:$rupypy_parent/rply:$rupypy_parent/rupypy:$PYTHONPATH
    fi
}

function win_path_setup {
    JAVA_FOLDER="$(ls /cygdrive/c/Program\ Files/Java/ | sort -r | grep -m 1 jdk)"
    export JAVA_HOME="C:/Program Files/Java/$JAVA_FOLDER"
    export PATH="`cygpath -a "$JAVA_HOME"`/bin:${PATH}"
    export ANT_HOME="/opt/apache-ant-1.8.4/"
    export PATH=$ANT_HOME/bin:$PATH

    export PATH=$PATH:/opt/mplayer
}

determine_os
screen_select
export_colors

path
environment
bash_options
rupypy_setup

if [ -n "$CYGWIN" ]; then
    win_path_setup
fi

source ~/.bashrc
