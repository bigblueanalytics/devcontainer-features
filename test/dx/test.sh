#!/bin/bash
# Default options, run by `devcontainer features test` against every base image in CI.
set -e

# shellcheck source=/dev/null
source dev-container-features-test-lib

# The user the Feature set up: the one it made zsh the login shell for. Not "uid 1000":
# the stock noble image's vscode user is not.
DX_USER="$(getent passwd | awk -F: '$3 >= 1000 && $7 ~ /zsh$/ { print $1; exit }')"
DX_HOME="$(getent passwd "$DX_USER" | cut -d: -f6)"

as_user() {
    if [ "$(id -nu)" = "$DX_USER" ]; then
        bash -c "$1"
    else
        su "$DX_USER" -s /bin/bash -c "$1"
    fi
}

check "zsh is the login shell" bash -c "getent passwd $DX_USER | cut -d: -f7 | grep -q zsh"
check "oh-my-zsh is installed" test -d "$DX_HOME/.oh-my-zsh"
check "theme is overridable, codespaces by default" grep -qF 'ZSH_THEME=${ZSH_THEME:-codespaces}' "$DX_HOME/.zshrc"
check "plugins are overridable" grep -qF 'plugins=($( echo ${ZSH_PLUGINS:-' "$DX_HOME/.zshrc"
check "shellrc is sourced by zsh" grep -qF /usr/local/share/bba-dx/shellrc /etc/zsh/zshrc
check "shellrc is sourced by bash" grep -qF /usr/local/share/bba-dx/shellrc /etc/bash.bashrc
check "history is writable by the user" as_user 'touch /commandhistory/.zsh_history'
# VS Code's shell integration sources ~/.zshrc from its own ZDOTDIR after resetting
# HISTFILE to ~/.zsh_history; this reproduces that order.
check "history survives VS Code's shell integration" as_user 'd=$(mktemp -d) && printf "HISTFILE=\$HOME/.zsh_history\n. \$HOME/.zshrc\n" > "$d/.zshrc" && [ "$(ZDOTDIR=$d zsh -ic "print \$HISTFILE" 2>/dev/null | tail -1)" = /commandhistory/.zsh_history ]'
check "passwordless sudo" as_user 'sudo -n true'

check "fd" fd --version
check "ripgrep" rg --version
check "jq" jq --version
check "vim" vim --version
check "fzf has --zsh" fzf --zsh
check "aws" aws --version
check "gh" gh --version
check "vault" vault version
check "kubectl" kubectl version --client
check "helm is off by default" bash -c '! command -v helm'
check "op-ssh-sign" test -x /usr/local/bin/op-ssh-sign
check "xdg-open hands URLs to VS Code's \$BROWSER" bash -c 'BROWSER=echo xdg-open https://example.com | grep -qx https://example.com'
check "no Vault auto-login unless vaultLogin is set" bash -c '! grep -q "vault login" /usr/local/share/bba-dx/shellrc'
check "claude is on the user's PATH in zsh" as_user 'zsh -ic "claude --version"'

reportResults
