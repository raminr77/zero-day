#!/usr/bin/env bash
# 20-zsh.sh — zsh, oh-my-zsh, powerlevel10k theme, and external plugins.

ui_section "Zsh, oh-my-zsh & Powerlevel10k"

# 1) zsh itself
has zsh || ui_run "Install zsh" pkg_install zsh

# 2) oh-my-zsh (non-interactive: don't run zsh, don't chsh here)
ZSH_DIR="${ZSH:-$HOME/.oh-my-zsh}"
if [[ -d "$ZSH_DIR" ]]; then
  ui_skip "oh-my-zsh already installed"
else
  # shellcheck disable=SC2016  # command substitution must be evaluated by the inner shell
  ui_run "Install oh-my-zsh" env RUNZSH=no CHSH=no KEEP_ZSHRC=yes bash -c \
    'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH_DIR/custom}"

# 3) Powerlevel10k theme
ui_run "Install Powerlevel10k" clone_or_update \
  https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"

# 4) External plugins (built-in OMZ plugins need no clone).
# "name|url" pairs — indexed array keeps this portable to bash 3.2 (macOS default).
# zsh-syntax-highlighting is cloned too (it's in your toolset) even though .zshrc
# enables fast-syntax-highlighting; keeps it available if you switch.
PLUGINS="
zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions.git
zsh-completions|https://github.com/zsh-users/zsh-completions.git
fast-syntax-highlighting|https://github.com/zdharma-continuum/fast-syntax-highlighting.git
fzf-tab|https://github.com/Aloxaf/fzf-tab.git
zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting.git
"
while IFS='|' read -r name url; do
  [[ -z "$name" ]] && continue
  ui_run "Plugin: $name" clone_or_update "$url" "$ZSH_CUSTOM/plugins/$name"
done <<< "$PLUGINS"

# 5) Make zsh the default shell (best-effort; needs the shell listed in /etc/shells)
if [[ "${SHELL:-}" != *zsh ]]; then
  zsh_path="$(command -v zsh || true)"
  if [[ -n "$zsh_path" ]]; then
    if ui_confirm "Set zsh as your default shell?" Y; then
      if ! maybe_sudo grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
        echo "$zsh_path" | maybe_sudo tee -a /etc/shells >/dev/null || true
      fi
      if chsh -s "$zsh_path" 2>/dev/null; then
        ui_ok "Default shell set to zsh"
      else
        ui_warn "Could not chsh automatically; run: chsh -s $zsh_path"
      fi
    fi
  fi
fi
