#!/usr/bin/env bash
# 10-base.sh — base toolchain plus modern CLI replacements.

ui_section "Base tools & modern CLI"

# Essentials requested explicitly + build prerequisites.
case "$DOTFILES_OS" in
  debian)
    # Many modern CLI tools live in the "universe" repo — enable it best-effort.
    if has add-apt-repository; then
      if ui_run "Enable universe repo" maybe_sudo add-apt-repository -y universe; then
        ui_run "Refresh package index" maybe_sudo apt-get update -y || true
      else
        ui_warn "Could not enable universe; continuing."
      fi
    fi

    # Core tools — reliable, in main. Fail fast if these can't install.
    ui_run "Install base packages" pkg_install \
      git curl wget htop ca-certificates gnupg lsb-release build-essential unzip

    # Modern CLI tools — installed individually so one missing package never
    # blocks the rest. Note: bat -> batcat, fd -> fd-find (fdfind); both are
    # aliased in .zshrc. tldr is provided by the `tealdeer` package on Debian.
    ui_step "Install modern CLI tools"
    pkg_install_each \
      bat fd-find ripgrep fzf jq tealdeer ncdu zoxide eza yq btop
    ;;
  macos)
    ui_run "Install base packages" pkg_install git curl wget htop

    ui_step "Install modern CLI tools"
    pkg_install_each \
      bat eza fd ripgrep fzf zoxide jq yq tealdeer btop ncdu
    ;;
esac

ui_ok "Base tools ready."
