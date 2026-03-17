_liminal-get-python-ver() {
    echo $(cat "$HOME/.liminal/envs/$1/.python-version" 2>/dev/null || echo "unknown")
}

liminal-help() {
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

liminal-status() {
    local pyver=$(python3 --version 2>&1)
    local pypath=$(which python3)
    local env=${VIRTUAL_ENV:-None}

    # colors
    local reset='\033[0m'
    local bold='\033[1m'
    local muted='\033[2m'
    local teal='\033[38;5;115m'
    local blue='\033[38;5;027m'
    local yellow='\033[38;5;178m'

    printf "\n${bold}${teal}󰊠 Liminal Status${reset}\n\n"
    printf "  ${blue}${bold} Python:      ${reset}${bold}%s${reset} ${muted}%s${reset}\n" "$pyver" "($pypath)"
    printf "  ${yellow}${bold}󰌪 Environment: ${reset}${bold}%s${reset}\n" "$env"
    printf "\n"
}

liminal-list() {
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

liminal-activate() {

  if ! [ -d "$HOME/.liminal/envs/$1" ]; then
    echo "FAIL: Environment $1 does not exist!"
    return 1
  fi

  # figure out which python version the env requires and set local env to be current version
  local pyver=$(_liminal-get-python-ver $1)
  liminal-switch $pyver

  # activate
  source "$HOME/.liminal/$1/bin/activate"
  return 0
}

liminal-create() {
    local env_name=$1
    local requirements=""
    local pyver=""
    shift

    # parse optional arguments
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

    # make sure environment doesn't already exist
    if [ -d "$HOME/.liminal/envs/$env_name" ]; then
        echo "FAIL: Environment $env_name already exists!"
        return 1
    fi

    # set python version — use specified or fall back to global default
    if [ -n "$pyver" ]; then
        if ! pyenv versions --bare | grep -q "^${pyver}$"; then
            echo "FAIL: Python $pyver is not installed. Run: liminal install $pyver"
            return 1
        fi
        pyenv shell $pyver
    else
        pyver=$(pyenv version-name)
    fi

    # create environment and write .python-version
    python3 -m venv "$HOME/.liminal/envs/$env_name"
    echo "$pyver" > "$HOME/.liminal/envs/$env_name/.python-version"

    # activate and install basic dependencies
    liminal-activate $env_name
    python3 -m pip install --upgrade pip ipykernel ipython
    python3 -m ipykernel install --user --name $env_name --display-name "$env_name ($pyver)"

    # install requirements if provided
    if [ -n "$requirements" ]; then
        if [ ! -f "$requirements" ]; then
            echo "FAIL: Requirements file not found: $requirements"
            return 1
        fi
        python3 -m pip install -r "$requirements"
    fi

    return 0
}

liminal-remove() {

  # make sure environment exists
  if ! [ -d "$HOME/.liminal/$1" ]; then
      echo "FAIL: Environment $1 does not exist!"
      return 1
  fi
  
  # deactivate if currently active
  if [ "$VIRTUAL_ENV" = "$HOME/.liminal/envs/$1" ]; then
      deactivate
  fi

  # remove ipykernel
  jupyter kernelspec remove -f $1 2>/dev/null

  # remove environment
  rm -rf "$HOME/.liminal/envs/$1"

  echo "Removed environment $1"
  return 0
}

liminal-set() {
  pyenv global $1
  return 0
}

liminal-switch() {
  pyenv local $1
  return 0
}

liminal-install() {
    if [ -z "$1" ]; then
        echo "FAIL: No Python version specified"
        echo "Usage: liminal install <version>"
        return 1
    fi

    pyenv install $1
    return 0
}

liminal-uninstall() {
    if [ -z "$1" ]; then
        echo "FAIL: No Python version specified"
        echo "Usage: liminal uninstall <version>"
        return 1
    fi

    pyenv uninstall -f $1
    return 0
}

liminal-search() {
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
  if [ -z $1 ];then
    liminal-help
  elif [ "$1" = "help" ];then
    liminal-help
  elif [ "$1" = "list" ];then
    liminal-list $2
  elif [ "$1" = "status" ];then
    liminal-status
  elif [ "$1" = "activate" ]; then
    liminal-activate $2
  elif [ "$1" = "deactivate" ]; then
    deactivate
  elif [ "$1" = "create" ]; then
    liminal-create $2 "${@:3}"
  elif [ "$1" = "remove" ]; then
    liminal-remove $2
  elif [ "$1" = "install" ]; then
    liminal-install $2
  elif [ "$1" = "uninstall" ]; then
    liminal-uninstall $2
  elif [ "$1" = "search" ]; then
    liminal-search $2
  elif [ "$1" = "set" ]; then
    liminal-set $2
  elif [ "$1" = "switch" ]; then
    liminal-switch $2
  else
    echo "FAIL: Unable to interpret liminal method $1"
    return 1
  fi
  return 0
}
