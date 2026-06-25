#!/usr/bin/env bats
# Tests for SSH public-key handling in lib/common.sh.

setup() {
  load "$(dirname "$BATS_TEST_FILENAME")/test_helper.bash"
  load_libs
}

ED25519="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO123abcDEF456ghiJKL789mnoPQR0stuVWX user@example"
RSA="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDexampleBODY1234567890+/abcXYZ== user@host"

# --- validation ------------------------------------------------------------
@test "ssh_validate_pubkey accepts an ed25519 key" {
  run ssh_validate_pubkey "$ED25519"
  [ "$status" -eq 0 ]
}

@test "ssh_validate_pubkey accepts an rsa key" {
  run ssh_validate_pubkey "$RSA"
  [ "$status" -eq 0 ]
}

@test "ssh_validate_pubkey rejects junk" {
  run ssh_validate_pubkey "this is not a key"
  [ "$status" -ne 0 ]
}

@test "ssh_validate_pubkey rejects an empty string" {
  run ssh_validate_pubkey ""
  [ "$status" -ne 0 ]
}

@test "ssh_validate_pubkey rejects a private key header" {
  run ssh_validate_pubkey "-----BEGIN OPENSSH PRIVATE KEY-----"
  [ "$status" -ne 0 ]
}

# --- adding ----------------------------------------------------------------
@test "ssh_add_authorized_key adds a new key and sets permissions" {
  home="$(make_tmp_home)"
  run ssh_add_authorized_key "$ED25519" "$home"
  [ "$status" -eq 0 ]
  [ -f "$home/.ssh/authorized_keys" ]
  grep -qF "$ED25519" "$home/.ssh/authorized_keys"

  # Permissions: .ssh = 700, authorized_keys = 600.
  perm_dir="$(stat -f '%Lp' "$home/.ssh" 2>/dev/null || stat -c '%a' "$home/.ssh")"
  perm_file="$(stat -f '%Lp' "$home/.ssh/authorized_keys" 2>/dev/null || stat -c '%a' "$home/.ssh/authorized_keys")"
  [ "$perm_dir" = "700" ]
  [ "$perm_file" = "600" ]
  rm -rf "$home"
}

@test "ssh_add_authorized_key is idempotent (returns 1 on duplicate)" {
  home="$(make_tmp_home)"
  ssh_add_authorized_key "$ED25519" "$home"
  run ssh_add_authorized_key "$ED25519" "$home"
  [ "$status" -eq 1 ]
  # Only one line present.
  count="$(grep -cF "$ED25519" "$home/.ssh/authorized_keys")"
  [ "$count" -eq 1 ]
  rm -rf "$home"
}

@test "ssh_add_authorized_key returns 2 for an invalid key" {
  home="$(make_tmp_home)"
  run ssh_add_authorized_key "garbage" "$home"
  [ "$status" -eq 2 ]
  [ ! -f "$home/.ssh/authorized_keys" ]
  rm -rf "$home"
}

@test "ssh_add_authorized_key trims surrounding whitespace" {
  home="$(make_tmp_home)"
  run ssh_add_authorized_key "   $ED25519   " "$home"
  [ "$status" -eq 0 ]
  # Stored line should not have leading spaces.
  run head -n1 "$home/.ssh/authorized_keys"
  [[ "$output" == ssh-ed25519* ]]
  rm -rf "$home"
}

@test "ssh_add_authorized_key dedupes same key with different comment" {
  home="$(make_tmp_home)"
  ssh_add_authorized_key "$ED25519" "$home"
  # Same body, different trailing comment.
  variant="${ED25519% *} different@comment"
  run ssh_add_authorized_key "$variant" "$home"
  [ "$status" -eq 1 ]
  rm -rf "$home"
}
