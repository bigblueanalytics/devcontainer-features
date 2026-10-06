#!/bin/bash
# Runs as the image's user, in a container started by plain `docker run`.
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

check "running as vscode" test "$(id -nu)" = vscode
check "zsh is the login shell" bash -c 'getent passwd vscode | cut -d: -f7 | grep -q zsh'
check "theme is codespaces by default" grep -qF 'ZSH_THEME=${ZSH_THEME:-codespaces}' ~/.zshrc
check "passwordless sudo" sudo -n true
check "history is writable" touch /commandhistory/.zsh_history
check "history survives VS Code's shell integration" bash -c 'd=$(mktemp -d) && printf "HISTFILE=\$HOME/.zsh_history\n. \$HOME/.zshrc\n" > "$d/.zshrc" && [ "$(ZDOTDIR=$d zsh -ic "print \$HISTFILE" 2>/dev/null | tail -1)" = /commandhistory/.zsh_history ]'
check "fd" fd --version
check "ripgrep" rg --version
check "fzf has --zsh" fzf --zsh
check "aws" aws --version
check "gh" gh --version
check "vault" vault version
check "kubectl" kubectl version --client
check "helm, opted in" helm version
check "op-ssh-sign" test -x /usr/local/bin/op-ssh-sign
check "claude on PATH in an interactive zsh" zsh -ic 'claude --version'
check "EDITOR defaults to vim in zsh" bash -c '[ "$(zsh -ic "echo \$EDITOR")" = vim ]'

exit "$failed"
