#!/usr/bin/env bash
# 50-extra.sh — tmux, neovim, lazygit, lazydocker, direnv, mise.

ui_section "Extra developer tools"

# --- tmux + neovim ---------------------------------------------------------
has tmux || ui_run "Install tmux" pkg_install tmux
has nvim || ui_run "Install neovim" pkg_install neovim

# --- direnv ----------------------------------------------------------------
has direnv || ui_run "Install direnv" pkg_install direnv

# --- mise (version manager; replaces nvm/pyenv) ----------------------------
if has mise; then
  ui_skip "mise already installed"
else
  case "$DOTFILES_OS" in
    macos) ui_run "Install mise" pkg_install mise ;;
    debian)
      ui_run "Install mise" bash -c 'curl -fsSL https://mise.run | sh'
      ;;
  esac
fi

# --- lazygit + lazydocker --------------------------------------------------
install_github_binary() {
  # install_github_binary <repo> <binary> <asset-grep>
  local repo="$1" bin="$2" pattern="$3"
  local tmp; tmp="$(mktemp -d)"
  local url
  url="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
    | grep -oE "https://[^\"]*${pattern}[^\"]*" | head -n1)"
  [[ -n "$url" ]] || { echo "no asset matching $pattern" >&2; rm -rf "$tmp"; return 1; }
  curl -fsSL "$url" -o "$tmp/asset.tar.gz"
  tar -xzf "$tmp/asset.tar.gz" -C "$tmp"
  maybe_sudo install -m 0755 "$tmp/$bin" /usr/local/bin/"$bin"
  rm -rf "$tmp"
}

case "$DOTFILES_OS" in
  macos)
    has lazygit    || ui_run "Install lazygit" pkg_install lazygit
    has lazydocker || ui_run "Install lazydocker" pkg_install lazydocker
    ;;
  debian)
    arch="$(uname -m)"; [[ "$arch" == "aarch64" ]] && lg_arch="arm64" || lg_arch="x86_64"
    has lazygit || ui_run "Install lazygit" \
      install_github_binary jesseduffield/lazygit lazygit "lazygit_.*_Linux_${lg_arch}.tar.gz" \
      || ui_warn "lazygit install failed; install manually later."
    has lazydocker || ui_run "Install lazydocker" \
      install_github_binary jesseduffield/lazydocker lazydocker "lazydocker_.*_Linux_${lg_arch}.tar.gz" \
      || ui_warn "lazydocker install failed; install manually later."
    ;;
esac

ui_ok "Extra tools ready."
