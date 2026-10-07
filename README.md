# devcontainer-features

Devcontainer Features for BBA repos. One so far, `dx`: the shell and CLI tooling every
BBA devcontainer starts from, so a terminal looks and works the same in every repo.

## dx

| Area | What it sets up |
|---|---|
| Base | [common-utils](https://github.com/devcontainers/features/tree/main/src/common-utils) at a pinned commit: non-root user with passwordless sudo, zsh as login shell, oh-my-zsh with the codespaces theme |
| Shell | fd, fzf (latest release, 0.48+ so `fzf --zsh` works), ripgrep, jq, vim, httpie, ping, netcat, file, patch, unzip, wget, xz |
| CLIs | aws (v2), gh, vault, kubectl, helm (opt-in) |
| Claude Code | Anthropic's native installer, in the user's `~/.local/bin` |
| Git signing | 1Password's `op-ssh-sign`, plus a shell hook that repoints a macOS gitconfig at it |
| Browser | an `xdg-open` that hands URLs to VS Code's `$BROWSER`, so `vault login -method=oidc`, `gh auth login` and `aws sso login` open the host's browser |
| History | zsh history in `/commandhistory`, so a volume keeps it across rebuilds |
| Defaults | `EDITOR=vim`, `LESS=-FRX`; plugins and theme overridable per developer through `ZSH_PLUGINS` / `ZSH_THEME` |

Debian and Ubuntu, amd64 and arm64. CI tests it on debian bookworm, debian trixie and
`mcr.microsoft.com/devcontainers/base:noble`.

### Use it from devcontainer.json

For devcontainers built from a stock image:

```jsonc
"features": {
    "ghcr.io/bigblueanalytics/devcontainer-features/dx:1": {}
}
```

The Feature also mounts a `/commandhistory` volume, adds the Claude Code extension, and
makes zsh the default VS Code terminal. It runs after `common-utils` when both are
listed, but it runs common-utils itself, so listing it as well is redundant.

### Use it from a Dockerfile

Features only run when the devcontainer CLI builds the container. An image that
`docker compose`, `make` or CI builds never sees them. Those images run the same script
during the build, fetched at the commit of a release tag:

```dockerfile
# dx v1.0.0 (bigblueanalytics/devcontainer-features)
ARG DX_SHA=<commit of the v1.0.0 tag>
RUN curl -fsSL "https://github.com/bigblueanalytics/devcontainer-features/archive/${DX_SHA}.tar.gz" \
        | tar -xz -C /tmp --strip-components=2 "devcontainer-features-${DX_SHA}/src/dx" \
    && USERNAME=bigblue HELM=true bash /tmp/dx/install.sh \
    && rm -rf /tmp/dx
```

Options are the upper-cased option names below, as env vars. Pass `USERNAME`
explicitly, since a Dockerfile build has no remote user to detect. Mount
`/commandhistory` from the compose file to keep history.

### Options

| Option | Default | |
|---|---|---|
| `username` | `automatic` | The remote user, else the uid 1000 user, else a new `vscode` user |
| `upgradePackages` | `false` | Upgrade the image's packages first |
| `plugins` | `colored-man-pages colorize git httpie pip zsh-interactive-cd fzf` | Default oh-my-zsh plugin list |
| `fzfVersion` | `latest` | fzf release; a pin must be 0.48+ |
| `aws` | `true` | AWS CLI v2 |
| `gh` | `true` | GitHub CLI |
| `vault` / `vaultVersion` | `true` / `latest` | Vault CLI |
| `kubectl` / `kubectlVersion` | `true` / `latest` | kubectl; `latest` is the current stable release |
| `helm` | `false` | Helm, latest release |
| `claude` / `claudeVersion` | `true` / `latest` | Claude Code: `latest`, `stable` or a version |
| `opSshSign` | `true` | 1Password commit signing |
| `vaultLogin` | (empty) | Vault auth method, e.g. `oidc`: the first terminal after the container starts runs `vault login`, without printing the token, when `VAULT_ADDR` is set and there is no valid token |

The Claude Code extension is added even with `claude: false`: Feature customizations
cannot depend on options.

### Vault tokens

With `vaultLogin` set, the token is the container's own, in its `~/.vault-token`: nothing
is mounted from the host, and the CLI, Terraform and applications find it at the default
path. It is requested once per container start, from the first interactive terminal, only
when there is no valid token; Ctrl-C skips it until the next start. It survives stopping
the container and is gone after a rebuild. The repo sets `VAULT_ADDR` itself, in
`containerEnv` or its compose file.

### Why not the upstream Features for each tool

- **aws-cli** also installs the AWS Toolkit extension, which asks for telemetry consent
  in every fresh container and appends to Copilot's instructions in a way the repo's
  settings cannot undo.
- Every upstream Feature only works through the devcontainer CLI, which leaves out
  every compose-built image. One script serves both.

## Releasing

1. Bump `version` in `src/dx/devcontainer-feature.json`, following semver: a new
   option is minor, a changed default or removed option is major.
2. Merge, then tag the merge commit `vX.Y.Z` with the same version.
3. The tag runs `release.yaml`, which refuses a tag that doesn't match the version and
   publishes `dx` to ghcr as `1`, `1.0` and `1.0.0`.

Dockerfile consumers pin a commit, so they move only when their `DX_SHA` is bumped.

## Layout

```
src/dx/          the Feature: devcontainer-feature.json and install.sh
test/dx/         `devcontainer features test`: test.sh for defaults, scenarios.json + opt_outs.sh
test/dockerfile/ the Dockerfile path, built and run by plain docker
```

Run the tests locally with the [devcontainer CLI](https://github.com/devcontainers/cli):

```
devcontainer features test --features dx --base-image debian:bookworm .
docker build -f test/dockerfile/Dockerfile -t dx-dockerfile . && docker run --rm dx-dockerfile
```
