#!/usr/bin/env bash
# 00-update.sh — refresh the system package index and upgrade installed packages.
# Sourced by setup.sh (libraries and DOTFILES_OS already in scope).

ui_section "System update"

case "$DOTFILES_OS" in
  debian)
    ui_run "Refresh package index" maybe_sudo env DEBIAN_FRONTEND=noninteractive apt-get update -y
    ui_run "Upgrade installed packages" \
      maybe_sudo env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
      || ui_warn "Some packages could not be upgraded; continuing."
    ;;
  macos)
    if ! has brew; then
      # shellcheck disable=SC2016  # command substitution must be evaluated by the inner shell
      ui_run "Install Homebrew" bash -c \
        '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
      # Make brew available for the rest of this run.
      if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [[ -x /usr/local/bin/brew ]]; then eval "$(/usr/local/bin/brew shellenv)"; fi
    fi
    ui_run "brew update"  brew update
    ui_run "brew upgrade" brew upgrade || ui_warn "brew upgrade reported issues; continuing."
    ;;
esac
