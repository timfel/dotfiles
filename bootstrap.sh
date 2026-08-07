#!/usr/bin/env bash
# Bootstrap the small set of prerequisites needed before mise can manage this
# repository. The full machine setup belongs in mise.toml and is applied by
# `mise bootstrap` below.
set -Eeuo pipefail

readonly DEFAULT_REPOSITORY="https://github.com/timfel/dotfiles.git"
readonly MISE_INSTALL_URL="https://mise.run"

repository="${DOTFILES_REPO:-$DEFAULT_REPOSITORY}"
dotfiles_dir="${DOTFILES_DIR:-${HOME}/dotfiles}"

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
}

install_mise() {
    if command -v mise >/dev/null 2>&1; then
        return
    fi

    command -v curl >/dev/null 2>&1 || fail "curl is required to install mise"

    log "mise was not found; installing it from ${MISE_INSTALL_URL}"
    local installer
    installer="$(mktemp)"
    curl --fail --silent --show-error --location "${MISE_INSTALL_URL}" --output "${installer}"
    sh "${installer}"
    rm -f "${installer}"

    # The official installer normally uses ~/.local/bin. Add the common
    # locations explicitly because this process cannot inherit a modified PATH.
    export PATH="${HOME}/.local/bin:${HOME}/bin:${PATH}"
    command -v mise >/dev/null 2>&1 || fail "mise was installed but is not on PATH"
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
        git -C "${dotfiles_dir}" rev-parse --show-toplevel >/dev/null 2>&1 \
            || fail "DOTFILES_DIR exists but is not a git checkout: ${dotfiles_dir}"
        log "using existing checkout ${dotfiles_dir}"
        log "not pulling automatically; update it manually with git -C ${dotfiles_dir} pull"
        return
    fi

    mkdir -p "$(dirname "${dotfiles_dir}")"
    log "cloning ${repository} into ${dotfiles_dir}"
    git clone "${repository}" "${dotfiles_dir}"
}

main() {
    [[ -n "${HOME:-}" ]] || fail 'HOME is not set'
    install_git
    install_mise
    clone_or_use_repository

    local config="${dotfiles_dir}/mise.toml"
    [[ -f "${config}" ]] || fail "mise.toml was not found in ${dotfiles_dir}"
    ensure_global_mise_config

    log "trusting ${config}"
    mise trust --yes "${config}"

    log "running mise bootstrap"
    (cd "${dotfiles_dir}" && mise bootstrap --yes)
    log "done"
}

main "$@"
