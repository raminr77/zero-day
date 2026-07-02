# zero-day · one-command machine setup

[![CI](https://github.com/raminr77/zero-day/actions/workflows/ci.yml/badge.svg)](https://github.com/raminr77/zero-day/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Provision a fresh **Ubuntu/Debian server** or **macOS laptop** from nothing with
a single command: system update, all your tools, your shell, and your config files.

```bash
curl -fsSL https://raw.githubusercontent.com/raminr77/zero-day/main/install.sh | bash
```

> [`install.sh`](install.sh)). The bootstrap installs `git`, clones this repo to
> `~/.zero-day`, then runs [`setup.sh`](setup.sh).

The script is **idempotent**, safe to run again any time to top up a machine.

---

## What it does

| Module        | What it installs / configures                                                                    |
| ------------- | ------------------------------------------------------------------------------------------------ |
| `00-update`   | `apt update && upgrade` / Homebrew install + `brew upgrade`                                      |
| `10-base`     | git, curl, wget, htop + modern CLI: bat, eza, fd, ripgrep, fzf, zoxide, jq, yq, tldr, btop, ncdu |
| `20-zsh`      | zsh, oh-my-zsh, **Powerlevel10k**, and all your plugins                                          |
| `30-node`     | Node.js (LTS), npm, pnpm + yarn (via corepack)                                                   |
| `40-docker`   | Docker Engine + Compose (Linux) / Docker Desktop (macOS)                                         |
| `45-caddy`    | Caddy web server + reverse proxy, auto-HTTPS (Linux: deploys config/caddy/Caddyfile)             |
| `50-extra`    | tmux, neovim, lazygit, lazydocker, direnv, mise                                                  |
| `60-dotfiles` | symlinks `config/*` into `$HOME` (backs up existing files)                                       |
| `70-git`      | git identity + sensible defaults                                                                 |
| `75-ssh`      | **(Linux)** optionally authorise an SSH public key                                               |
| `80-security` | **(Linux)** ufw firewall, fail2ban, unattended-upgrades                                          |

OS is detected automatically; macOS skips the Linux-only modules.

---

## Configuration files (kept in the repo)

Your real dotfiles live under [`config/`](config/) and are **symlinked** onto the
machine, so the repo is the single source of truth:

```txt
config/zsh/.zshrc        config/git/.gitconfig
config/zsh/.p10k.zsh     config/tmux/.tmux.conf
config/nvim/init.lua     config/caddy/Caddyfile
```

Edit them in the repo, commit, and re-run `setup.sh` (or just `git pull`,
they're symlinks). Existing files are backed up to `*.bak.<timestamp>`.

Most land in `$HOME` (via `60-dotfiles`). `config/caddy/Caddyfile` is the
exception: `45-caddy` symlinks it to `/etc/caddy/Caddyfile` on Linux and
reloads the service. After editing it, run `sudo systemctl reload caddy`.

---

## Options

```bash
./setup.sh --yes              # assume yes (non-interactive)
./setup.sh --only 20,30       # run only zsh + node modules
./setup.sh --skip 40,80       # skip docker + security
./setup.sh --dry-run          # show what would run
```

### Interactive by default: `.env` is optional

You don't need any config file. When run, `setup.sh` **asks for whatever it
needs** along the way (git name/email, whether to add an SSH key, etc.), and
prompts work even under `curl | bash` because they read from your terminal.

If you'd rather run **fully unattended** (no prompts), drop the values into a
git-ignored `.env` (see [`.env.example`](.env.example)) or pass them inline:

```bash
curl -fsSL https://raw.githubusercontent.com/raminr77/zero-day/main/install.sh \
  | GIT_NAME="Ramin" GIT_EMAIL="you@example.com" bash
```

---

## SSH key on a new server

`75-ssh` asks whether to add an SSH public key. Paste the **public** key from
your laptop (`cat ~/.ssh/id_ed25519.pub`) and it's appended to
`~/.ssh/authorized_keys` with correct permissions (deduplicated). Or set
`SSH_PUBLIC_KEY` in `.env` to do it without a prompt.

---

## Optional: self-hosted n8n

Separate from machine setup, [`n8n/`](n8n/) contains a **standalone** installer
that deploys [n8n](https://n8n.io) on a server as a production Docker stack:
**n8n + PostgreSQL + Caddy** with automatic HTTPS. Run it whenever you like;
it's independent of `setup.sh`.

Run it the same way as the machine bootstrap, straight from the web (no `.env`
or checkout needed):

```bash
curl -fsSL https://raw.githubusercontent.com/raminr77/zero-day/main/n8n/install.sh | bash
```

Or pass everything up front for a hands-off run (via flags or env vars):

```bash
curl -fsSL https://raw.githubusercontent.com/raminr77/zero-day/main/n8n/install.sh \
  | bash -s -- --domain example.com --email you@example.com --yes
```

It runs like a CLI: prompts for anything not given via flag/env (domain, base
path, TLS email, timezone), generates a complete `docker-compose.yml` +
`Caddyfile`, and publishes n8n at your domain root (`https://<your-domain>/`)
with a Let's Encrypt certificate obtained automatically. Serve it on a dedicated
(sub)domain, not a subpath: n8n's subpath support is buggy. Requires Docker (see
module `40-docker`), a domain pointed at the server, and open ports 80/443.

See [`n8n/README.md`](n8n/README.md) for details, flags, and day-two operations.

---

## A note on version managers

You use both the `pyenv` zsh plugin and `mise`. **mise** is the primary version
manager here (Node, Python, etc. via `mise use -g node@lts`); the `pyenv` plugin
stays enabled in `.zshrc` and activates only if `pyenv` is present. Pick whichever
you prefer per language, they don't conflict.

`fast-syntax-highlighting` is enabled in `.zshrc` (not `zsh-syntax-highlighting`)
since the two conflict; both are cloned so you can switch by editing the plugin list.

---

## Development

```bash
make lint     # shellcheck all scripts
make test     # run the bats suite
make dry-run  # preview without changes
```

### Testing safely in a container

```bash
docker run -it --rm ubuntu:24.04 bash -c '
  apt-get update && apt-get install -y curl &&
  curl -fsSL https://raw.githubusercontent.com/raminr77/zero-day/main/install.sh | bash'
```

---

## Layout

```txt
install.sh        bootstrap entrypoint (curl | bash)
setup.sh          orchestrator: sources libs, runs modules in order
lib/ui.sh         pretty CLI: colours, banner, spinner, prompts
lib/common.sh     OS detection, package helpers, linking, SSH keys
modules/          one file per step (NN-name.sh)
n8n/              standalone n8n deploy (Docker: n8n + Postgres + Caddy/HTTPS)
config/           your dotfiles (symlink sources)
tests/            bats unit tests for the pure helpers
.github/          CI workflow (shellcheck + bats + integration)
```

---

## License

[MIT](LICENSE) © Ramin Rezaei
