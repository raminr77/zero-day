#!/usr/bin/env bash
# 70-git.sh — set global git identity and sensible defaults.
#
# Name/email come from GIT_NAME / GIT_EMAIL (env or .env), or are prompted for.
# The shared aliases/colours live in config/.gitconfig (linked in module 60);
# this module only writes machine-specific identity into a separate file so the
# tracked .gitconfig stays free of personal data.

ui_section "Git configuration"

git_name="${GIT_NAME:-$(git config --global user.name 2>/dev/null || true)}"
git_email="${GIT_EMAIL:-$(git config --global user.email 2>/dev/null || true)}"

[[ -z "$git_name" ]]  && ui_ask "Your name for git commits" git_name "$(whoami)"
[[ -z "$git_email" ]] && ui_ask "Your email for git commits" git_email ""

if [[ -n "$git_name" ]]; then
  git config --global user.name "$git_name"
  ui_ok "git user.name = $git_name"
fi
if [[ -n "$git_email" ]]; then
  git config --global user.email "$git_email"
  ui_ok "git user.email = $git_email"
else
  ui_warn "No git email set; configure later with: git config --global user.email you@example.com"
fi

# Defaults (idempotent).
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global push.autoSetupRemote true
if has nvim; then git config --global core.editor "nvim"; fi

# Credential helper, per platform: macOS keychain, in-memory cache on Linux.
case "$DOTFILES_OS" in
  macos)  git config --global credential.helper osxkeychain ;;
  debian) git config --global credential.helper "cache --timeout=3600" ;;
esac

ui_ok "Git configured."
