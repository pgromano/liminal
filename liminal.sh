# ---------------------------------------------------------------------------
# Display variables — namespaced to avoid polluting the shell environment.
# Not exported, so they won't bleed into child processes, but intentionally
# file-scoped (sourced context) so all _liminal-* functions can reference them.
# ---------------------------------------------------------------------------
_LIMINAL_RESET='\033[0m'
_LIMINAL_BOLD='\033[1m'
_LIMINAL_MUTED='\033[2m'
_LIMINAL_BLUE='\033[38;5;027m'
_LIMINAL_YELLOW='\033[38;5;178m'
_LIMINAL_TEAL='\033[38;5;115m'

_liminal-get-python-ver() {
    echo $(cat "$HOME/.liminal/envs/$1/.python-version" 2>/dev/null || echo "unknown")
}

# ---------------------------------------------------------------------------
# autocomplete
#   zsh and bash use entirely different completion systems.
#   We provide a native implementation for each.
# ---------------------------------------------------------------------------
_liminal_commands="help list status activate deactivate create remove install uninstall search switch set"

if [ -n "${ZSH_VERSION:-}" ]; then
    # --- zsh native completion ---
    _liminal_completions_zsh() {
        local prev="${words[-2]}"
        case "$prev" in
            activate|remove)
                local envs=($(ls "$HOME/.liminal/envs/" 2>/dev/null))
                compadd -a envs
                ;;
            switch|set|uninstall)
                local versions=($(pyenv versions --bare 2>/dev/null))
                compadd -a versions
                ;;
            install|search|create)
                ;;
            *)
                compadd -- ${=_liminal_commands}
                ;;
        esac
    }
    compdef _liminal_completions_zsh liminal
else
    # --- bash native completion ---
    _liminal_completions_bash() {
        local cur="${COMP_WORDS[COMP_CWORD]}"
        local prev="${COMP_WORDS[COMP_CWORD-1]}"
        case "$prev" in
            activate|remove)
                local envs=$(ls "$HOME/.liminal/envs/" 2>/dev/null)
                COMPREPLY=($(compgen -W "$envs" -- "$cur"))
                ;;
            switch|set|uninstall)
                local versions=$(pyenv versions --bare 2>/dev/null)
                COMPREPLY=($(compgen -W "$versions" -- "$cur"))
                ;;
            install|search|create)
                COMPREPLY=()
                ;;
            *)
                COMPREPLY=($(compgen -W "$_liminal_commands" -- "$cur"))
                ;;
        esac
    }
    complete -F _liminal_completions_bash liminal
fi

# ---------------------------------------------------------------------------
# _liminal-help
# ---------------------------------------------------------------------------
_liminal-help() {
    printf "\n ${_LIMINAL_BOLD}liminal${_LIMINAL_RESET}: a tool for things inbetween the things inbetween\n"
    printf "\n${_LIMINAL_BOLD}Usage:${_LIMINAL_RESET}\n ${_LIMINAL_MUTED}liminal <command> [options]${_LIMINAL_RESET}\n"
    printf "\n${_LIMINAL_BOLD}Env Commands:${_LIMINAL_RESET}\n"
    echo "  help          Show this help message and exit"
    echo "  list          List all existing virtual environments"
    echo "  activate      Activates an existing virtual environment"
    echo "  deactivate    Deactivates current virtual environment"
    echo "  create        Create a new virtual environment"
    echo "  remove        Removes an existing virtual environment"
    echo "  install       Install a new Python version"
    echo "  uninstall     Uninstall an existing Python version"
    echo "  search        Search available Python versions"
    echo "  switch        Temporarily update the local Python version"
    echo "  set           Update the default global Python version"
    echo "  status        Display info about the current active env and Python version"
}

# ---------------------------------------------------------------------------
# _liminal-status
# ---------------------------------------------------------------------------
_liminal-status() {
    local pyver=$(python3 --version 2>&1)
    local pypath=$(which python3)
    local env=${VIRTUAL_ENV:-None}

    printf "\n${_LIMINAL_BLUE}  ${_LIMINAL_BOLD}Python:      ${_LIMINAL_RESET}${_LIMINAL_BOLD}%s${_LIMINAL_RESET} ${_LIMINAL_MUTED}%s${_LIMINAL_RESET}" "$pyver" "($pypath)"
    printf "\n${_LIMINAL_YELLOW}  ${_LIMINAL_BOLD}Environment: ${_LIMINAL_RESET}${_LIMINAL_BOLD}%s${_LIMINAL_RESET}" "$env"
    printf "\n"
}

# ---------------------------------------------------------------------------
# _liminal-list
# ---------------------------------------------------------------------------
_liminal-list() {
    printf "\nAvailable Environments\n"

    if [ ! -d "$HOME/.liminal/envs" ] || [ -z "$(ls "$HOME/.liminal/envs/" 2>/dev/null)" ]; then
        printf "  None\n"
    else
        for env in $(ls "$HOME/.liminal/envs/"); do
            local pyver=$(_liminal-get-python-ver "$env")
            printf "  %-20s ${_LIMINAL_MUTED}(%s)${_LIMINAL_RESET}\n" "$env" "$pyver"
        done
    fi

    printf "\n"
    return 0
}

# ---------------------------------------------------------------------------
# _liminal-activate
# ---------------------------------------------------------------------------
_liminal-activate() {
    if [ -z "$1" ]; then
        echo "FAIL: No environment name specified"
        echo "Usage: liminal activate <env>"
        return 1
    fi

    if ! [ -d "$HOME/.liminal/envs/$1" ]; then
        echo "FAIL: Environment '$1' does not exist!"
        echo "  Run: liminal list"
        return 1
    fi

    local pyver=$(_liminal-get-python-ver "$1")
    pyenv shell "$pyver"

    source "$HOME/.liminal/envs/$1/bin/activate"
    return 0
}

# ---------------------------------------------------------------------------
# _liminal-create
# ---------------------------------------------------------------------------
_liminal-create() {
    local env_name=$1
    local requirements=""
    local pyver=""
    shift

    if [ -z "$env_name" ]; then
        echo "FAIL: No environment name specified"
        echo "Usage: liminal create <name> [-v <python-version>] [-r <requirements.txt>]"
        return 1
    fi

    while [ $# -gt 0 ]; do
        case "$1" in
            -r|--requirements)
                requirements="$2"
                shift 2
                ;;
            -v|--version)
                pyver="$2"
                shift 2
                ;;
            *)
                echo "FAIL: Unknown argument '$1'"
                return 1
                ;;
        esac
    done

    if [ -d "$HOME/.liminal/envs/$env_name" ]; then
        echo "FAIL: Environment '$env_name' already exists!"
        return 1
    fi

    if [ -n "$pyver" ]; then
        if ! pyenv versions --bare | grep -q "^${pyver}$"; then
            echo "FAIL: Python $pyver is not installed."
            echo "  Run: liminal install $pyver"
            return 1
        fi
        pyenv shell "$pyver"
    else
        pyver=$(pyenv version-name)
    fi

    python3 -m venv "$HOME/.liminal/envs/$env_name"
    echo "$pyver" > "$HOME/.liminal/envs/$env_name/.python-version"

    _liminal-activate "$env_name"
    python3 -m pip install --upgrade pip ipykernel ipython
    python3 -m ipykernel install --user --name "$env_name" --display-name "$env_name ($pyver)"

    if [ -n "$requirements" ]; then
        if [ ! -f "$requirements" ]; then
            echo "FAIL: Requirements file not found: $requirements"
            return 1
        fi
        python3 -m pip install -r "$requirements"
    fi

    python3 -m pip freeze > "$HOME/.liminal/envs/$env_name/requirements.txt"

    return 0
}

# ---------------------------------------------------------------------------
# _liminal-remove
# ---------------------------------------------------------------------------
_liminal-remove() {
    if [ -z "$1" ]; then
        echo "FAIL: No environment name specified"
        echo "Usage: liminal remove <env>"
        return 1
    fi

    if ! [ -d "$HOME/.liminal/envs/$1" ]; then
        echo "FAIL: Environment '$1' does not exist!"
        return 1
    fi

    if [ "$VIRTUAL_ENV" = "$HOME/.liminal/envs/$1" ]; then
        deactivate
    fi

    jupyter kernelspec remove -f "$1" 2>/dev/null
    rm -rf "$HOME/.liminal/envs/$1"

    echo "Removed environment '$1'"
    return 0
}

# ---------------------------------------------------------------------------
# _liminal-set / _liminal-switch
# ---------------------------------------------------------------------------
_liminal-set() {
    if [ -z "$1" ]; then
        echo "FAIL: No Python version specified"
        echo "Usage: liminal set <version>"
        return 1
    fi
    pyenv global "$1"
    return 0
}

_liminal-switch() {
    if [ -z "$1" ]; then
        echo "FAIL: No Python version specified"
        echo "Usage: liminal switch <version>"
        return 1
    fi
    pyenv shell "$1"
    return 0
}

# ---------------------------------------------------------------------------
# _liminal-install / _liminal-uninstall
# ---------------------------------------------------------------------------
_liminal-install() {
    if [ -z "$1" ]; then
        echo "FAIL: No Python version specified"
        echo "Usage: liminal install <version>"
        echo "  Tip: run 'liminal search' to see available versions"
        return 1
    fi
    pyenv install "$1"
    return 0
}

_liminal-uninstall() {
    if [ -z "$1" ]; then
        echo "FAIL: No Python version specified"
        echo "Usage: liminal uninstall <version>"
        return 1
    fi
    pyenv uninstall -f "$1"
    return 0
}

# ---------------------------------------------------------------------------
# _liminal-search
# ---------------------------------------------------------------------------
_liminal-search() {
    if [ -z "$1" ]; then
        printf "\nAvailable Python Versions\n"
        pyenv install --list | grep -E "^\s+[0-9]+\.[0-9]+(\.[0-9]+)?$"
    else
        printf "\nAvailable Python Versions matching '%s'\n" "$1"
        pyenv install --list | grep -E "^\s+${1}(\.[0-9]+)*$"
    fi
    printf "\n"
}

# ---------------------------------------------------------------------------
# liminal — main dispatcher
# ---------------------------------------------------------------------------
liminal() {
    case "${1:-}" in
        ""| help)       _liminal-help ;;
        list)           _liminal-list "${2:-}" ;;
        status)         _liminal-status ;;
        activate)       _liminal-activate "${2:-}" ;;
        deactivate)     deactivate ;;
        create)         _liminal-create "${2:-}" "${@:3}" ;;
        remove)         _liminal-remove "${2:-}" ;;
        install)        _liminal-install "${2:-}" ;;
        uninstall)      _liminal-uninstall "${2:-}" ;;
        search)         _liminal-search "${2:-}" ;;
        set)            _liminal-set "${2:-}" ;;
        switch)         _liminal-switch "${2:-}" ;;
        *)
            echo "FAIL: Unknown command '$1'"
            echo "  Run: liminal help"
            return 1
            ;;
    esac
    return 0
}
