# dotfiles · one-command machine setup

Provision a fresh **Ubuntu/Debian server** or **macOS laptop** with a single
command: system update, all your tools, your shell, and your config files.

```bash
curl -fsSL https://raw.githubusercontent.com/<you>/dotfiles/main/install.sh | bash
```

> Replace `<you>` with your GitHub username (and update `DOTFILES_REPO` in
> [`install.sh`](install.sh)). The bootstrap installs `git`, clones this repo to
> `~/.dotfiles`, then runs [`setup.sh`](setup.sh).

The script is **idempotent** — safe to run again any time to top up a machine.

---

## What it does

| Module | What it installs / configures |
|--------|-------------------------------|
| `00-update`   | `apt update && upgrade` / Homebrew install + `brew upgrade` |
| `10-base`     | git, curl, wget, htop + modern CLI: bat, eza, fd, ripgrep, fzf, zoxide, jq, yq, tldr, btop, ncdu |
| `20-zsh`      | zsh, oh-my-zsh, **Powerlevel10k**, and all your plugins |
| `30-node`     | Node.js (LTS), npm, pnpm + yarn (via corepack) |
| `40-docker`   | Docker Engine + Compose (Linux) / Docker Desktop (macOS) |
| `50-extra`    | tmux, neovim, lazygit, lazydocker, direnv, mise |
| `60-dotfiles` | symlinks `config/*` into `$HOME` (backs up existing files) |
| `70-git`      | git identity + sensible defaults |
| `75-ssh`      | **(Linux)** optionally authorise an SSH public key |
| `80-security` | **(Linux)** ufw firewall, fail2ban, unattended-upgrades |

OS is detected automatically; macOS skips the Linux-only modules.

---

## Configuration files (kept in the repo)

Your real dotfiles live under [`config/`](config/) and are **symlinked** onto the
machine, so the repo is the single source of truth:

```
config/zsh/.zshrc        config/git/.gitconfig
config/zsh/.p10k.zsh     config/tmux/.tmux.conf
config/nvim/init.lua
```

Edit them in the repo, commit, and re-run `setup.sh` (or just `git pull` —
they're symlinks). Existing files are backed up to `*.bak.<timestamp>`.

---

## Options

```bash
./setup.sh --yes              # assume yes (non-interactive)
./setup.sh --only 20,30       # run only zsh + node modules
./setup.sh --skip 40,80       # skip docker + security
./setup.sh --dry-run          # show what would run
```

Non-interactive values (git name/email, SSH key) can be supplied via a
git-ignored `.env` — see [`.env.example`](.env.example).

---

## SSH key on a new server

`75-ssh` asks whether to add an SSH public key. Paste the **public** key from
your laptop (`cat ~/.ssh/id_ed25519.pub`) and it's appended to
`~/.ssh/authorized_keys` with correct permissions (deduplicated). Or set
`SSH_PUBLIC_KEY` in `.env` to do it without a prompt.

---

## A note on version managers

You use both the `pyenv` zsh plugin and `mise`. **mise** is the primary version
manager here (Node, Python, etc. via `mise use -g node@lts`); the `pyenv` plugin
stays enabled in `.zshrc` and activates only if `pyenv` is present. Pick whichever
you prefer per language — they don't conflict.

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
  curl -fsSL https://raw.githubusercontent.com/<you>/dotfiles/main/install.sh | bash'
```

---

## Layout

```
install.sh        bootstrap entrypoint (curl | bash)
setup.sh          orchestrator: sources libs, runs modules in order
lib/ui.sh         pretty CLI: colours, banner, spinner, prompts
lib/common.sh     OS detection, package helpers, linking, SSH keys
modules/          one file per step (NN-name.sh)
config/           your dotfiles (symlink sources)
tests/            bats unit tests for the pure helpers
```
