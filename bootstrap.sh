#!/usr/bin/env bash
# Bootstrap the small set of prerequisites needed before mise can manage this
# repository. The full machine setup belongs in mise.toml and is applied by
# `mise bootstrap` below.
set -Eeuo pipefail

readonly DEFAULT_REPOSITORY="https://github.com/timfel/dotfiles.git"
readonly MISE_INSTALL_URL="https://mise.run"
readonly ANDROID_EMACSCLIENT="/data/data/org.gnu.emacs/lib/libemacsclient.so"
readonly TERMUX_BIN="/data/data/com.termux/files/usr/bin"

is_android() {
    [[ "$(uname -o 2>/dev/null || true)" == Android ]] \
        || [[ "$(uname -r 2>/dev/null || true)" == *-android* ]]
}

if is_android && [[ -d "$TERMUX_BIN" ]]; then
    export PATH="$TERMUX_BIN:$PATH"
fi

repository="${DOTFILES_REPO:-$DEFAULT_REPOSITORY}"
dotfiles_dir="${DOTFILES_DIR:-${HOME}/dotfiles}"
has_git=0
wrapper_dir=""

cleanup() {
    if [[ -n "${wrapper_dir}" ]]; then
        rm -rf "${wrapper_dir}"
    fi
}
trap cleanup EXIT

inside_android_eshell() {
    [[ "${INSIDE_EMACS:-}" == *eshell ]] && is_android
}

ensure_wrapper_dir() {
    if [[ -n "${wrapper_dir}" ]]; then
        return
    fi
    wrapper_dir="$(mktemp -d)"
    export DOTFILES_ANDROID_EMACSCLIENT="${ANDROID_EMACSCLIENT}"
    export PATH="${wrapper_dir}:${PATH}"
    hash -r
}

log() {
    printf 'bootstrap: %s\n' "$*"
}

fail() {
    printf 'bootstrap: error: %s\n' "$*" >&2
    exit 1
}

as_root() {
    if [[ "${EUID}" -eq 0 ]]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        fail "installing prerequisites requires root or sudo: $*"
    fi
}

install_git() {
    if command -v git >/dev/null 2>&1; then
        has_git=1
        return
    fi

    if inside_android_eshell; then
        log "git was not found; using jj's Git commands through mise"
        ensure_wrapper_dir
        cat > "${wrapper_dir}/git" <<'EOF'
#!/system/bin/sh
if [ "${1:-}" = clone ]; then
    exec mise x jj -- jj git "$@"
fi
{
    printf 'bootstrap: ignoring unsupported git command:'
    for argument do
        printf ' %s' "$argument"
    done
    printf '\n'
} >&2
exit 0
EOF
        chmod +x "${wrapper_dir}/git"
        hash -r
        return
    fi

    log "git was not found; installing it with the system package manager"
    if command -v apt-get >/dev/null 2>&1; then
        as_root apt-get update
        as_root apt-get install -y ca-certificates curl git
    elif command -v dnf >/dev/null 2>&1; then
        as_root dnf install -y ca-certificates curl git
    elif command -v yum >/dev/null 2>&1; then
        as_root yum install -y ca-certificates curl git
    elif command -v apk >/dev/null 2>&1; then
        as_root apk add ca-certificates curl git
    elif command -v pacman >/dev/null 2>&1; then
        as_root pacman -Sy --needed --noconfirm ca-certificates curl git
    elif command -v zypper >/dev/null 2>&1; then
        as_root zypper --non-interactive install ca-certificates curl git
    elif command -v brew >/dev/null 2>&1; then
        brew install git
    else
        fail "could not find a supported package manager; install git and rerun this script"
    fi
    has_git=1
}

install_mise() {
    if command -v mise >/dev/null 2>&1; then
        return
    fi

    log "mise was not found; installing it from ${MISE_INSTALL_URL}"
    local installer
    installer="$(mktemp)"
    if inside_android_eshell; then
        [[ -x "${ANDROID_EMACSCLIENT}" ]] \
            || fail "Android Emacs client is not executable: ${ANDROID_EMACSCLIENT}"
        "${ANDROID_EMACSCLIENT}" --eval \
            "(progn (require 'url-handlers) (url-copy-file \"${MISE_INSTALL_URL}\" \"${installer}\" t))" \
            >/dev/null
    else
        command -v curl >/dev/null 2>&1 || fail "curl is required to install mise"
        curl --fail --silent --show-error --location "${MISE_INSTALL_URL}" --output "${installer}"
    fi
    sh "${installer}"
    rm -f "${installer}"

    # The official installer normally uses ~/.local/bin. Add the common
    # locations explicitly because this process cannot inherit a modified PATH.
    export PATH="${HOME}/.local/bin:${HOME}/bin:${PATH}"
    command -v mise >/dev/null 2>&1 || fail "mise was installed but is not on PATH"
}

install_wget_wrapper() {
    if ! inside_android_eshell; then
        return
    fi
    if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
        return
    fi

    log "curl and wget were not found; providing wget through Android Emacs"
    ensure_wrapper_dir
    cat > "${wrapper_dir}/wget" <<'EOF'
#!/system/bin/sh
set -eu

emacsclient="${DOTFILES_ANDROID_EMACSCLIENT:?}"

unsupported() {
    {
        printf 'bootstrap: unsupported wget arguments:'
        for argument do
            printf ' %s' "$argument"
        done
        printf '\n'
    } >&2
    exit 2
}

copy_url() {
    url="$1"
    file="$2"
    printf 'bootstrap: wget via Android Emacs: %s -> %s\n' "$url" "$file" >&2
    "$emacsclient" --eval \
        "(progn (require 'url-handlers) (url-copy-file \"$url\" \"$file\" t))" \
        >/dev/null
}

case "${1:-}" in
    -qO|-O)
        [ "$#" -eq 3 ] || unsupported "$@"
        output="$2"
        url="$3"
        ;;
    -qO-|-O-)
        [ "$#" -eq 2 ] || unsupported "$@"
        output="-"
        url="$2"
        ;;
    *)
        unsupported "$@"
        ;;
esac

if [ "$output" = - ]; then
    temporary_file="$(mktemp)"
    trap 'rm -f "$temporary_file"' 0 1 2 3 15
    copy_url "$url" "$temporary_file"
    cat "$temporary_file"
else
    copy_url "$url" "$output"
fi
EOF
    chmod +x "${wrapper_dir}/wget"
    hash -r
}

ensure_global_mise_config() {
    local config_dir config link_target actual_target
    config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/mise"
    config="${config_dir}/config.toml"
    link_target="${dotfiles_dir}/mise.toml"
    mkdir -p "${config_dir}"

    if [[ -e "${config}" || -L "${config}" ]]; then
        [[ -L "${config}" ]] || fail "refusing to replace existing mise config: ${config}"
        actual_target="$(readlink -f "${config}" 2>/dev/null || true)"
        [[ "${actual_target}" == "$(readlink -f "${link_target}")" ]] \
            || fail "mise config is a conflicting symlink: ${config}"
        return
    fi

    log "linking global mise config ${config} -> ${link_target}"
    ln -s "${link_target}" "${config}"
}

clone_or_use_repository() {
    if [[ -e "${dotfiles_dir}" ]]; then
        [[ -d "${dotfiles_dir}" ]] || fail "DOTFILES_DIR exists but is not a directory: ${dotfiles_dir}"
        if [[ $has_git -eq 1 ]]; then
            git -C "${dotfiles_dir}" rev-parse --show-toplevel >/dev/null 2>&1 \
                || fail "DOTFILES_DIR exists but is not a git checkout: ${dotfiles_dir}"
        elif inside_android_eshell; then
            [[ -d "${dotfiles_dir}/.jj" ]] \
                || fail "DOTFILES_DIR exists but is not a jj checkout: ${dotfiles_dir}"
        else
            fail "DOTFILES_DIR exists but is not a supported checkout: ${dotfiles_dir}"
        fi
        log "using existing checkout ${dotfiles_dir}"
        if inside_android_eshell; then
            log "not pulling automatically; update it manually with mise x jj -- jj git fetch -R ${dotfiles_dir}"
        else
            log "not pulling automatically; update it manually with git -C ${dotfiles_dir} pull"
        fi
        return
    fi

    mkdir -p "$(dirname "${dotfiles_dir}")"
    log "cloning ${repository} into ${dotfiles_dir}"
    git clone "${repository}" "${dotfiles_dir}"
}

main() {
    [[ -n "${HOME:-}" ]] || fail 'HOME is not set'
    install_wget_wrapper
    install_mise
    install_git
    clone_or_use_repository

    local config="${dotfiles_dir}/mise.toml"
    [[ -f "${config}" ]] || fail "mise.toml was not found in ${dotfiles_dir}"
    ensure_global_mise_config

    log "trusting ${config}"
    mise trust --yes "${config}"

    log "running mise bootstrap"
    if [[ $has_git -eq 1 ]]; then
        (cd "${dotfiles_dir}" && mise bootstrap --yes)
    else
        log "forcing dotfile overrides, since we already created a mise config to use jj instead of git"
        (cd "${dotfiles_dir}" && mise bootstrap --force-dotfiles --yes)
    fi
    log "done"
}

main "$@"
