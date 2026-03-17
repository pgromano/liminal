_liminal-get-python-ver() {
    echo $(cat "$HOME/.liminal/envs/$1/.python-version" 2>/dev/null || echo "unknown")
}

# autocomplete
autoload -U +X bashcompinit && bashcompinit
_liminal_completions() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"

    local commands="help list status activate deactivate create remove install uninstall search switch set"

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
            COMPREPLY=($(compgen -W "$commands" -- "$cur"))
            ;;
    esac
}

complete -F _liminal_completions liminal

_liminal-help() {
  echo "\nUsage:\n liminal <command> [options]"
  echo "\nCommands: "
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

_liminal-status() {
    local pyver=$(python3 --version 2>&1)
    local pypath=$(which python3)
    local env=${VIRTUAL_ENV:-None}

    local reset='\033[0m'
    local bold='\033[1m'
    local muted='\033[2m'
    local teal='\033[38;5;115m'
    local blue='\033[38;5;027m'
    local yellow='\033[38;5;178m'

    printf "\n${bold}${teal}󰊠 Liminal Status${reset}\n\n"
    printf "  ${blue}${bold} Python:      ${reset}${bold}%s${reset} ${muted}%s${reset}\n" "$pyver" "($pypath)"
    printf "  ${yellow}${bold}󰌪 Environment: ${reset}${bold}%s${reset}\n" "$env"
    printf "\n"
}

_liminal-list() {
    printf "\nAvailable Environments\n"

    if [ ! -d "$HOME/.liminal/envs" ] || [ -z "$(ls "$HOME/.liminal/envs/" 2>/dev/null)" ]; then
        printf "  None\n"
    else
        for env in $(ls "$HOME/.liminal/envs/"); do
            local pyver=$(_liminal-get-python-ver $env)
            printf "  %-20s ${muted}(%s)${reset}\n" "$env" "$pyver"
        done
    fi

    printf "\n"
    return 0
}

_liminal-activate() {
    if ! [ -d "$HOME/.liminal/envs/$1" ]; then
        echo "FAIL: Environment $1 does not exist!"
        return 1
    fi

    local pyver=$(_liminal-get-python-ver $1)
    pyenv shell $pyver

    source "$HOME/.liminal/envs/$1/bin/activate"
    return 0
}

_liminal-create() {
    local env_name=$1
    local requirements=""
    local pyver=""
    shift

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
                echo "FAIL: Unknown argument $1"
                return 1
                ;;
        esac
    done

    if [ -d "$HOME/.liminal/envs/$env_name" ]; then
        echo "FAIL: Environment $env_name already exists!"
        return 1
    fi

    if [ -n "$pyver" ]; then
        if ! pyenv versions --bare | grep -q "^${pyver}$"; then
            echo "FAIL: Python $pyver is not installed. Run: liminal install $pyver"
            return 1
        fi
        pyenv shell $pyver
    else
        pyver=$(pyenv version-name)
    fi

    python3 -m venv "$HOME/.liminal/envs/$env_name"
    echo "$pyver" > "$HOME/.liminal/envs/$env_name/.python-version"

    _liminal-activate $env_name
    python3 -m pip install --upgrade pip ipykernel ipython
    python3 -m ipykernel install --user --name $env_name --display-name "$env_name ($pyver)"

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

_liminal-remove() {
    if ! [ -d "$HOME/.liminal/envs/$1" ]; then
        echo "FAIL: Environment $1 does not exist!"
        return 1
    fi

    if [ "$VIRTUAL_ENV" = "$HOME/.liminal/envs/$1" ]; then
        deactivate
    fi

    jupyter kernelspec remove -f $1 2>/dev/null
    rm -rf "$HOME/.liminal/envs/$1"

    echo "Removed environment $1"
    return 0
}

_liminal-set() {
    pyenv global $1
    return 0
}

_liminal-switch() {
    pyenv shell $1
    return 0
}

_liminal-install() {
    if [ -z "$1" ]; then
        echo "FAIL: No Python version specified"
        echo "Usage: liminal install <version>"
        return 1
    fi

    pyenv install $1
    return 0
}

_liminal-uninstall() {
    if [ -z "$1" ]; then
        echo "FAIL: No Python version specified"
        echo "Usage: liminal uninstall <version>"
        return 1
    fi

    pyenv uninstall -f $1
    return 0
}

_liminal-search() {
    if [ -z "$1" ]; then
        printf "\nAvailable Python Versions\n"
        pyenv install --list | grep -E "^\s+[0-9]+\.[0-9]+(\.[0-9]+)?$"
    else
        printf "\nAvailable Python Versions matching $1\n"
        pyenv install --list | grep -E "^\s+${1}(\.[0-9]+)*$"
    fi
    printf "\n"
}

liminal() {
    if [ -z $1 ]; then
        _liminal-help
    elif [ "$1" = "help" ]; then
        _liminal-help
    elif [ "$1" = "list" ]; then
        _liminal-list $2
    elif [ "$1" = "status" ]; then
        _liminal-status
    elif [ "$1" = "activate" ]; then
        _liminal-activate $2
    elif [ "$1" = "deactivate" ]; then
        deactivate
    elif [ "$1" = "create" ]; then
        _liminal-create $2 "${@:3}"
    elif [ "$1" = "remove" ]; then
        _liminal-remove $2
    elif [ "$1" = "install" ]; then
        _liminal-install $2
    elif [ "$1" = "uninstall" ]; then
        _liminal-uninstall $2
    elif [ "$1" = "search" ]; then
        _liminal-search $2
    elif [ "$1" = "set" ]; then
        _liminal-set $2
    elif [ "$1" = "switch" ]; then
        _liminal-switch $2
    else
        echo "FAIL: Unable to interpret liminal method $1"
        return 1
    fi
    return 0
}
