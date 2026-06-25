#!/usr/bin/env bash
# 10-base.sh — base toolchain plus modern CLI replacements.

ui_section "Base tools & modern CLI"

# Essentials requested explicitly + build prerequisites.
case "$DOTFILES_OS" in
  debian)
    ui_run "Install base packages" pkg_install \
      git curl wget htop ca-certificates gnupg lsb-release build-essential unzip
    # Modern CLI tools. Some have different binary names on Debian (handled in .zshrc).
    ui_run "Install modern CLI tools" pkg_install \
      bat fd-find ripgrep fzf jq tldr ncdu zoxide
    # eza / yq / btop are not always packaged on older Debian; install best-effort.
    pkg_install eza   2>/dev/null || ui_skip "eza (not in apt; install via mise/cargo later)"
    pkg_install yq    2>/dev/null || ui_skip "yq (install via snap/binary later)"
    pkg_install btop  2>/dev/null || ui_skip "btop (older repos lack it)"
    ;;
  macos)
    ui_run "Install base + modern CLI tools" pkg_install \
      git curl wget htop \
      bat eza fd ripgrep fzf zoxide jq yq tldr btop ncdu
    ;;
esac

ui_ok "Base tools ready."
