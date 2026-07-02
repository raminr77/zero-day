#!/usr/bin/env bash
# 45-caddy.sh: Caddy web server / reverse proxy with automatic HTTPS.
#
# Installs Caddy (official apt repo on Debian, Homebrew on macOS). On Linux it
# also deploys the repo's config/caddy/Caddyfile to /etc/caddy/Caddyfile (as a
# symlink, so the repo stays the single source of truth) and enables the service.
#
# NOTE: the dockerised n8n stack in n8n/ ships its OWN Caddy and binds 80/443.
# Run one or the other; see config/caddy/Caddyfile for how to front n8n here.

ui_section "Caddy"

install_caddy_debian() {
  # Official Caddy apt repository (Cloudsmith). The published source list pins
  # the keyring path below, so the key must live exactly there.
  maybe_sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | maybe_sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  maybe_sudo chmod a+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    | maybe_sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null

  maybe_sudo env DEBIAN_FRONTEND=noninteractive apt-get update -y
  pkg_install caddy
}

# Symlink the repo Caddyfile to /etc/caddy/Caddyfile, backing up any real file.
deploy_caddyfile_debian() {
  local src="$DOTFILES_ROOT/config/caddy/Caddyfile" dest="/etc/caddy/Caddyfile"
  [[ -f "$src" ]] || { ui_warn "No Caddyfile in repo at $src; skipping config."; return 0; }

  # Already pointing at the repo copy? nothing to do.
  if [[ "$(readlink -f "$dest" 2>/dev/null)" == "$(readlink -f "$src")" ]]; then
    ui_skip "Caddyfile already linked to the repo"
    return 0
  fi

  maybe_sudo install -d -m 0755 /etc/caddy
  # Back up an existing real config (the package ships a default one).
  if [[ -e "$dest" && ! -L "$dest" ]]; then
    local stamp; stamp="$(date +%Y%m%d%H%M%S 2>/dev/null || echo bak)"
    maybe_sudo cp -a "$dest" "$dest.bak.$stamp"
  fi
  maybe_sudo ln -sfn "$src" "$dest"
}

case "$DOTFILES_OS" in
  debian)
    if has caddy; then
      ui_skip "caddy already installed ($(caddy version 2>/dev/null | head -1))"
    else
      ui_run "Install Caddy" install_caddy_debian
    fi

    deploy_caddyfile_debian

    # Validate before (re)loading so a bad edit never takes the service down.
    if maybe_sudo caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1; then
      maybe_sudo systemctl enable --now caddy 2>/dev/null || true
      maybe_sudo systemctl reload caddy 2>/dev/null \
        || maybe_sudo systemctl restart caddy 2>/dev/null || true
      ui_ok "Caddy configured and running (config: /etc/caddy/Caddyfile)"
    else
      ui_warn "Caddyfile failed validation; left the running config untouched. Check /etc/caddy/Caddyfile."
    fi
    ;;
  macos)
    if has caddy; then
      ui_skip "caddy already installed"
    else
      ui_run "Install Caddy" brew install caddy \
        || ui_warn "Could not install Caddy; install it manually with: brew install caddy"
    fi
    ui_info "On macOS, point Caddy at the repo config and run it as a service:"
    ui_info "  ln -sfn \"$DOTFILES_ROOT/config/caddy/Caddyfile\" \"\$(brew --prefix)/etc/Caddyfile\""
    ui_info "  brew services start caddy"
    ;;
esac
