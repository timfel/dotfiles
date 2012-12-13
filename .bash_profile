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
	    ;;
	*)
	    ;;
    esac
}

function screen_select {
    if [ -n "$CYGWIN" ]; then
	if where /Q screen; then
	    export PROF_SCREEN_CMD="screen -xR"
	fi
    else
	if which tmux 2>&1 >/dev/null; then
        # if no session is started, start a new session
	    export PROF_SCREEN_CMD="test -z ${TMUX} && (tmux attach || tmux new-session)"
	else if which screen 2>&1 >/dev/null; then
	    export PROF_SCREEN_CMD="screen -xR"
	fi fi
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
    if [[ -e "$HOME/Devel/projects/git-hg/bin" ]]; then
	export PATH=$PATH:$HOME/Devel/projects/git-hg/bin
    fi
    if [[ -e "$HOME/homebrew/bin" ]]; then
	export PATH=$HOME/homebrew/bin:$PATH
    fi
}

function environment {
    export BIBINPUTS=".:~/texmf/bibliography/:~/Dropbox/Papers/:$BIBINPUTS"

    # export RUBYOPT="rubygems"
    # export MAGLEV_OPTS="-rubygems"

    export EMACS="emacsclient -f ${HOME}/.emacs.d/server/server -c"
    export EDITOR="$EMACS"
    export ALTERNATE_EDITOR=""
    alias vi=$EDITOR
    alias em="$EMACS -n"

    export VISUALWORKS=/media/Data/Applications/vw79public
}

function bash_options {
    # don't put duplicate lines in the history. See bash(2) for more options
    # ... and ignore same sucessive entries.
    export HISTCONTROL="ignoredups;ignoreboth"

    # check the window size after each command and, if necessary,
    # update the values of LINES and COLUMNS.
    shopt -s checkwinsize
 
    # enable programmable completion features (you don't need to enable
    # this, if it's already enabled in /etc/bash.bashrc and /etc/profile
    # sources /etc/bash.bashrc).
    # if [ -f /etc/bash_completion ]; then
    #     . /etc/bash_completion
    # fi
 
    # One-TAB-Completion
    set show-all-if-ambiguous on
}

function prepare_prompt_variables {
    if [ -z $HOSTNAME ]; then
        export HOSTNAME=`hostname -s`
    fi
}

function bin_options {
   # make less more friendly for non-text input files, see lesspipe(1)
   [ -x /usr/bin/lesspipe ] && eval "$(lesspipe)"

   # enable color support of ls and also add handy aliases
   if [ -n "$SOLARIS" ] && [ "$TERM" != "dumb" ]; then
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

   # RVM shortcuts
   alias rvm_isolate="rvm gemset create \$(basename \`pwd\`); echo 'rvm gemset use \$(basename \`pwd\`)' >> .rvmrc; cd ../\$(basename \`pwd\`)"

   # Work shortcuts
   alias swa_hiwi="cd ~/Documents/HPI/SWA-HiWi"
   alias maglevh="source ~/bin/maglev-head"
   alias jrubyh="source ~/bin/jruby-head"

   alias dia="dia --integrated"
}

function rupypy_setup {
    rupypy=$(readlink -f "$HOME/.rbenv/versions/rupypy")
    rupypy_parent=$(cd $rupypy ; cd .. ; pwd)
    export PYTHONPATH=$rupypy_parent/pypy:$rupypy_parent/pypy/pypy:$rupypy_parent/rply:$rupypy_parent/rupypy:$PYTHONPATH
}

function win_java_setup {
    export JAVA_HOME="C:/Program Files/Java/jdk1.7.0_09/"
    export PATH="`cygpath -a "$JAVA_HOME"`/bin:${PATH}"
    export ANT_HOME="/opt/apache-ant-1.8.4/"
    export PATH=$ANT_HOME/bin:$PATH
}

determine_os
screen_select
export_colors

path
environment
bash_options
bin_options
rupypy_setup

if [ -n "$CYGWIN" ]; then
    win_java_setup
fi

source ~/.bashrc
