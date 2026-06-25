#!/usr/bin/env bash
# 80-security.sh — (Linux only) baseline server hardening:
#   ufw firewall, fail2ban, and automatic security updates.

[[ "$DOTFILES_OS" == "debian" ]] || return 0

ui_section "Server security baseline"

if ! ui_confirm "Apply baseline security (ufw + fail2ban + auto-updates)?" Y; then
  ui_skip "Security baseline"
  return 0
fi

# --- ufw firewall ----------------------------------------------------------
has ufw || ui_run "Install ufw" pkg_install ufw
ui_run "Allow SSH through ufw" maybe_sudo ufw allow OpenSSH
# Enabling ufw can drop connections; allow SSH first (done above).
ui_run "Enable ufw" maybe_sudo ufw --force enable

# --- fail2ban --------------------------------------------------------------
has fail2ban-client || ui_run "Install fail2ban" pkg_install fail2ban
ui_run "Enable fail2ban" maybe_sudo systemctl enable --now fail2ban || \
  ui_warn "Could not start fail2ban (no systemd?); enable it manually."

# --- unattended-upgrades ---------------------------------------------------
ui_run "Install unattended-upgrades" pkg_install unattended-upgrades
# Enable non-interactively.
ui_run "Enable automatic security updates" \
  maybe_sudo env DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive -plow unattended-upgrades \
  || ui_warn "Could not auto-enable; run: sudo dpkg-reconfigure -plow unattended-upgrades"

ui_ok "Security baseline applied."
