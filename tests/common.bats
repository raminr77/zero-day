#!/usr/bin/env bats
# Tests for lib/common.sh pure helpers.

setup() {
  load "$(dirname "$BATS_TEST_FILENAME")/test_helper.bash"
  load_libs
}

# --- detect_os -------------------------------------------------------------
@test "detect_os returns a known value" {
  run detect_os
  [ "$status" -eq 0 ]
  case "$output" in
    macos|debian|unsupported) : ;;
    *) printf 'unexpected: %s\n' "$output"; return 1 ;;
  esac
}

# --- has -------------------------------------------------------------------
@test "has finds an existing command" {
  run has bash
  [ "$status" -eq 0 ]
}

@test "has fails for a missing command" {
  run has this_command_does_not_exist_zzz
  [ "$status" -ne 0 ]
}

# --- backup_and_link -------------------------------------------------------
@test "backup_and_link creates a symlink to the source" {
  home="$(make_tmp_home)"
  src="$home/src.txt"; echo "hello" > "$src"
  dest="$home/dest.txt"

  run backup_and_link "$src" "$dest"
  [ "$status" -eq 0 ]
  [ -L "$dest" ]
  [ "$(readlink "$dest")" = "$src" ]
  rm -rf "$home"
}

@test "backup_and_link backs up an existing real file" {
  home="$(make_tmp_home)"
  src="$home/src.txt"; echo "new" > "$src"
  dest="$home/dest.txt"; echo "old" > "$dest"

  run backup_and_link "$src" "$dest"
  [ "$status" -eq 0 ]
  [ -L "$dest" ]
  # A backup copy must exist containing the old content.
  found=""
  for f in "$home"/dest.txt.bak.*; do [ -e "$f" ] && found="$f"; done
  [ -n "$found" ]
  [ "$(cat "$found")" = "old" ]
  rm -rf "$home"
}

@test "backup_and_link is idempotent for an existing correct link" {
  home="$(make_tmp_home)"
  src="$home/src.txt"; echo "x" > "$src"
  dest="$home/dest.txt"
  ln -s "$src" "$dest"

  run backup_and_link "$src" "$dest"
  [ "$status" -eq 0 ]
  # No spurious backup created.
  count=0
  for f in "$home"/dest.txt.bak.*; do [ -e "$f" ] && count=$((count+1)); done
  [ "$count" -eq 0 ]
  rm -rf "$home"
}

@test "backup_and_link fails when source is missing" {
  home="$(make_tmp_home)"
  run backup_and_link "$home/nope" "$home/dest"
  [ "$status" -ne 0 ]
  rm -rf "$home"
}
