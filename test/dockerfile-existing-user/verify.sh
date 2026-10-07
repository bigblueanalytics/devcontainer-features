#!/bin/bash
# Runs as the image's existing user, in a container started by plain `docker run`.
set -euo pipefail

failed=0
check() {
    local label="$1"
    shift
    if "$@" > /dev/null 2>&1; then
        echo "ok   $label"
    else
        echo "FAIL $label"
        failed=1
    fi
}

check "running as app" test "$(id -nu)" = app
check "primary group is still root" test "$(id -gn)" = root
check "no group was created for the user" bash -c '! getent group app'
check "zsh is the login shell" bash -c 'getent passwd app | cut -d: -f7 | grep -q zsh'
check ".zshrc belongs to the user" test "$(stat -c %U:%G ~/.zshrc)" = app:root
check "the image's own files keep their owner" test "$(stat -c %U:%G ~/root-owned)" = root:root
check "passwordless sudo" sudo -n true
check "history is writable" touch /commandhistory/.zsh_history
check "claude on PATH in an interactive zsh" zsh -ic 'claude --version'

exit "$failed"
