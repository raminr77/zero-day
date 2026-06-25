#!/usr/bin/env bash
# setup.sh — orchestrator. Sources the libraries and runs each module in order.
#
# Usage:
#   ./setup.sh [--yes] [--only NN[,NN...]] [--skip NN[,NN...]] [--dry-run]
#
#   --yes        Assume "yes" for every confirmation (non-interactive).
#   --only       Run only the listed module number prefixes (e.g. --only 20,30).
#   --skip       Skip the listed module number prefixes.
#   --dry-run    Print what would run without executing modules.
#
# Configuration is read from a local .env if present (see .env.example).
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_ROOT

# --- load libraries --------------------------------------------------------
# shellcheck source=lib/ui.sh
source "$DOTFILES_ROOT/lib/ui.sh"
# shellcheck source=lib/common.sh
source "$DOTFILES_ROOT/lib/common.sh"

# --- load optional .env ----------------------------------------------------
# .env is entirely optional. When absent, every module prompts interactively for
# whatever it needs (and falls back to safe defaults if there is no terminal).
DOTFILES_ENV_LOADED=""
if [[ -f "$DOTFILES_ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$DOTFILES_ROOT/.env"
  set +a
  DOTFILES_ENV_LOADED=1
fi

# --- parse arguments -------------------------------------------------------
ONLY="" SKIP="" DRY_RUN=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y) export ASSUME_YES=1 ;;
    --only)   ONLY="$2"; shift ;;
    --skip)   SKIP="$2"; shift ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      sed -n '2,16p' "$DOTFILES_ROOT/setup.sh" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) ui_warn "Unknown argument: $1" ;;
  esac
  shift
done

# --- detect OS once, share with modules ------------------------------------
DOTFILES_OS="$(detect_os)"
export DOTFILES_OS DOTFILES_ROOT

# --- module selection helpers ----------------------------------------------
in_list() { local needle="$1" list="$2"; [[ ",$list," == *",$needle,"* ]]; }

should_run() {
  local num="$1"
  [[ -n "$ONLY" ]] && { in_list "$num" "$ONLY"; return; }
  [[ -n "$SKIP" ]] && in_list "$num" "$SKIP" && return 1
  return 0
}

# ---------------------------------------------------------------------------
main() {
  ui_banner
  ui_info "Detected OS: ${UI_BOLD}${DOTFILES_OS}${UI_RESET}"
  if [[ -n "$DOTFILES_ENV_LOADED" ]]; then
    ui_info "Loaded settings from .env"
  else
    ui_info "No .env found — I'll ask for anything I need as we go."
  fi

  if [[ "$DOTFILES_OS" == "unsupported" ]]; then
    ui_die "Unsupported OS. This installer targets macOS and Debian/Ubuntu."
  fi

  if ! ui_confirm "Proceed with provisioning this machine?" Y; then
    ui_warn "Aborted by user."
    exit 0
  fi

  local module count=0
  for module in "$DOTFILES_ROOT"/modules/[0-9][0-9]-*.sh; do
    [[ -e "$module" ]] || continue
    local base num
    base="$(basename "$module")"
    num="${base%%-*}"

    should_run "$num" || { ui_skip "$base"; continue; }

    if [[ -n "$DRY_RUN" ]]; then
      ui_step "[dry-run] would run $base"
      continue
    fi

    # shellcheck disable=SC1090
    source "$module"
    count=$((count + 1))
  done

  ui_section "Done"
  ui_ok "Provisioning complete ($count module(s) ran)."
  ui_info "Open a new terminal (or run ${UI_BOLD}zsh${UI_RESET}) to load your shell."
  if [[ "$DOTFILES_OS" == "debian" ]]; then
    ui_info "If you were added to the ${UI_BOLD}docker${UI_RESET} group, log out/in for it to take effect."
  fi
}

main "$@"
