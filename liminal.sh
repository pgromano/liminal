liminal-init-check() {
    # ensure that pyenv is properly set up for shell
    eval "$(pyenv init --path)"

    # make sure a base liminal directory exists
    if ! [ -d $HOME/.liminal ]; then
        echo "Initializing environment repo at $HOME/.liminal"
        mkdir $HOME/.liminal
    fi

    # make sure that a python3 specific folder exists
    pyver=$(python3 --version)
    if ! [ -d "$HOME/.liminal/$pyver" ]; then
        echo "Initializing version folder at $HOME/.liminal for $pyver"
        mkdir "$HOME/.liminal/$pyver"
    fi
    return 0
}

liminal-help() {
    echo "\nUsage:\n  liminal <command> [options]"
    echo "\nCommands:"
    echo "    help           Show this help message and exit"
    echo "    list           List all existing virtual environments"
    echo "    activate       Activates an existing virtual environment"
    echo "    deactivate     Deactivates current virtual environment"
    echo "    create         Create a new virtual environment"
    echo "    remove         Remove an existing virtual environment"
    echo "    install        Install a new Python version"
    echo "    uninstall      Uninstall an existing Python version"
    echo "    switch         Switch between existing Python versions"
    echo "    status         Display info about the current active env and Python version"
}

liminal-status() {
    echo "$(python3 --version)"
    echo "    Python Path: $(which python3)"
    if [ -z $VIRTUAL_ENV ];then
        echo "    Virtual Environment: None"
    else
        echo "    Virtual Environment: $VIRTUAL_ENV"
    fi
}

liminal-list-env() {
    pyver=$(python3 --version)
    echo "\n$pyver: Available Virtual Environments"
    if [ -d "$HOME/.liminal/$pyver/" ];then
        for value in $(ls "$HOME/.liminal/$pyver"); do
            echo "  $value"
        done
    else
        echo "  No virtual environments found!"
    fi
        echo ""
    return 0
}

liminal-list-ver() {

    if [ -z $1 ]; then
        echo "\nAvailable Python Versions"
        pyenv install --list | grep -E "^  [0-9](\.[0-9]{1,2})+$"
    elif [ "$1" = "--all-sources" ];then
        echo "\nAvailable Python Versions"
        pyenv install --list
    elif [ "$1" = "--installed" ];then
        echo "\nPython Versions Installed"
        pyenv versions
    else
        echo "\nAvailable Python Versions"
        pyenv install --list | grep -E "^  ${1}(\.[0-9]{1,2})+$"
    fi
    return 0
}

liminal-list() {
    if [ -z $1 ];then
        liminal-list-env
    elif [ "$1" = "env" ];then
        liminal-list-env
    elif [ "$1" = "ver" ];then
        liminal-list-ver $2
    else
        echo "FAIL: Unable to interpret argument list $1!"
        return 1
    fi
}

liminal-activate() {

    pyver=$(python3 --version)
    if ! [ -d "$HOME/.liminal/$pyver/$1" ]; then
        echo "FAIL: Environment $1 does not exists!"
        return 1
    fi
    source "$HOME/.liminal/$pyver/$1/bin/activate"
    return 0
}

liminal-deactivate() {
    deactivate
    return 0
}

liminal-create() {

    pyver=$(python3 --version)
    if [ -d "$HOME/.liminal/$pyver/$1" ]; then
        echo "FAIL: Environment $1 already exists!"
        return 1
    fi
    
    python3 -m venv "$HOME/.liminal/$pyver/$1"
    source "$HOME/.liminal/$pyver/$1/bin/activate"
    python3 -m pip install --upgrade pip ipykernel ipython
    python3 -m ipykernel install --user --name $1 --display-name "$1 ($pyver)"
}

liminal-remove() {

    pyver=$(python3 --version)
    if ! [ -d "$HOME/.liminal/$pyver/$1" ]; then
        echo "FAIL: Environment $1 does not exist!"
        return 1
    fi
    rm -rf "$HOME/.liminal/$pyver/$1"
    return 0
}

liminal-install() {
    pyenv install $1
    mkdir "$HOME/.liminal/Python $1"
    return 0
}

liminal-uninstall() {
    pyenv uninstall $1
    rm -rf "$HOME/.liminal/Python $1"
    return 0
}

liminal-switch() {
    pyenv global $1
    return 0
}

liminal() {
    if [ -z $1 ];then
        liminal-help
    elif [ "$1" = "help" ]; then
        liminal-help
    elif [ "$1" = "list" ]; then
        liminal-list $2 $3
    elif [ "$1" = "activate" ]; then
        liminal-activate $2
    elif [ "$1" = "deactivate" ]; then
        deactivate
    elif [ "$1" = "create" ]; then
        liminal-create $2
    elif [ "$1" = "remove" ]; then
        liminal-remove $2
    elif [ "$1" = "install" ]; then
        liminal-install $2
    elif [ "$1" = "uninstall" ]; then
        liminal-uninstall $2
    elif [ "$1" = "switch" ]; then
        liminal-switch $2
    elif [ "$1" = "status" ]; then
        liminal-status
    else
        echo "FAIL: Unable to interpret liminal method $1"
        return 1
    fi
    return 0
}
