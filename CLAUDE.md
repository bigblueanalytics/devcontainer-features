# CLAUDE.md

Devcontainer Features for BBA repos, published to ghcr. See README.md for what `dx`
installs, the two ways it is consumed, and the release flow.

This repo is public: no Notion IDs, internal hostnames, account IDs or secrets in any
file, commit or PR.

- `src/dx/install.sh` runs both as a Feature and from consumers' Dockerfiles. Never rely
  on anything only the devcontainer CLI provides (`dependsOn`, lifecycle commands,
  `_REMOTE_USER` alone) for the tooling itself: compose-built images never get it.
- Every option needs a default that matches what `install.sh` assumes when the env var
  is unset, since Dockerfile consumers pass only what they change.
- A behaviour change bumps `version` in `devcontainer-feature.json` (semver), and the
  release tag must name the same version.
- Run before pushing: `shellcheck src/*/install.sh test/*/*.sh`. The Feature and
  Dockerfile tests need Docker, so CI runs them on every PR.
- Git and PR rules are the org's: branch `<prefix>/PRO-<id>-<slug>`, PR title with the
  card ID, rebase-only history.
