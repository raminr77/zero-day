#!/usr/bin/env bash
# install.sh — one-line bootstrap entrypoint.
#
#   curl -fsSL https://raw.githubusercontent.com/<user>/dotfiles/main/install.sh | bash
#
# It ensures git exists, clones (or updates) the repo into ~/.dotfiles, then
# hands off to setup.sh inside the checkout so the full tree (lib, modules,
# config) is available locally.
set -euo pipefail

# --- configuration (override via environment) ------------------------------
REPO_URL="${DOTFILES_REPO:-https://github.com/ramin/dotfiles.git}"
TARGET_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
BRANCH="${DOTFILES_BRANCH:-main}"

say() { printf '\033[36m➜\033[0m %s\n' "$*"; }
die() { printf '\033[31m✘ %s\033[0m\n' "$*" >&2; exit 1; }

# --- detect OS for the bootstrap-level git install -------------------------
ensure_git() {
  command -v git >/dev/null 2>&1 && return 0
  say "git not found — installing it first"
  case "$(uname -s)" in
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        local sudo=""; [[ "$(id -u)" -ne 0 ]] && command -v sudo >/dev/null 2>&1 && sudo="sudo"
        $sudo apt-get update -y
        DEBIAN_FRONTEND=noninteractive $sudo apt-get install -y git
      else
        die "Unsupported Linux: please install git manually, then re-run."
      fi
      ;;
    Darwin)
      # Triggers the Xcode Command Line Tools installer, which provides git.
      xcode-select --install 2>/dev/null || true
      command -v git >/dev/null 2>&1 || die "Install Xcode Command Line Tools, then re-run."
      ;;
    *) die "Unsupported OS: $(uname -s)" ;;
  esac
}

main() {
  ensure_git

  if [[ -d "$TARGET_DIR/.git" ]]; then
    say "Updating existing checkout in $TARGET_DIR"
    git -C "$TARGET_DIR" pull --ff-only --quiet || true
  else
    say "Cloning $REPO_URL into $TARGET_DIR"
    git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$TARGET_DIR"
  fi

  say "Launching setup"
  exec bash "$TARGET_DIR/setup.sh" "$@"
}

main "$@"
