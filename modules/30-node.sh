#!/usr/bin/env bash
# 30-node.sh — Node.js with npm, plus pnpm and yarn via corepack.
#
# We prefer mise (installed in 50-extra) as the long-term version manager, but
# this module guarantees a working node/npm/pnpm/yarn immediately.

ui_section "Node.js, npm, pnpm, yarn"

install_node_debian() {
  # NodeSource LTS repository.
  curl -fsSL https://deb.nodesource.com/setup_lts.x | maybe_sudo -E bash -
  pkg_install nodejs
}

if has node; then
  ui_skip "node already installed ($(node -v 2>/dev/null))"
else
  case "$DOTFILES_OS" in
    debian) ui_run "Install Node.js (LTS)" install_node_debian ;;
    macos)  ui_run "Install Node.js" pkg_install node ;;
  esac
fi

# corepack ships with modern Node and manages pnpm + yarn.
if has corepack; then
  ui_run "Enable corepack" maybe_sudo corepack enable || corepack enable || true
  ui_run "Activate pnpm" corepack prepare pnpm@latest --activate || true
  ui_run "Activate yarn" corepack prepare yarn@stable --activate || true
else
  ui_warn "corepack not found; installing pnpm/yarn via npm"
  has npm && ui_run "npm i -g pnpm yarn" npm install -g pnpm yarn || true
fi

has node && ui_ok "node $(node -v)"
has npm  && ui_ok "npm $(npm -v)"
