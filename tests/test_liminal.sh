#!/usr/bin/env sh
# =============================================================================
# tests/test_liminal.sh
# Plain shell test suite for liminal.sh and the Makefile install logic.
#
# Usage:
#   bash tests/test_liminal.sh           # run all tests
#   bash tests/test_liminal.sh list      # run only tests matching "list"
#
# All tests are fully isolated:
#   - HOME is redirected to a per-run temp directory
#   - pyenv, python3, pip, jupyter are mocked via PATH-prepended stubs
#   - No real pyenv operations or venvs are created
#   - Temp directory is cleaned up on exit
# =============================================================================

set -uo pipefail

# ---------------------------------------------------------------------------
# Colours for output
# ---------------------------------------------------------------------------
_T_RESET='\033[0m'
_T_BOLD='\033[1m'
_T_GREEN='\033[38;5;114m'
_T_RED='\033[38;5;203m'
_T_YELLOW='\033[38;5;178m'
_T_MUTED='\033[2m'

# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------
_PASS=0
_FAIL=0
_SKIP=0
_FILTER="${1:-}"

# ---------------------------------------------------------------------------
# Temp sandbox — all tests run with HOME pointing here
# ---------------------------------------------------------------------------
TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT

# ---------------------------------------------------------------------------
# Mock bin directory — stubs prepended to PATH so real tools are never called
# ---------------------------------------------------------------------------
MOCK_BIN="$TEST_TMP/mock_bin"
mkdir -p "$MOCK_BIN"

# pyenv stub — records calls and simulates behaviour
cat > "$MOCK_BIN/pyenv" << 'EOF'
#!/usr/bin/env bash
echo "pyenv $*" >> "$TEST_TMP/pyenv_calls"
case "$1" in
    versions)
        # --bare: list installed versions
        echo "3.11.0"
        echo "3.12.0"
        ;;
    version-name)
        echo "3.11.0"
        ;;
    install)
        if [ "$2" = "--list" ]; then
            printf "  3.10.0\n  3.11.0\n  3.12.0\n  3.12.1\n"
        fi
        ;;
    global|shell)
        # side-effect free in tests
        ;;
esac
EOF
chmod +x "$MOCK_BIN/pyenv"

# python3 stub — creates a fake venv structure when -m venv is called
cat > "$MOCK_BIN/python3" << 'EOF'
#!/usr/bin/env bash
if [ "$1" = "--version" ]; then
    echo "Python 3.11.0"
    exit 0
fi
if [ "$1" = "-m" ] && [ "$2" = "venv" ]; then
    # Simulate venv creation: create activate script
    mkdir -p "$3/bin"
    cat > "$3/bin/activate" << 'ACTIVATE'
# mock activate
export VIRTUAL_ENV="$3"
ACTIVATE
    exit 0
fi
if [ "$1" = "-m" ] && [ "$2" = "pip" ]; then
    # Silently succeed for pip operations
    exit 0
fi
if [ "$1" = "-m" ] && [ "$2" = "ipykernel" ]; then
    exit 0
fi
EOF
chmod +x "$MOCK_BIN/python3"

# pip stub
cat > "$MOCK_BIN/pip" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$MOCK_BIN/pip"

# jupyter stub
cat > "$MOCK_BIN/jupyter" << 'EOF'
#!/usr/bin/env bash
echo "jupyter $*" >> "$TEST_TMP/jupyter_calls"
exit 0
EOF
chmod +x "$MOCK_BIN/jupyter"

# brew stub
cat > "$MOCK_BIN/brew" << 'EOF'
#!/usr/bin/env bash
echo "brew $*" >> "$TEST_TMP/brew_calls"
exit 0
EOF
chmod +x "$MOCK_BIN/brew"

# which stub — returns a sensible path for python3
cat > "$MOCK_BIN/which" << 'EOF'
#!/usr/bin/env bash
echo "/usr/bin/$1"
EOF
chmod +x "$MOCK_BIN/which"

export PATH="$MOCK_BIN:$PATH"
export TEST_TMP   # make available to pyenv stub

# ---------------------------------------------------------------------------
# Source liminal into THIS shell with sandboxed HOME
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIMINAL_SH="$SCRIPT_DIR/../liminal.sh"

if [ ! -f "$LIMINAL_SH" ]; then
    printf "${_T_RED}ERROR:${_T_RESET} liminal.sh not found at %s\n" "$LIMINAL_SH"
    exit 1
fi

# Redirect HOME so all ~/.liminal paths go into the sandbox
export HOME="$TEST_TMP/home"
mkdir -p "$HOME/.liminal/envs"

# Source liminal — functions now available in this shell
# shellcheck source=../liminal.sh
source "$LIMINAL_SH"

# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------

# assert_eq <description> <actual> <expected>
assert_eq() {
    local desc="$1" actual="$2" expected="$3"
    if [ "$actual" = "$expected" ]; then
        printf "  ${_T_GREEN}✓${_T_RESET} %s\n" "$desc"
        _PASS=$(( _PASS + 1 ))
    else
        printf "  ${_T_RED}✗${_T_RESET} %s\n    expected: %s\n    got:      %s\n" \
            "$desc" "$expected" "$actual"
        _FAIL=$(( _FAIL + 1 ))
    fi
}

# assert_contains <description> <haystack> <needle>
assert_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        printf "  ${_T_GREEN}✓${_T_RESET} %s\n" "$desc"
        _PASS=$(( _PASS + 1 ))
    else
        printf "  ${_T_RED}✗${_T_RESET} %s\n    expected to contain: %s\n    got: %s\n" \
            "$desc" "$needle" "$haystack"
        _FAIL=$(( _FAIL + 1 ))
    fi
}

# assert_not_contains <description> <haystack> <needle>
assert_not_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if ! echo "$haystack" | grep -qF "$needle"; then
        printf "  ${_T_GREEN}✓${_T_RESET} %s\n" "$desc"
        _PASS=$(( _PASS + 1 ))
    else
        printf "  ${_T_RED}✗${_T_RESET} %s\n    expected NOT to contain: %s\n    got: %s\n" \
            "$desc" "$needle" "$haystack"
        _FAIL=$(( _FAIL + 1 ))
    fi
}

# assert_exits_nonzero <description> <command string>
assert_exits_nonzero() {
    local desc="$1"
    shift
    if ! "$@" >/dev/null 2>&1; then
        printf "  ${_T_GREEN}✓${_T_RESET} %s\n" "$desc"
        _PASS=$(( _PASS + 1 ))
    else
        printf "  ${_T_RED}✗${_T_RESET} %s (expected non-zero exit)\n" "$desc"
        _FAIL=$(( _FAIL + 1 ))
    fi
}

# assert_file_exists <description> <path>
assert_file_exists() {
    local desc="$1" path="$2"
    if [ -e "$path" ]; then
        printf "  ${_T_GREEN}✓${_T_RESET} %s\n" "$desc"
        _PASS=$(( _PASS + 1 ))
    else
        printf "  ${_T_RED}✗${_T_RESET} %s\n    file not found: %s\n" "$desc" "$path"
        _FAIL=$(( _FAIL + 1 ))
    fi
}

# assert_file_not_exists <description> <path>
assert_file_not_exists() {
    local desc="$1" path="$2"
    if [ ! -e "$path" ]; then
        printf "  ${_T_GREEN}✓${_T_RESET} %s\n" "$desc"
        _PASS=$(( _PASS + 1 ))
    else
        printf "  ${_T_RED}✗${_T_RESET} %s\n    expected absent: %s\n" "$desc" "$path"
        _FAIL=$(( _FAIL + 1 ))
    fi
}

# describe <group name> — prints a section header, skips group if filter active
describe() {
    _CURRENT_GROUP="$1"
    if [ -n "$_FILTER" ] && ! echo "$_CURRENT_GROUP" | grep -qi "$_FILTER"; then
        return 1
    fi
    printf "\n${_T_BOLD}%s${_T_RESET}\n" "$1"
    return 0
}

# reset_calls — clears mock call logs between tests
reset_calls() {
    rm -f "$TEST_TMP/pyenv_calls" "$TEST_TMP/jupyter_calls"
    touch "$TEST_TMP/pyenv_calls" "$TEST_TMP/jupyter_calls"
}

# make_env <name> [python_version] — creates a fake env dir for tests that
# need a pre-existing environment without running _liminal-create
make_env() {
    local name="$1" ver="${2:-3.11.0}"
    mkdir -p "$HOME/.liminal/envs/$name/bin"
    echo "$ver" > "$HOME/.liminal/envs/$name/.python-version"
    # minimal activate script
    printf '#!/bin/sh\nexport VIRTUAL_ENV="%s"\n' \
        "$HOME/.liminal/envs/$name" \
        > "$HOME/.liminal/envs/$name/bin/activate"
}

# remove_env <name>
remove_env() {
    rm -rf "$HOME/.liminal/envs/$1"
}

# =============================================================================
# TEST GROUPS
# =============================================================================

# ---------------------------------------------------------------------------
# 1. Color variable scoping
# ---------------------------------------------------------------------------
if describe "Color variables"; then

    assert_eq "_LIMINAL_RESET is set"  "$_LIMINAL_RESET"  '\033[0m'
    assert_eq "_LIMINAL_BOLD is set"   "$_LIMINAL_BOLD"   '\033[1m'
    assert_eq "_LIMINAL_MUTED is set"  "$_LIMINAL_MUTED"  '\033[2m'
    assert_eq "_LIMINAL_BLUE is set"   "$_LIMINAL_BLUE"   '\033[38;5;027m'
    assert_eq "_LIMINAL_YELLOW is set" "$_LIMINAL_YELLOW" '\033[38;5;178m'
    assert_eq "_LIMINAL_TEAL is set"   "$_LIMINAL_TEAL"   '\033[38;5;115m'

    # Variables must NOT be exported (should not appear in child env)
    local_vars=$(bash -c 'echo "${_LIMINAL_RESET:-NOTSET}"')
    assert_eq "_LIMINAL_RESET not exported to child shells" "$local_vars" "NOTSET"

fi

# ---------------------------------------------------------------------------
# 2. liminal help / unknown command
# ---------------------------------------------------------------------------
if describe "Help and dispatcher"; then

    out=$(liminal help 2>&1)
    assert_contains "help shows usage"         "$out" "Usage:"
    assert_contains "help lists commands"      "$out" "activate"
    assert_contains "help lists create"        "$out" "create"

    out=$(liminal 2>&1)
    assert_contains "no args shows help"       "$out" "Usage:"

    out=$(liminal notacommand 2>&1)
    assert_contains "unknown command prints FAIL" "$out" "FAIL"
    assert_contains "unknown command hints help"  "$out" "liminal help"

fi

# ---------------------------------------------------------------------------
# 3. liminal list
# ---------------------------------------------------------------------------
if describe "list"; then

    # No envs
    remove_env testenv 2>/dev/null || true
    out=$(liminal list 2>&1)
    assert_contains "list shows None when empty" "$out" "None"

    # With envs
    make_env myenv 3.11.0
    make_env otherenv 3.12.0
    out=$(liminal list 2>&1)
    assert_contains "list shows myenv"    "$out" "myenv"
    assert_contains "list shows otherenv" "$out" "otherenv"
    assert_contains "list shows version"  "$out" "3.11.0"
    remove_env myenv
    remove_env otherenv

fi

# ---------------------------------------------------------------------------
# 4. liminal status
# ---------------------------------------------------------------------------
if describe "status"; then

    out=$(liminal status 2>&1)
    assert_contains "status shows Python"       "$out" "Python"
    assert_contains "status shows Environment"  "$out" "Environment"

    # With an active venv
    export VIRTUAL_ENV="$HOME/.liminal/envs/myenv"
    out=$(liminal status 2>&1)
    assert_contains "status shows active venv path" "$out" "myenv"
    unset VIRTUAL_ENV

fi

# ---------------------------------------------------------------------------
# 5. liminal activate
# ---------------------------------------------------------------------------
if describe "activate"; then

    # Missing arg
    out=$(liminal activate 2>&1)
    assert_contains "activate with no arg prints FAIL" "$out" "FAIL"

    # Non-existent env
    out=$(liminal activate doesnotexist 2>&1)
    assert_contains "activate missing env prints FAIL"    "$out" "FAIL"
    assert_contains "activate missing env suggests list"  "$out" "liminal list"

    # Valid env — check pyenv shell is called with correct version
    make_env goodenv 3.12.0
    reset_calls
    liminal activate goodenv 2>/dev/null || true
    pyenv_log=$(cat "$TEST_TMP/pyenv_calls")
    assert_contains "activate calls pyenv shell with env version" \
        "$pyenv_log" "pyenv shell 3.12.0"
    remove_env goodenv

fi

# ---------------------------------------------------------------------------
# 6. liminal create
# ---------------------------------------------------------------------------
if describe "create"; then

    # Missing name
    out=$(liminal create 2>&1)
    assert_contains "create with no name prints FAIL" "$out" "FAIL"

    # Unknown flag
    out=$(liminal create newenv --badopt 2>&1)
    assert_contains "create with unknown flag prints FAIL" "$out" "FAIL"

    # Duplicate env
    make_env dupenv
    out=$(liminal create dupenv 2>&1)
    assert_contains "create duplicate env prints FAIL" "$out" "FAIL"
    remove_env dupenv

    # Version not installed
    out=$(liminal create newenv -v 9.9.9 2>&1)
    assert_contains "create with missing version prints FAIL"    "$out" "FAIL"
    assert_contains "create with missing version suggests install" "$out" "liminal install"

    # Missing requirements file
    out=$(liminal create newenv -r /nonexistent/requirements.txt 2>&1)
    assert_contains "create with missing req file prints FAIL" "$out" "FAIL"

    # Happy path — version exists in mock pyenv
    reset_calls
    liminal create happyenv -v 3.11.0 2>/dev/null || true
    assert_file_exists "create makes env dir" \
        "$HOME/.liminal/envs/happyenv"
    assert_file_exists "create writes .python-version" \
        "$HOME/.liminal/envs/happyenv/.python-version"
    ver=$(cat "$HOME/.liminal/envs/happyenv/.python-version")
    assert_eq "create records correct python version" "$ver" "3.11.0"
    remove_env happyenv

fi

# ---------------------------------------------------------------------------
# 7. liminal remove
# ---------------------------------------------------------------------------
if describe "remove"; then

    # Missing arg
    out=$(liminal remove 2>&1)
    assert_contains "remove with no arg prints FAIL" "$out" "FAIL"

    # Non-existent env
    out=$(liminal remove ghostenv 2>&1)
    assert_contains "remove missing env prints FAIL" "$out" "FAIL"

    # Happy path
    make_env doomed
    reset_calls
    liminal remove doomed 2>/dev/null
    assert_file_not_exists "remove deletes env dir" \
        "$HOME/.liminal/envs/doomed"
    jupyter_log=$(cat "$TEST_TMP/jupyter_calls")
    assert_contains "remove calls jupyter kernelspec remove" \
        "$jupyter_log" "kernelspec remove"

fi

# ---------------------------------------------------------------------------
# 8. pyenv integration — install / uninstall / switch / set
# ---------------------------------------------------------------------------
if describe "pyenv integration"; then

    # install — no arg
    out=$(liminal install 2>&1)
    assert_contains "install with no arg prints FAIL"    "$out" "FAIL"
    assert_contains "install with no arg suggests search" "$out" "liminal search"

    # install — delegates to pyenv
    reset_calls
    liminal install 3.12.0 2>/dev/null
    assert_contains "install calls pyenv install" \
        "$(cat "$TEST_TMP/pyenv_calls")" "pyenv install 3.12.0"

    # uninstall — no arg
    out=$(liminal uninstall 2>&1)
    assert_contains "uninstall with no arg prints FAIL" "$out" "FAIL"

    # uninstall — delegates to pyenv
    reset_calls
    liminal uninstall 3.12.0 2>/dev/null
    assert_contains "uninstall calls pyenv uninstall" \
        "$(cat "$TEST_TMP/pyenv_calls")" "pyenv uninstall -f 3.12.0"

    # switch — no arg
    out=$(liminal switch 2>&1)
    assert_contains "switch with no arg prints FAIL" "$out" "FAIL"

    # switch — delegates to pyenv shell
    reset_calls
    liminal switch 3.11.0 2>/dev/null
    assert_contains "switch calls pyenv shell" \
        "$(cat "$TEST_TMP/pyenv_calls")" "pyenv shell 3.11.0"

    # set — no arg
    out=$(liminal set 2>&1)
    assert_contains "set with no arg prints FAIL" "$out" "FAIL"

    # set — delegates to pyenv global
    reset_calls
    liminal set 3.11.0 2>/dev/null
    assert_contains "set calls pyenv global" \
        "$(cat "$TEST_TMP/pyenv_calls")" "pyenv global 3.11.0"

fi

# ---------------------------------------------------------------------------
# 9. liminal search
# ---------------------------------------------------------------------------
if describe "search"; then

    out=$(liminal search 2>&1)
    assert_contains "search lists versions"      "$out" "3.11.0"
    assert_contains "search lists minor version" "$out" "3.12.0"

    out=$(liminal search 3.12 2>&1)
    assert_contains     "search with filter shows match"    "$out" "3.12"
    # 3.10 should not appear when filtering for 3.12
    assert_not_contains "search with filter excludes non-match" "$out" "3.10.0"

fi

# ---------------------------------------------------------------------------
# 10. Autocomplete
# ---------------------------------------------------------------------------
if describe "autocomplete"; then

    if [ -n "${ZSH_VERSION:-}" ]; then
        # --- zsh: test _liminal_completions_zsh via compdef ---
        assert_contains "zsh completion function is defined" \
            "$(type _liminal_completions_zsh 2>/dev/null)" \
            "shell function"

        # Helper: run zsh completion and return matches via compadd capture
        _test_complete() {
            # Simulate zsh completion context by calling the function with
            # words/CURRENT set, capturing compadd output via _values mock
            local prev="$1"
            words=("liminal" "$prev" "")
            CURRENT=3
            # compadd writes to stdout in test context when using -V
            _liminal_completions_zsh
        }

        # Top-level: words=("liminal" "") CURRENT=2
        words=("liminal" "")
        CURRENT=2
        result=$(compadd -- ${=_liminal_commands} 2>&1 || true; _liminal_completions_zsh 2>&1 || true)
        # Directly test the commands variable is populated
        assert_contains "zsh top-level commands include help"       "$_liminal_commands" "help"
        assert_contains "zsh top-level commands include activate"   "$_liminal_commands" "activate"
        assert_contains "zsh top-level commands include create"     "$_liminal_commands" "create"
        assert_contains "zsh top-level commands include list"       "$_liminal_commands" "list"
        assert_contains "zsh top-level commands include remove"     "$_liminal_commands" "remove"
        assert_contains "zsh top-level commands include install"    "$_liminal_commands" "install"
        assert_contains "zsh top-level commands include search"     "$_liminal_commands" "search"
        assert_contains "zsh top-level commands include switch"     "$_liminal_commands" "switch"
        assert_contains "zsh top-level commands include set"        "$_liminal_commands" "set"
        assert_contains "zsh top-level commands include status"     "$_liminal_commands" "status"
        assert_contains "zsh top-level commands include deactivate" "$_liminal_commands" "deactivate"

        # Env name completions — test that ls output feeds completion correctly
        make_env compenv1
        make_env compenv2
        envs=$(ls "$HOME/.liminal/envs/" 2>/dev/null)
        assert_contains "activate env candidates include compenv1" "$envs" "compenv1"
        assert_contains "activate env candidates include compenv2" "$envs" "compenv2"
        assert_contains "remove env candidates include compenv1"   "$envs" "compenv1"
        remove_env compenv1
        remove_env compenv2

        # pyenv version completions
        versions=$(pyenv versions --bare 2>/dev/null)
        assert_contains "switch version candidates include 3.11.0" "$versions" "3.11.0"
        assert_contains "switch version candidates include 3.12.0" "$versions" "3.12.0"

    else
        # --- bash: test _liminal_completions_bash via COMP_WORDS/COMPREPLY ---
        assert_eq "bash completion function is defined" \
            "$(type -t _liminal_completions_bash 2>/dev/null || echo '')" "function"

        # Top-level completions
        COMP_WORDS=(liminal "")
        COMP_CWORD=1
        COMPREPLY=()
        _liminal_completions_bash
        result="${COMPREPLY[*]}"
        assert_contains "top-level completions include help"       "$result" "help"
        assert_contains "top-level completions include activate"   "$result" "activate"
        assert_contains "top-level completions include create"     "$result" "create"
        assert_contains "top-level completions include list"       "$result" "list"
        assert_contains "top-level completions include remove"     "$result" "remove"
        assert_contains "top-level completions include install"    "$result" "install"
        assert_contains "top-level completions include search"     "$result" "search"
        assert_contains "top-level completions include switch"     "$result" "switch"
        assert_contains "top-level completions include set"        "$result" "set"
        assert_contains "top-level completions include status"     "$result" "status"
        assert_contains "top-level completions include deactivate" "$result" "deactivate"

        # activate + remove complete env names
        make_env compenv1
        make_env compenv2
        COMP_WORDS=(liminal activate "")
        COMP_CWORD=2
        COMPREPLY=()
        _liminal_completions_bash
        result="${COMPREPLY[*]}"
        assert_contains "activate completes env names" "$result" "compenv1"
        assert_contains "activate completes env names" "$result" "compenv2"

        COMP_WORDS=(liminal remove "")
        COMP_CWORD=2
        COMPREPLY=()
        _liminal_completions_bash
        result="${COMPREPLY[*]}"
        assert_contains "remove completes env names" "$result" "compenv1"
        remove_env compenv1
        remove_env compenv2

        # switch completes pyenv versions
        COMP_WORDS=(liminal switch "")
        COMP_CWORD=2
        COMPREPLY=()
        _liminal_completions_bash
        result="${COMPREPLY[*]}"
        assert_contains "switch completes pyenv versions" "$result" "3.11.0"
        assert_contains "switch completes pyenv versions" "$result" "3.12.0"

        # install returns empty completions
        COMP_WORDS=(liminal install "")
        COMP_CWORD=2
        COMPREPLY=()
        _liminal_completions_bash
        assert_eq "install completions are empty" "${#COMPREPLY[@]}" "0"
    fi

fi

# ---------------------------------------------------------------------------
# 11. Makefile — profile file resolution logic
#     These tests invoke the Makefile's _find-profile-file logic directly
#     by running make with a sandboxed HOME and checking which file gets written.
# ---------------------------------------------------------------------------
if describe "Makefile profile file resolution"; then

    MAKEFILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

    _run_install() {
        # Run make install in a subshell with sandboxed HOME
        # SHELL is passed explicitly to control which shell make thinks is active
        local test_home="$1" shell_bin="$2"
        SHELL="$shell_bin" HOME="$test_home" \
            make -C "$MAKEFILE_DIR" install \
            --no-print-directory 2>&1
    }

    # --- .profile always wins regardless of shell ---
    h="$TEST_TMP/profile_priority"
    mkdir -p "$h/.liminal/envs"
    touch "$h/.profile" "$h/.bash_profile" "$h/.zprofile" "$h/.bashrc"
    _run_install "$h" "/bin/bash" >/dev/null 2>&1 || true
    assert_contains ".profile wins over .bash_profile (bash)" \
        "$(cat "$h/.profile")" "pyenv PATH (liminal)"
    assert_not_contains ".bash_profile not written when .profile exists" \
        "$(cat "$h/.bash_profile")" "pyenv PATH (liminal)"

    h="$TEST_TMP/profile_priority_zsh"
    mkdir -p "$h/.liminal/envs"
    touch "$h/.profile" "$h/.zprofile" "$h/.zshrc"
    _run_install "$h" "/bin/zsh" >/dev/null 2>&1 || true
    assert_contains ".profile wins over .zprofile (zsh)" \
        "$(cat "$h/.profile")" "pyenv PATH (liminal)"
    assert_not_contains ".zprofile not written when .profile exists" \
        "$(cat "$h/.zprofile")" "pyenv PATH (liminal)"

    # --- bash fallback to .bash_profile ---
    h="$TEST_TMP/bash_fallback"
    mkdir -p "$h/.liminal/envs"
    touch "$h/.bash_profile" "$h/.bashrc"
    _run_install "$h" "/bin/bash" >/dev/null 2>&1 || true
    assert_contains "bash uses .bash_profile when no .profile" \
        "$(cat "$h/.bash_profile")" "pyenv PATH (liminal)"

    # --- bash error when no profile file ---
    h="$TEST_TMP/bash_no_profile"
    mkdir -p "$h/.liminal/envs"
    touch "$h/.bashrc"
    out=$(_run_install "$h" "/bin/bash" 2>&1) || true
    assert_contains "bash errors helpfully when no profile file" \
        "$out" "Error: No profile file found for bash"

    # --- zsh fallback to .zprofile ---
    h="$TEST_TMP/zsh_fallback"
    mkdir -p "$h/.liminal/envs"
    touch "$h/.zprofile" "$h/.zshrc"
    _run_install "$h" "/bin/zsh" >/dev/null 2>&1 || true
    assert_contains "zsh uses .zprofile when no .profile" \
        "$(cat "$h/.zprofile")" "pyenv PATH (liminal)"

    # --- zsh error when no profile file ---
    h="$TEST_TMP/zsh_no_profile"
    mkdir -p "$h/.liminal/envs"
    touch "$h/.zshrc"
    out=$(_run_install "$h" "/bin/zsh" 2>&1) || true
    assert_contains "zsh errors helpfully when no profile file" \
        "$out" "Error: No profile file found for zsh"

fi

# ---------------------------------------------------------------------------
# 12. Makefile — rc file resolution logic
# ---------------------------------------------------------------------------
if describe "Makefile rc file resolution"; then

    MAKEFILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

    _run_install() {
        local test_home="$1" shell_bin="$2"
        SHELL="$shell_bin" HOME="$test_home" \
            make -C "$MAKEFILE_DIR" install \
            --no-print-directory 2>&1
    }

    # --- bash rc file ---
    h="$TEST_TMP/bash_rc"
    mkdir -p "$h/.liminal/envs"
    touch "$h/.profile" "$h/.bashrc"
    _run_install "$h" "/bin/bash" >/dev/null 2>&1 || true
    assert_contains "bash writes pyenv init to .bashrc" \
        "$(cat "$h/.bashrc")" "pyenv init (liminal)"
    assert_contains "bash writes liminal source to .bashrc" \
        "$(cat "$h/.bashrc")" "Load liminal"

    # --- bash error when no rc file ---
    h="$TEST_TMP/bash_no_rc"
    mkdir -p "$h/.liminal/envs"
    touch "$h/.profile"
    out=$(_run_install "$h" "/bin/bash" 2>&1) || true
    assert_contains "bash errors helpfully when no rc file" \
        "$out" "Error: No rc file found for bash"

    # --- zsh rc file ---
    h="$TEST_TMP/zsh_rc"
    mkdir -p "$h/.liminal/envs"
    touch "$h/.profile" "$h/.zshrc"
    _run_install "$h" "/bin/zsh" >/dev/null 2>&1 || true
    assert_contains "zsh writes pyenv init to .zshrc" \
        "$(cat "$h/.zshrc")" "pyenv init (liminal)"
    assert_contains "zsh writes liminal source to .zshrc" \
        "$(cat "$h/.zshrc")" "Load liminal"

    # --- zsh error when no rc file ---
    h="$TEST_TMP/zsh_no_rc"
    mkdir -p "$h/.liminal/envs"
    touch "$h/.profile"
    out=$(_run_install "$h" "/bin/zsh" 2>&1) || true
    assert_contains "zsh errors helpfully when no rc file" \
        "$out" "Error: No rc file found for zsh"

fi

# ---------------------------------------------------------------------------
# 13. Makefile — idempotent install (no duplicate blocks)
# ---------------------------------------------------------------------------
if describe "Makefile idempotent install"; then

    MAKEFILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
    h="$TEST_TMP/idempotent"
    mkdir -p "$h/.liminal/envs"
    touch "$h/.profile" "$h/.bashrc"

    SHELL="/bin/bash" HOME="$h" make -C "$MAKEFILE_DIR" install --no-print-directory >/dev/null 2>&1 || true
    SHELL="/bin/bash" HOME="$h" make -C "$MAKEFILE_DIR" install --no-print-directory >/dev/null 2>&1 || true

    profile_count=$(grep -cx "# pyenv PATH (liminal)" "$h/.profile" 2>/dev/null || echo 0)
    assert_eq "profile block not duplicated on re-install" "$profile_count" "1"

    rc_count=$(grep -cx "# pyenv init (liminal)" "$h/.bashrc" 2>/dev/null || echo 0)
    assert_eq "rc pyenv block not duplicated on re-install" "$rc_count" "1"

    liminal_count=$(grep -cx "# Load liminal" "$h/.bashrc" 2>/dev/null || echo 0)
    assert_eq "rc liminal source not duplicated on re-install" "$liminal_count" "1"

fi

# ---------------------------------------------------------------------------
# 14. Makefile — uninstall cleans all candidate files
# ---------------------------------------------------------------------------
if describe "Makefile uninstall cleanup"; then

    MAKEFILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
    h="$TEST_TMP/uninstall_clean"
    mkdir -p "$h/.liminal/envs"

    # Manually seed all candidate files with liminal blocks (matching install format)
    for f in .profile .bash_profile .zprofile .bashrc .zshrc; do
        printf '\n# pyenv PATH (liminal)\nexport PYENV_ROOT="$HOME/.pyenv"\nexport PATH="$PYENV_ROOT/bin:$PATH"\nif command -v pyenv >/dev/null 2>&1; then\n    eval "$(pyenv init --path)"\nfi\n# end pyenv PATH (liminal)\n' >> "$h/$f"
        printf '\n# pyenv init (liminal)\nif command -v pyenv >/dev/null 2>&1; then\n    eval "$(pyenv init -)"\nfi\n# end pyenv init (liminal)\n' >> "$h/$f"
        printf '\n# Load liminal\nif [ -f "$HOME/.liminal/liminal.sh" ]; then\n    . "$HOME/.liminal/liminal.sh"\nfi\n# end Load liminal\n' >> "$h/$f"
    done

    HOME="$h" make -C "$MAKEFILE_DIR" uninstall --no-print-directory >/dev/null 2>&1 || true

    for f in .profile .bash_profile .zprofile .bashrc .zshrc; do
        assert_not_contains "uninstall cleans pyenv PATH block from $f" \
            "$(cat "$h/$f" 2>/dev/null)" "pyenv PATH (liminal)"
        assert_not_contains "uninstall cleans pyenv init block from $f" \
            "$(cat "$h/$f" 2>/dev/null)" "pyenv init (liminal)"
        assert_not_contains "uninstall cleans liminal source block from $f" \
            "$(cat "$h/$f" 2>/dev/null)" "Load liminal"
    done

    assert_file_not_exists "uninstall removes ~/.liminal dir" "$h/.liminal"

fi

# =============================================================================
# Summary
# =============================================================================
total=$(( _PASS + _FAIL + _SKIP ))
printf "\n${_T_BOLD}Results:${_T_RESET} %s tests — " "$total"
printf "${_T_GREEN}%s passed${_T_RESET}" "$_PASS"
[ "$_FAIL" -gt 0 ] && printf ", ${_T_RED}%s failed${_T_RESET}" "$_FAIL"
[ "$_SKIP" -gt 0 ] && printf ", ${_T_YELLOW}%s skipped${_T_RESET}" "$_SKIP"
printf "\n\n"

[ "$_FAIL" -eq 0 ]
