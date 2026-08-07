export BASH_PROFILE_LOADED=1

# System detection env
case "$(uname)" in
    Darwin) export DARWIN=1 ;;
    Linux) export LINUX=1 ;;
esac

if which tmux >2&1 >/dev/null; then
    export PROF_SCREEN_CMD="test -z ${TMUX} && (tmux -2 attach || tmux -2 new-session)"
fi

# Colors
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
if [ -n "$WT_SESSION" ]; then
    export COLORTERM=truecolor
    export TERM=xterm-direct
fi

# General variables
export PATH="$HOME/bin:$HOME/.local/bin:/usr/local/bin:/opt/bin:/sbin:$PATH"
export BIBINPUTS=".:~/texmf/bibliography/:~/Dropbox/Papers/:$BIBINPUTS"

if [ -z $HOSTNAME ]; then
    export HOSTNAME=`hostname -s`
fi

# For emacs lsp-mode
export LSP_USE_PLISTS=true

# Wayland by default
if [ -n "${WAYLAND_DISPLAY}" ]; then
    export MOZ_ENABLE_WAYLAND=1
    export SDL_VIDEODRIVER=wayland
    export GDK_BACKEND=wayland
fi

if [ -d "$HOME/.mx/mx" ]; then
    export PATH="$HOME/.mx/mx:$PATH"
    export MX_PYTHON_VERSION=3
    # export MX_COMPDB=default
    export MX_BUILD_SHALLOW_DEPENDENCY_CHECKS=true
    export MX_OUTPUT_ROOT_INCLUDES_CONFIG=false
    # export MX_BUILD_EXPLODED=true
    # export LINKY_LAYOUT="*.jar"
    # export JAVA_HOME="lookup:labsjdk-ce-latest"
    export LATEST_JAVA_HOME="$HOME/.mx/jdks/labsjdk-ce-latest"
    # export TOOLS_JAVA_HOME="$HOME/.mx/jdks/labsjdk-ce-21/"
    export PATH="$HOME/.ol/bin:$PATH"
fi

if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate bash)"
fi

if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi

# print CPU version:
awk '/^model name/ { sub(/^model name[^:]*: /, "", $0); print "   ****", toupper($0), "****"; exit }' /proc/cpuinfo
# print memory summary:
free -b | awk '/^Mem:/ { printf " %dK RAM SYSTEM  %d BASIC BYTES FREE\n\nREADY.\n", $2 / 1024, $4 }'
