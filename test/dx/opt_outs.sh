#!/bin/bash
# Tools switched off stay absent, opt-ins and pinned versions take effect.
set -e

# shellcheck source=/dev/null
source dev-container-features-test-lib

# The user the Feature set up: the one it made zsh the login shell for. Not "uid 1000":
# the stock noble image's vscode user is not.
DX_USER="$(getent passwd | awk -F: '$3 >= 1000 && $7 ~ /zsh$/ { print $1; exit }')"
DX_HOME="$(getent passwd "$DX_USER" | cut -d: -f6)"

check "aws is absent" bash -c '! command -v aws'
check "vault is absent" bash -c '! command -v vault'
check "claude is absent" bash -c "! test -e $DX_HOME/.local/bin/claude"
check "op-ssh-sign is absent" bash -c '! test -e /usr/local/bin/op-ssh-sign'
check "no 1Password block in shellrc" bash -c '! grep -q 1password /usr/local/share/bba-dx/shellrc'
check "helm is installed" helm version
check "kubectl is the pinned version" bash -c 'kubectl version --client | grep -q v1.31.4'
check "plugins option sets the default list" grep -qF '${ZSH_PLUGINS:-git fzf}' "$DX_HOME/.zshrc"
check "fzf is the pinned version" bash -c 'fzf --version | grep -q "^0.60.3"'
check "gh is still installed" gh --version

reportResults
