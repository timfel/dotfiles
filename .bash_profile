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
	    ;;
	*)
	    ;;
    esac
}

function screen_select {
    if [ -n "$PROF_SCREEN_CMD" ]; then
	return
    elif [ -n "$CYGWIN" ]; then
	if where /Q screen; then
	    export PROF_SCREEN_CMD="screen -xRR"
	fi
    else
	if which tmux 2>&1 >/dev/null; then
            export PROF_SCREEN_CMD="test -z ${TMUX} && (tmux -2 attach || tmux -2 new-session)"
	elif which screen 2>&1 >/dev/null; then
	    export PROF_SCREEN_CMD="screen -xRR"
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
    export PATH=$PATH:$HOME/.local/bin
    export PATH=$PATH:/usr/local/bin:/usr/local/sbin:/usr/local/share/npm/bin
    export PATH="$HOME"/bin/:/opt/bin/:/sbin/:$PATH
    if [ -n "$SOLARIS" ]; then
	export PATH=/opt/csw/bin:/opt/sfw/bin:$PATH
    fi
    if [ -n "$CYGWIN" ]; then
	export PATH=/opt/emacs/bin:$PATH
    fi
    if [[ -e "$HOME/.texlive/2016/bin/x86_64-linux/" ]]; then
	export PATH=$PATH:$HOME/.texlive/2016/bin/x86_64-linux/
    fi
    if [[ -e "$HOME/.texlive/2017/bin/x86_64-linux/" ]]; then
	export PATH=$PATH:$HOME/.texlive/2017/bin/x86_64-linux/
    fi
    if [[ -e "$HOME/homebrew/bin" ]]; then
	export PATH=$HOME/homebrew/bin:$PATH
    fi

    export PATH="/home/tim/.linuxbrew/bin:$PATH"
    export MANPATH="/home/tim/.linuxbrew/share/man:$MANPATH"
    export INFOPATH="/home/tim/.linuxbrew/share/info:$INFOPATH"
    if [[ -e "/usr/local/heroku" ]]; then
	export PATH="/usr/local/heroku/bin:$PATH"
    fi

    if [ -d "/usr/local/opt/llvm@6" ]; then
        export PATH="/usr/local/opt/llvm@6/bin:$PATH"
    fi
}

function environment {
    export BIBINPUTS=".:~/texmf/bibliography/:~/Dropbox/Papers/:$BIBINPUTS"

    # export RUBYOPT="rubygems"
    # export MAGLEV_OPTS="-rubygems"

    # if [ -n "$CYGWIN" ]; then
    #     export EMACS="emacsclient -f $(cygpath -m ${HOME}/.emacs.d/server/server) -c"
    # else
    #     export EMACS="emacsclient -f ${HOME}/.emacs.d/server/server -c"
    # fi
    # export EDITOR="$EMACS"
    # export ALTERNATE_EDITOR=""

    export VISUALWORKS=/media/Data/Applications/vw79public
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

function tmux_setup {
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        git clone https://github.com/tmux-plugins/tpm $HOME/.tmux/plugins/tpm
        echo "Reminder: The first time you start tmux, press <prefix keys>+I to install plugins"
        read
    fi
}

function emacs_setup {
    if [ ! -d "$HOME/.emacs.d" ]; then
	git clone https://github.com/timfel/my_emacs_for_rails.git $HOME/.emacs.d
        pushd $HOME/.emacs.d
        git remote set-url origin git@github.com:timfel/my_emacs_for_rails.git
        popd
        # Workaround helm issue
        mkdir -p $HOME/.emacs.d/elpa/
        ln -s $HOME/.emacs.d/el-get/emacs-async $HOME/.emacs.d/elpa/async-0
    fi
    export LSP_USE_PLISTS=true
}

function emacs_workspace {
    if [ ! -d "$1" ]; then
        echo "Preparing workspace"
        git clone --depth 1 https://github.com/timfel/my_emacs_for_rails.git "$1"
        if [ -d "${HOME}/.emacs.d/elpa" ]; then
            cp -R "${HOME}/.emacs.d/elpa" "${1}/elpa"
            find "$1" -name "*.elc" -delete
            find "$1" -name "*.eln" -delete
        fi
    fi
    emacs --init-directory "$1"
}

function install_vista_fonts {
    # Copyright (c) 2007 Aristotle Pagaltzis
    #
    # Permission is hereby granted, free of charge, to any person obtaining a copy
    # of this software and associated documentation files (the "Software"), to
    # deal in the Software without restriction, including without limitation the
    # rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
    # sell copies of the Software, and to permit persons to whom the Software is
    # furnished to do so, subject to the following conditions:
    #
    # The above copyright notice and this permission notice shall be included in
    # all copies or substantial portions of the Software.
    #
    # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    # IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    # FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    # AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    # LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    # FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
    # IN THE SOFTWARE.
    if ! [ -d ~/.fonts ] ; then
        mkdir -p ~/.fonts
    fi

    # split up to keep the download command short
    DL_HOST=download.microsoft.com
    DL_PATH=download/f/5/a/f5a3df76-d856-4a61-a6bd-722f52a5be26
    ARCHIVE=PowerPointViewer.exe
    URL="http://$DL_HOST/$DL_PATH/$ARCHIVE"

    pushd ~/.fonts
    wget "$URL"
    TMPDIR=`mktemp -d`
    cabextract -L -F ppviewer.cab -d "$TMPDIR" "$ARCHIVE"
    cabextract -L -F '*.TT[FC]' -d ~/.fonts "$TMPDIR/ppviewer.cab"
    mv cambria.ttc cambria.ttf
    fc-cache -fv ~/.fonts
    popd
}

function ubuntu_setup {
    if [ ! -e "$HOME/.ubuntu_dev_installed" ]; then
        touch "$HOME/.ubuntu_dev_installed"
        if [[ `lsb_release -i` = *Ubuntu ]]; then
            printf "Setup Ubuntu dev system (Skype/Eclipse/Emacs/LLVM)? (Y/n)"
            read answer
            if [ $answer == "y" -o $answer == "Y" ]; then
                curl -L https://packagecloud.io/slacktechnologies/slack/gpgkey | sudo apt-key add -
                sudo add-apt-repository ppa:webupd8team/java
                sudo add-apt-repository ppa:mmk2410/eclipse-ide-java
                sudo add-apt-repository ppa:openconnect/daily
                sudo su –c 'echo "deb [arch=amd64] https://repo.skype.com/deb stable main" > /etc/apt/sources.list.d/skype.list"'
                sudo su –c 'echo "deb https://packagecloud.io/slacktechnologies/slack/debian/ jessie main" > /etc/apt/sources.list.d/slack.list"'
                sudo apt update
                sudo apt install emacs texinfo cvs git-svn \
                     xsel git mercurial ruby rake build-essential \
                     tmux vim htop curl screen clang eclipse-ide-java \
                     llvm libc++-dev libc++abi-dev \
                     skypeforlinux openconnect python3-pip \
                     libffi-dev libz-dev ttf-mscorefonts-installer
                oracle-java8-installer oracle-java8-set-default
                pip3 install --user https://github.com/dlenski/vpn-slice/archive/master.zip
                install_vista_fonts
            fi
        fi
    fi
}

function darwin_setup {
    if [ ! -e "$HOME/.ubuntu_dev_installed" ]; then
        touch "$HOME/.ubuntu_dev_installed"
        printf "Setup dev system (LLVM, brew)? (Y/n)"
        read answer
        if [ $answer == "y" -o $answer == "Y" ]; then
            xcode-select --install
            /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
            brew install llvm@6
            export PATH="/usr/local/opt/llvm@6/bin:$PATH"
            # install headers
            open /Library/Developer/CommandLineTools/Packages/macOS_SDK_headers_for_macOS_10.14.pkg
        fi
    fi
}

function install_slack_term {
    if [ ! -e "$HOME/bin/slack-term" -o -n "$1" ]; then
        printf "Install slack-term? (y/N)"
        read answer
        if [ "$answer" == "y" -o "$answer" == "Y" ]; then
            which go || sudo apt-get install golang-go || true
            GOPATH=/tmp/goslkterm go get -u github.com/timfel/slack-term
            pushd /tmp/goslkterm/src/github.com/timfel/slack-term/

            # jump to unread action
            # ( git fetch origin pull/156/head && git merge -m "m" FETCH_HEAD ) || true

            GOPATH=/tmp/goslkterm go install .
            popd
            mv /tmp/goslkterm/bin/slack-term ${HOME}/bin
            rm -rf /tmp/goslkterm
        else
            touch "$HOME/bin/slack-term"
        fi
    fi
}

function debian_setup {
    export DEBEMAIL="Tim Felgentreff <timfelgentreff@gmail.com>"
    export DEBFULLNAME="Tim Felgentreff"
}

function wayland_setup {
    if [ -n "${WAYLAND_DISPLAY}" ]; then
        export MOZ_ENABLE_WAYLAND=1
        export SDL_VIDEODRIVER=wayland
        export GDK_BACKEND=wayland
    fi
}

if [ -e "$HOME/.micronaut/micronaut-cli-3.9.1/" ]; then
    export MICRONAUT_HOME="$HOME/.micronaut/micronaut-cli-3.9.1/"
    export PATH="${PATH}:${MICRONAUT_HOME}/bin"
fi

debian_setup
determine_os
screen_select
export_colors

path
environment
rupypy_setup
tmux_setup
emacs_setup
wayland_setup

if [ -n "$LINUX" ]; then
    install_slack_term
fi

if [ -n "$CYGWIN" ]; then
    win_path_setup
fi

source ~/.bashrc

# startup virtualenv-burrito
# if [ -f $HOME/.venvburrito/startup.sh ]; then
#     . $HOME/.venvburrito/startup.sh
# fi

# print CPU version:
awk '/^model name/ { sub(/^model name[^:]*: /, "", $0); print "   ****", toupper($0), "****"; exit }' /proc/cpuinfo
# print memory summary:
free -b | awk '/^Mem:/ { printf " %dK RAM SYSTEM  %d BASIC BYTES FREE\n\nREADY.\n", $2 / 1024, $4 }'

# function term_sane {
#     stty sane
#     echo -en "\e[?25h"
# }
if [ -e "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
fi

# Added by `rbenv init` on Mon Oct 21 21:20:27 CEST 2024
eval "$(rbenv init - bash)"
