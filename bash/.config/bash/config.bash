# dotfiles Bash setup.

case $- in
    *i*) ;;
    *) return ;;
esac

__dotfiles_path_prepend() {
    [ -n "$1" ] || return
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1:$PATH" ;;
    esac
}

__dotfiles_path_prepend "$HOME/.local/bin"
export PATH

alias lg='ls | grep'

qf() {
    [ -n "${1:-}" ] || return
    find . -name "$1"
}

ssh() {
    printf '\033]11;#8B4000\007'
    trap 'printf "\033]11;#232627\007"' RETURN

    command ssh "$@"
    local exit_code=$?

    printf '\033]11;#232627\007'
    trap - RETURN
    return "$exit_code"
}

if [ -n "${XDG_RUNTIME_DIR:-}" ]; then
    export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
fi

export FNM_DIR="$HOME/.local/share/fnm"
__dotfiles_path_prepend "$FNM_DIR"
if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --use-on-cd --shell bash)"
fi

export PNPM_HOME="$HOME/.local/share/pnpm"
__dotfiles_path_prepend "$PNPM_HOME"
export PATH

if [ "${TERM:-}" != "dumb" ] && command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi

if [ -r "$HOME/.local/share/blesh/ble.sh" ]; then
    # shellcheck disable=SC1091
    . "$HOME/.local/share/blesh/ble.sh"
elif [ -r /usr/share/blesh/ble.sh ]; then
    # shellcheck disable=SC1091
    . /usr/share/blesh/ble.sh
fi

unset -f __dotfiles_path_prepend
