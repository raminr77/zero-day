#!/usr/bin/env bash
# lib/ui.sh — Pretty terminal UI primitives.
#
# Provides colours, a banner, section headers, status lines, a spinner-backed
# step runner, and interactive prompts. All output goes to stderr so that
# functions which also print a "return value" on stdout stay clean.
#
# Honours:
#   NO_COLOR=1   -> disable all colour
#   CI=1         -> non-interactive, no spinner
# and automatically disables colour/spinner when stderr is not a TTY.

# ---------------------------------------------------------------------------
# Colour setup
# ---------------------------------------------------------------------------
ui_supports_color() {
  [[ -z "${NO_COLOR:-}" ]] && [[ -t 2 ]]
}

if ui_supports_color; then
  UI_RESET=$'\033[0m'
  UI_BOLD=$'\033[1m'
  UI_DIM=$'\033[2m'
  UI_RED=$'\033[31m'
  UI_GREEN=$'\033[32m'
  UI_YELLOW=$'\033[33m'
  UI_BLUE=$'\033[34m'
  UI_MAGENTA=$'\033[35m'
  UI_CYAN=$'\033[36m'
else
  UI_RESET='' UI_BOLD='' UI_DIM='' UI_RED='' UI_GREEN='' UI_YELLOW=''
  UI_BLUE='' UI_MAGENTA='' UI_CYAN=''
fi

# ---------------------------------------------------------------------------
# Glyphs (fall back to ASCII when the locale is not UTF-8)
# ---------------------------------------------------------------------------
if [[ "${LANG:-}${LC_ALL:-}" == *UTF-8* || "${LANG:-}${LC_ALL:-}" == *utf8* ]]; then
  UI_TICK='✔' UI_CROSS='✘' UI_ARROW='➜' UI_DOT='•' UI_WARN='⚠'
else
  UI_TICK='+' UI_CROSS='x' UI_ARROW='>' UI_DOT='*' UI_WARN='!'
fi

# ---------------------------------------------------------------------------
# Banner & headers
# ---------------------------------------------------------------------------
ui_banner() {
  printf '%s' "$UI_CYAN$UI_BOLD" >&2
  cat >&2 <<'ART'

   ╔══════════════════════════════════════════════════════╗
   ║      zero-day   ·   Machine Setup                    ║
   ║      Provision a fresh box from nothing              ║
   ╚══════════════════════════════════════════════════════╝
ART
  printf '%s' "$UI_RESET" >&2
}

# ui_section "Title"
ui_section() {
  local title="$1"
  printf '\n%s%s━━ %s %s%s\n' \
    "$UI_BOLD" "$UI_MAGENTA" "$title" \
    "$(printf '━%.0s' $(seq 1 $(( 50 - ${#title} > 0 ? 50 - ${#title} : 1 ))))" \
    "$UI_RESET" >&2
}

# ---------------------------------------------------------------------------
# Status lines
# ---------------------------------------------------------------------------
ui_info()  { printf '%s%s%s %s\n'  "$UI_BLUE"   "$UI_DOT"  "$UI_RESET" "$*" >&2; }
ui_step()  { printf '%s%s%s %s\n'  "$UI_CYAN"   "$UI_ARROW" "$UI_RESET" "$*" >&2; }
ui_ok()    { printf '%s%s%s %s\n'  "$UI_GREEN"  "$UI_TICK" "$UI_RESET" "$*" >&2; }
ui_warn()  { printf '%s%s %s%s\n'  "$UI_YELLOW" "$UI_WARN" "$*" "$UI_RESET" >&2; }
ui_err()   { printf '%s%s %s%s\n'  "$UI_RED"    "$UI_CROSS" "$*" "$UI_RESET" >&2; }
ui_skip()  { printf '%s%s skip%s %s\n' "$UI_DIM" "$UI_DOT" "$UI_RESET" "$*" >&2; }

# Fatal error then exit.
ui_die() { ui_err "$*"; exit 1; }

# ---------------------------------------------------------------------------
# Step runner with spinner
# ---------------------------------------------------------------------------
# ui_run "Human description" command arg arg...
# Runs the command, streaming a spinner while it works. On failure the captured
# output is shown. Spinner is skipped in non-interactive contexts.
ui_run() {
  local desc="$1"; shift
  local logfile
  logfile="$(mktemp 2>/dev/null || echo "/tmp/dotfiles.$$.$RANDOM")"

  if [[ ! -t 2 || -n "${CI:-}" ]]; then
    ui_step "$desc"
    if "$@" >"$logfile" 2>&1; then
      ui_ok "$desc"
      rm -f "$logfile"
      return 0
    fi
    ui_err "$desc"
    sed 's/^/    /' "$logfile" >&2
    rm -f "$logfile"
    return 1
  fi

  local frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  "$@" >"$logfile" 2>&1 &
  local pid=$!
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    local frame=${frames:$((i % ${#frames})):1}
    printf '\r%s%s%s %s' "$UI_CYAN" "$frame" "$UI_RESET" "$desc" >&2
    i=$((i + 1))
    sleep 0.1
  done
  local rc=0
  wait "$pid" || rc=$?
  printf '\r\033[K' >&2
  if [[ $rc -eq 0 ]]; then
    ui_ok "$desc"
  else
    ui_err "$desc"
    sed 's/^/    /' "$logfile" >&2
  fi
  rm -f "$logfile"
  return $rc
}

# ---------------------------------------------------------------------------
# Interactive prompts (read from the terminal even under `curl | bash`)
# ---------------------------------------------------------------------------
# Open the controlling terminal if available; otherwise prompts auto-answer.
ui_has_tty() { [[ -r /dev/tty ]] && [[ -t 1 || -t 0 || -e /dev/tty ]]; }

# ui_confirm "Question?" [default:Y/N]  -> returns 0 for yes, 1 for no.
ui_confirm() {
  local q="$1" default="${2:-N}" reply hint
  if [[ "$default" == [Yy]* ]]; then hint="[Y/n]"; else hint="[y/N]"; fi

  if [[ -n "${ASSUME_YES:-}" ]]; then return 0; fi
  if ! ui_has_tty; then
    [[ "$default" == [Yy]* ]]; return
  fi

  printf '%s%s?%s %s %s ' "$UI_YELLOW" "$UI_BOLD" "$UI_RESET" "$q" "$hint" >&2
  read -r reply </dev/tty || reply=""
  reply="${reply:-$default}"
  [[ "$reply" == [Yy]* ]]
}

# ui_ask "Prompt" varname [default]  -> stores entered value in named variable.
ui_ask() {
  local prompt="$1" __var="$2" default="${3:-}" reply
  if ! ui_has_tty; then
    printf -v "$__var" '%s' "$default"
    return 0
  fi
  if [[ -n "$default" ]]; then
    printf '%s%s?%s %s %s(%s)%s ' "$UI_YELLOW" "$UI_BOLD" "$UI_RESET" "$prompt" "$UI_DIM" "$default" "$UI_RESET" >&2
  else
    printf '%s%s?%s %s ' "$UI_YELLOW" "$UI_BOLD" "$UI_RESET" "$prompt" >&2
  fi
  read -r reply </dev/tty || reply=""
  printf -v "$__var" '%s' "${reply:-$default}"
}

# ui_ask_multiline "Prompt" varname  -> reads until an empty line (for pasting keys).
ui_ask_multiline() {
  local prompt="$1" __var="$2" line buf=""
  if ! ui_has_tty; then printf -v "$__var" '%s' ""; return 0; fi
  printf '%s%s?%s %s\n   %s(paste, then press Enter on an empty line)%s\n' \
    "$UI_YELLOW" "$UI_BOLD" "$UI_RESET" "$prompt" "$UI_DIM" "$UI_RESET" >&2
  while IFS= read -r line </dev/tty; do
    [[ -z "$line" ]] && break
    buf+="${buf:+$'\n'}$line"
  done
  printf -v "$__var" '%s' "$buf"
}
