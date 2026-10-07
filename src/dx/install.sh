#!/usr/bin/env bash
# BBA developer experience: the tooling every BBA devcontainer starts from.
#
# Runs two ways, with the same options:
#   - as a devcontainer Feature, where the CLI passes options as upper-cased env vars
#     and sets _REMOTE_USER
#   - from a Dockerfile, fetched at a pinned commit and run as root with the options as
#     env vars. Images built by `docker compose` or CI never see Features, so this is
#     how compose-backed devcontainers get the same tools. See the README.
#
# Debian and Ubuntu only.
set -euo pipefail

USERNAME="${USERNAME:-automatic}"
UPGRADE_PACKAGES="${UPGRADEPACKAGES:-false}"
PLUGINS="${PLUGINS:-colored-man-pages colorize git httpie pip zsh-interactive-cd fzf}"
FZF_VERSION="${FZFVERSION:-latest}"
INSTALL_AWS="${AWS:-true}"
INSTALL_GH="${GH:-true}"
INSTALL_VAULT="${VAULT:-true}"
VAULT_VERSION="${VAULTVERSION:-latest}"
INSTALL_KUBECTL="${KUBECTL:-true}"
KUBECTL_VERSION="${KUBECTLVERSION:-latest}"
INSTALL_HELM="${HELM:-false}"
INSTALL_CLAUDE="${CLAUDE:-true}"
CLAUDE_VERSION="${CLAUDEVERSION:-latest}"
INSTALL_OP_SSH_SIGN="${OPSSHSIGN:-true}"
VAULT_LOGIN="${VAULTLOGIN:-}"

# devcontainers/features at the commit that added the ohMyZshTheme and sudoers options
# (2.7.0). Fetched, not depended on: a Feature dependency would only run under the
# devcontainer CLI, and the Dockerfile path has to get it too.
COMMON_UTILS_SHA=b654aff13af70cedb99316931f0ef589ba38da30

SHELLRC=/usr/local/share/bba-dx/shellrc

export DEBIAN_FRONTEND=noninteractive

if [ "$(id -u)" -ne 0 ]; then
    echo "dx: run as root" >&2
    exit 1
fi

if ! command -v apt-get > /dev/null; then
    echo "dx: only Debian and Ubuntu images are supported" >&2
    exit 1
fi

if [ -n "$VAULT_LOGIN" ] && ! printf '%s' "$VAULT_LOGIN" | grep -qE '^[a-z0-9_-]+$'; then
    echo "dx: vaultLogin must be a Vault auth method name such as oidc, got '$VAULT_LOGIN'" >&2
    exit 1
fi

ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
    amd64|arm64) ;;
    *) echo "dx: unsupported architecture $ARCH" >&2; exit 1 ;;
esac

# The same choice common-utils makes for "automatic", made here because later steps
# need the name.
if [ "$USERNAME" = "auto" ] || [ "$USERNAME" = "automatic" ]; then
    if [ -n "${_REMOTE_USER:-}" ] && [ "${_REMOTE_USER}" != "root" ]; then
        USERNAME="$_REMOTE_USER"
    elif id -nu 1000 > /dev/null 2>&1; then
        USERNAME="$(id -nu 1000)"
    else
        USERNAME=vscode
    fi
fi

apt_install() {
    apt-get update
    apt-get install -y --no-install-recommends "$@"
}

# curl and ca-certificates to fetch common-utils; bare debian images have neither.
apt_install ca-certificates curl

# Base packages, non-root user, sudoers, zsh with oh-my-zsh and the codespaces theme.
# bash-completion, bubblewrap and init-system-helpers are dropped from its package list:
# no devcontainer here uses them.
mkdir -p /tmp/dx-common-utils
curl -fsSL "https://github.com/devcontainers/features/archive/${COMMON_UTILS_SHA}.tar.gz" \
    | tar -xz -C /tmp/dx-common-utils --strip-components=3 "features-${COMMON_UTILS_SHA}/src/common-utils"
sed -i -E '/^install_debian_packages\(\)/,/^}/{/^[[:space:]]+(bash-completion|bubblewrap|init-system-helpers)[[:space:]]+\\$/d}' \
    /tmp/dx-common-utils/main.sh
# For a user that already exists, common-utils assumes a group named after it and fails
# when there is none, as with an image whose user has root as its primary group. Use the
# user's actual primary group; a user it creates still gets one named after it.
sed -i 's/^group_name="${USERNAME}"$/group_name="$(id -gn "${USERNAME}" 2>\/dev\/null || echo "${USERNAME}")"/' \
    /tmp/dx-common-utils/main.sh
grep -qF 'group_name="$(id -gn' /tmp/dx-common-utils/main.sh
USERNAME="$USERNAME" \
INSTALLZSH=true \
INSTALLOHMYZSH=true \
INSTALLOHMYZSHCONFIG=true \
OHMYZSHTHEME=codespaces \
CONFIGUREZSHASDEFAULTSHELL=true \
SUDOERS=true \
UPGRADEPACKAGES="$UPGRADE_PACKAGES" \
    bash /tmp/dx-common-utils/install.sh
rm -rf /tmp/dx-common-utils

USER_HOME="$(getent passwd "$USERNAME" | cut -d: -f6)"
USER_GROUP="$(id -gn "$USERNAME")"

# common-utils clears the apt lists it used, so every install from here refreshes them.
apt_install \
    fd-find \
    file \
    httpie \
    iputils-ping \
    jq \
    netcat-openbsd \
    patch \
    ripgrep \
    unzip \
    vim \
    wget \
    xz-utils

# Debian names the binary fdfind; completion and habit expect fd.
ln -sf "$(command -v fdfind)" /usr/local/bin/fd

# fzf from its release: distro packages lag (bookworm ships 0.38), and from 0.48 on
# `fzf --zsh` gives oh-my-zsh's fzf plugin its key bindings without separate scripts.
# The latest tag comes from the releases/latest redirect: no API rate limit, no HTML.
if [ "$FZF_VERSION" = "latest" ]; then
    FZF_VERSION="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/junegunn/fzf/releases/latest)"
    FZF_VERSION="${FZF_VERSION##*/}"
fi
FZF_VERSION="${FZF_VERSION#v}"
curl -fsSL "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_${ARCH}.tar.gz" \
    | tar -xz -C /usr/local/bin fzf

if [ "$INSTALL_AWS" = "true" ]; then
    # The official installer rather than the aws-cli Feature, which also installs the
    # AWS Toolkit extension: it prompts for telemetry consent in every fresh container.
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o /tmp/awscliv2.zip
    unzip -q /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install --update
    rm -rf /tmp/awscliv2.zip /tmp/aws
fi

if [ "$INSTALL_GH" = "true" ]; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /usr/share/keyrings/githubcli-archive-keyring.gpg
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list
    apt_install gh
fi

if [ "$INSTALL_VAULT" = "true" ]; then
    # HashiCorp's apt repo has no build for every release we run on; the zip does.
    if [ "$VAULT_VERSION" = "latest" ]; then
        VAULT_VERSION="$(curl -fsSL https://checkpoint-api.hashicorp.com/v1/check/vault | jq -r .current_version)"
    fi
    curl -fsSL "https://releases.hashicorp.com/vault/${VAULT_VERSION#v}/vault_${VAULT_VERSION#v}_linux_${ARCH}.zip" -o /tmp/vault.zip
    unzip -q -o /tmp/vault.zip vault -d /usr/local/bin
    rm -f /tmp/vault.zip
fi

if [ "$INSTALL_KUBECTL" = "true" ]; then
    if [ "$KUBECTL_VERSION" = "latest" ]; then
        KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
    fi
    curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/v${KUBECTL_VERSION#v}/bin/linux/${ARCH}/kubectl"
    chmod +x /usr/local/bin/kubectl
fi

if [ "$INSTALL_HELM" = "true" ]; then
    HELM_VERSION="$(curl -fsSL https://get.helm.sh/helm-latest-version)"
    curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz" \
        | tar -xz -C /usr/local/bin --strip-components=1 "linux-${ARCH}/helm"
fi

if [ "$INSTALL_OP_SSH_SIGN" = "true" ]; then
    curl -fsSL "https://downloads.1password.com/linux/tar/stable/$(uname -m)/1password-latest.tar.gz" \
        | tar -xz -C /usr/local/bin --strip-components=1 --wildcards '*/op-ssh-sign'
fi

# Tools that open a browser (vault login -method=oidc, gh auth login, aws sso login) call
# xdg-open, which a devcontainer lacks. VS Code's terminals export $BROWSER, a helper that
# opens the URL on the host, so hand it over. Only when no real xdg-open is installed.
if ! command -v xdg-open > /dev/null; then
    cat > /usr/local/bin/xdg-open <<'EOF'
#!/bin/sh
# Installed by the dx devcontainer Feature: open URLs through the browser VS Code exposes.
if [ -n "${BROWSER:-}" ]; then
    exec "$BROWSER" "$@"
fi
echo "xdg-open: no browser available here (\$BROWSER is unset)" >&2
exit 1
EOF
    chmod 755 /usr/local/bin/xdg-open
fi

# History lives in /commandhistory so a volume can keep it across rebuilds: the Feature
# mounts one there, compose-backed devcontainers mount their own. Sticky and
# world-writable like /tmp rather than owned by the user: the devcontainer CLI remaps the
# remote user's uid to the host's when the container starts and re-owns only the home
# directory, so an owner set here can be wrong by then. zsh creates the file itself.
mkdir -p /commandhistory
chmod 1777 /commandhistory

# Shell setup shared by every user, sourced from the system rc files rather than written
# into ~/.zshrc, so it still applies when a devcontainer replaces ~/.zshrc.
mkdir -p "$(dirname "$SHELLRC")"
cat > "$SHELLRC" <<'EOF'
# Installed by the dx devcontainer Feature (bigblueanalytics/devcontainer-features).
export EDITOR="${EDITOR:-vim}"
export LESS="${LESS:--FRX}"

case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

if [ -n "${ZSH_VERSION:-}" ] && [ -w /commandhistory ]; then
    HISTFILE=/commandhistory/.zsh_history
    setopt INC_APPEND_HISTORY
fi
EOF

if [ "$INSTALL_OP_SSH_SIGN" = "true" ]; then
    cat >> "$SHELLRC" <<'EOF'

# A gitconfig copied from a macOS host points gpg.ssh.program at the 1Password app and
# expects its agent socket under ~/.1password. Repoint both at what exists in here.
# The devcontainer tooling writes ~/.gitconfig only once setup is done, so this runs
# per shell rather than at build time.
if [ -e ~/.gitconfig ]; then
    [ -d ~/.1password ] || mkdir -p ~/.1password
    if [ -n "${SSH_AUTH_SOCK:-}" ] && [ ! -e ~/.1password/agent.sock ]; then
        ln -s "$SSH_AUTH_SOCK" ~/.1password/agent.sock
    fi
    if grep -q 'Applications/1Password.app' ~/.gitconfig; then
        sed -e 's:Applications/1Password.app/Contents/MacOS/op-ssh-sign:usr/local/bin/op-ssh-sign:' -i ~/.gitconfig
    fi
fi
EOF
fi

if [ -n "$VAULT_LOGIN" ]; then
    cat >> "$SHELLRC" <<EOF

# Log in to Vault from the first interactive terminal after the container starts, when
# there is no valid token. Once per container start, so cancelling it is not repeated in
# every new terminal; PID 1's start time changes on every start. Needs a terminal on both
# ends, which keeps it out of VS Code's environment probe and of non-interactive shells.
# -no-print keeps the token off the screen, where a pasted log or a shared screen would
# carry it.
if [ -t 0 ] && [ -t 1 ] && [ -n "\${VAULT_ADDR:-}" ] && command -v vault > /dev/null; then
    _dx_vault_marker="/tmp/.dx-vault-login-\$(id -u)-\$(cut -d' ' -f22 /proc/1/stat 2>/dev/null)"
    if [ ! -e "\$_dx_vault_marker" ]; then
        : > "\$_dx_vault_marker"
        if ! vault token lookup > /dev/null 2>&1; then
            echo "dx: no valid Vault token, logging in to \$VAULT_ADDR (Ctrl-C to skip)"
            vault login -no-print -method=${VAULT_LOGIN} && echo "dx: logged in to Vault"
        fi
    fi
    unset _dx_vault_marker
fi
EOF
fi

for rc in /etc/zsh/zshrc /etc/bash.bashrc; do
    if [ -f "$rc" ] && ! grep -qF "$SHELLRC" "$rc"; then
        printf '\n[ -r %s ] && . %s\n' "$SHELLRC" "$SHELLRC" >> "$rc"
    fi
done

# Plugins and theme stay overridable per developer through ZSH_PLUGINS and ZSH_THEME.
# These have to be edited in ~/.zshrc itself: oh-my-zsh reads them when that file
# sources it.
ZSHRC="$USER_HOME/.zshrc"
if [ -f "$ZSHRC" ] && grep -q '^plugins=' "$ZSHRC"; then
    sed -e "s/^\(plugins=\).\+/\1(\$( echo \${ZSH_PLUGINS:-${PLUGINS}} ))/" \
        -e 's/^# \(COMPLETION_WAITING_DOTS="true"\)/\1/' \
        -e 's/^# \(DISABLE_UNTRACKED_FILES_DIRTY="true"\)/\1/' \
        -e 's/^\(ZSH_THEME=\).\+/\1${ZSH_THEME:-codespaces}/' \
        -i "$ZSHRC"
fi

# The shellrc sets HISTFILE too, but VS Code's terminal shell integration runs after the
# system rc files and resets HISTFILE to ~/.zsh_history before sourcing ~/.zshrc, so in a
# VS Code terminal only a value set in ~/.zshrc survives.
if [ -f "$ZSHRC" ] && ! grep -qF '/commandhistory/.zsh_history' "$ZSHRC"; then
    printf '\n[ -w /commandhistory ] && HISTFILE=/commandhistory/.zsh_history\n' >> "$ZSHRC"
fi

if [ "$INSTALL_CLAUDE" = "true" ]; then
    # The native installer puts Claude Code in the user's home, so it runs as that user.
    # ~/.local/bin is on PATH through the shellrc above.
    su "$USERNAME" -s /bin/bash -c "cd ~ && curl -fsSL https://claude.ai/install.sh | bash -s -- '${CLAUDE_VERSION}'"
fi

# sed -i above rewrote ~/.zshrc as root. It is the only file in the home this script
# leaves to root: common-utils hands over what it creates, and Claude Code installs as
# the user. A recursive chown of the home would also take over whatever the base image
# keeps there under another owner, and copy each such file into this layer.
if [ -f "$ZSHRC" ]; then
    chown "$USERNAME:$USER_GROUP" "$ZSHRC"
fi

apt-get clean
rm -rf /var/lib/apt/lists/*

echo "dx: done for user $USERNAME"
