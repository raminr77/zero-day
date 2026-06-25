#!/usr/bin/env bash
# lib/common.sh — OS detection, package helpers, dotfile linking, SSH keys.
#
# Pure, side-effect-light helpers live here so they can be unit-tested with bats.
# Anything that prints a result does so on stdout; status chatter uses lib/ui.sh.

# ---------------------------------------------------------------------------
# OS / package-manager detection
# ---------------------------------------------------------------------------
# Echoes one of: macos | debian | unsupported
detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)
      if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        case "${ID:-}${ID_LIKE:-}" in
          *debian*|*ubuntu*) echo "debian" ;;
          *) echo "unsupported" ;;
        esac
      else
        echo "unsupported"
      fi
      ;;
    *) echo "unsupported" ;;
  esac
}

# True when a command is available on PATH.
has() { command -v "$1" >/dev/null 2>&1; }

# Run with sudo only when needed and available (Linux). On macOS, never sudo.
maybe_sudo() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  elif has sudo; then
    sudo "$@"
  else
    "$@"
  fi
}

# ---------------------------------------------------------------------------
# Package installation abstraction
# ---------------------------------------------------------------------------
# pkg_install pkg1 pkg2 ...  (uses $DOTFILES_OS set by setup.sh, else detects)
pkg_install() {
  local os="${DOTFILES_OS:-$(detect_os)}"
  case "$os" in
    debian)
      maybe_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
      ;;
    macos)
      brew install "$@"
      ;;
    *)
      return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Dotfile linking
# ---------------------------------------------------------------------------
# backup_and_link <source> <dest>
# Creates parent dirs, backs up an existing real file/dir to <dest>.bak.<ts>,
# and symlinks dest -> source. Idempotent: re-linking the same target is a no-op.
backup_and_link() {
  local src="$1" dest="$2"
  [[ -e "$src" ]] || { echo "source missing: $src" >&2; return 1; }

  mkdir -p "$(dirname "$dest")"

  # Already linked to the right place -> nothing to do.
  if [[ -L "$dest" ]]; then
    local current
    current="$(readlink "$dest")"
    [[ "$current" == "$src" ]] && return 0
  fi

  if [[ -e "$dest" || -L "$dest" ]]; then
    local stamp
    stamp="$(date +%Y%m%d%H%M%S 2>/dev/null || echo bak)"
    mv "$dest" "$dest.bak.$stamp"
  fi

  ln -sfn "$src" "$dest"
}

# ---------------------------------------------------------------------------
# Git helper for cloning / updating repos (oh-my-zsh plugins, themes, ...)
# ---------------------------------------------------------------------------
# clone_or_update <git-url> <dest-dir> [depth]
clone_or_update() {
  local url="$1" dest="$2" depth="${3:-1}"
  if [[ -d "$dest/.git" ]]; then
    git -C "$dest" pull --ff-only --quiet || true
  else
    git clone --depth "$depth" --quiet "$url" "$dest"
  fi
}

# ---------------------------------------------------------------------------
# SSH public-key handling (Linux server convenience)
# ---------------------------------------------------------------------------
# ssh_validate_pubkey "<key line>" -> 0 if it looks like a valid OpenSSH pubkey.
ssh_validate_pubkey() {
  local key="$1"
  # type  base64body  [comment]
  [[ "$key" =~ ^(ssh-rsa|ssh-ed25519|ssh-dss|ecdsa-sha2-[a-z0-9-]+|sk-ssh-ed25519@openssh\.com|sk-ecdsa-sha2-[a-z0-9-]+@openssh\.com)[[:space:]]+[A-Za-z0-9+/]+=*([[:space:]].*)?$ ]]
}

# ssh_add_authorized_key "<key line>" [home]
# Returns: 0 added, 1 already present, 2 invalid key.
ssh_add_authorized_key() {
  local key="$1" home="${2:-$HOME}"
  local sshdir="$home/.ssh" authfile="$home/.ssh/authorized_keys"

  # Trim leading/trailing whitespace.
  key="${key#"${key%%[![:space:]]*}"}"
  key="${key%"${key##*[![:space:]]}"}"

  ssh_validate_pubkey "$key" || return 2

  mkdir -p "$sshdir"
  chmod 700 "$sshdir"
  touch "$authfile"
  chmod 600 "$authfile"

  # Dedupe on the key body (second field), ignoring the comment.
  local body
  body="$(awk '{print $2}' <<<"$key")"
  if [[ -n "$body" ]] && grep -qF -- "$body" "$authfile" 2>/dev/null; then
    return 1
  fi

  printf '%s\n' "$key" >>"$authfile"
  return 0
}
