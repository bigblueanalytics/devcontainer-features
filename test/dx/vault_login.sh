#!/bin/bash
# vaultLogin: the first interactive terminal after the container starts logs in to Vault
# when there is no valid token; later terminals and non-interactive shells do not.
set -e

# shellcheck source=/dev/null
source dev-container-features-test-lib

# A stand-in vault: no valid token, and every login attempt recorded.
FAKE="$(mktemp -d)"
printf '#!/bin/sh\ncase "$1" in token) exit 1 ;; login) echo "login $2" >> %s/calls ;; esac\n' "$FAKE" > "$FAKE/vault"
chmod +x "$FAKE/vault"
# An empty .zshrc of its own, so zsh skips its first-run wizard for a user without one.
# The login hook lives in /etc/zsh/zshrc, which zsh reads regardless.
touch "$FAKE/.zshrc"
rm -f /tmp/.dx-vault-login-*

terminal() {
    # `script` gives the shell a pty, as a VS Code terminal does.
    ZDOTDIR="$FAKE" PATH="$FAKE:$PATH" VAULT_ADDR=https://vault.example script -qec 'zsh -ic exit' /dev/null > /dev/null
}

check "login command is installed" grep -qF 'vault login -method=oidc' /usr/local/share/bba-dx/shellrc
check "no login without a terminal" bash -c "ZDOTDIR='$FAKE' PATH='$FAKE:\$PATH' VAULT_ADDR=https://vault.example zsh -ic exit < /dev/null > /dev/null 2>&1; ! test -e '$FAKE/calls'"
terminal
check "first terminal logs in with the configured method" grep -qx 'login -method=oidc' "$FAKE/calls"
terminal
check "later terminals do not log in again" test "$(wc -l < "$FAKE/calls")" -eq 1

reportResults
