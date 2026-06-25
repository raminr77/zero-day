#!/usr/bin/env bash
# 75-ssh.sh — (Linux only) optionally authorise an SSH public key for this user.
#
# On a fresh server you usually want to drop in the public key from your laptop
# so you can log in without a password. This asks, validates the key, and appends
# it to ~/.ssh/authorized_keys (deduplicated, correct permissions).
#
# The key can also be supplied non-interactively via SSH_PUBLIC_KEY (env/.env).

# This convenience is server-oriented; skip on macOS.
[[ "$DOTFILES_OS" == "debian" ]] || return 0

ui_section "SSH public key"

key="${SSH_PUBLIC_KEY:-}"

if [[ -z "$key" ]]; then
  if ui_confirm "Add an SSH public key to authorized_keys for this user?" N; then
    ui_ask "Paste the PUBLIC key (one line, e.g. 'ssh-ed25519 AAAA... you@host')" key ""
  else
    ui_skip "SSH key step"
    return 0
  fi
fi

[[ -z "$key" ]] && { ui_warn "No key provided; skipping."; return 0; }

rc=0
ssh_add_authorized_key "$key" || rc=$?
case $rc in
  0) ui_ok   "Public key added to ~/.ssh/authorized_keys" ;;
  1) ui_skip "That key is already authorised" ;;
  2) ui_err  "That does not look like a valid SSH public key — skipped." ;;
esac
