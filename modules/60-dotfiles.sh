#!/usr/bin/env bash
# 60-dotfiles.sh — symlink the config files kept in this repo into $HOME.
#
# This is the step that places your kept-in-repo configuration onto the machine.
# Existing real files are backed up to <file>.bak.<timestamp> before linking.

ui_section "Dotfiles"

CFG="$DOTFILES_ROOT/config"

# Map of <repo source>  ->  <destination in $HOME>
link_one() {
  local src="$1" dest="$2"
  if backup_and_link "$src" "$dest"; then
    ui_ok "linked ${dest/#$HOME/~}"
  else
    ui_warn "could not link ${dest/#$HOME/~}"
  fi
}

link_one "$CFG/zsh/.zshrc"        "$HOME/.zshrc"
link_one "$CFG/zsh/.p10k.zsh"     "$HOME/.p10k.zsh"
link_one "$CFG/git/.gitconfig"    "$HOME/.gitconfig"
link_one "$CFG/tmux/.tmux.conf"   "$HOME/.tmux.conf"
link_one "$CFG/nvim/init.lua"     "$HOME/.config/nvim/init.lua"

ui_ok "Dotfiles linked."
