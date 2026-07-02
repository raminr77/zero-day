#!/usr/bin/env bash
# n8n/install.sh: Standalone, self-contained installer for a production n8n stack.
#
# Runs like a small CLI: it asks for everything it needs (root domain, subpath,
# TLS email, timezone …), or takes it all from flags/env for a hands-off run,
# then generates a complete, professional docker-compose stack (n8n + PostgreSQL
# + Caddy with automatic HTTPS via Let's Encrypt) and, if you want, brings it up.
# n8n is published at:
#
#     https://<your-domain><base-path>/        (default base-path: /routine)
#
# It needs NO .env file and NO repo checkout: it is safe to pipe straight from
# the web, exactly like the machine bootstrap:
#
#   curl -fsSL https://raw.githubusercontent.com/raminr77/zero-day/main/n8n/install.sh | bash
#
# Pass answers up front (any that are missing are still prompted for, unless
# --yes is given, in which case they must all be present):
#
#   curl -fsSL .../n8n/install.sh \
#     | N8N_DOMAIN=example.com LETSENCRYPT_EMAIL=you@example.com bash -s -- --yes
#
#   # or with flags (use `bash -s --` to forward them through the pipe):
#   curl -fsSL .../n8n/install.sh | bash -s -- \
#     --domain example.com --email you@example.com --base-path /routine --yes
#
# Local usage:
#   ./install.sh                 # fully interactive
#   ./install.sh --domain x --email y@z --yes   # non-interactive via flags
#   ./install.sh --generate-only # write files but do not start the stack
#   ./install.sh --print-compose # write files and print the compose file
#   ./install.sh --dir /opt/n8n  # choose where the stack files are written
#   ./install.sh -h | --help
set -euo pipefail

# --- locate ourselves (may be running from a pipe, with no file on disk) -----
SELF="${BASH_SOURCE[0]:-$0}"
if [[ -f "$SELF" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "$SELF")" && pwd)"
else
  SCRIPT_DIR=""   # piped via `curl | bash`, no source file to read
fi

# --- UI: reuse the repo's pretty primitives, or fall back to a tiny shim ------
# Sourcing lib/ui.sh keeps this installer visually consistent with setup.sh, but
# it works standalone (copied to a server, or piped from the web) via the shim.
UI_LIB=""
[[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/../lib/ui.sh" ]] && UI_LIB="$SCRIPT_DIR/../lib/ui.sh"
if [[ -n "$UI_LIB" ]]; then
  # shellcheck source=/dev/null
  source "$UI_LIB"
else
  ui_section() { printf '\n== %s ==\n' "$*" >&2; }
  ui_info()    { printf '  - %s\n'   "$*" >&2; }
  ui_step()    { printf '  > %s\n'   "$*" >&2; }
  ui_ok()      { printf '  OK %s\n'  "$*" >&2; }
  ui_warn()    { printf '  ! %s\n'   "$*" >&2; }
  ui_err()     { printf '  x %s\n'   "$*" >&2; }
  ui_skip()    { printf '  skip %s\n' "$*" >&2; }
  ui_die()     { ui_err "$*"; exit 1; }
  ui_banner()  { :; }
  UI_BOLD='' UI_RESET='' UI_DIM=''
  ui_has_tty() { [[ -r /dev/tty ]] && { [[ -t 0 ]] || [[ -e /dev/tty ]]; }; }
  ui_confirm() {
    local q="$1" d="${2:-N}" r
    [[ -n "${ASSUME_YES:-}" ]] && return 0
    ui_has_tty || { [[ "$d" == [Yy]* ]]; return; }
    printf '? %s [%s] ' "$q" "$d" >&2; read -r r </dev/tty || r=""
    r="${r:-$d}"; [[ "$r" == [Yy]* ]]
  }
  ui_ask() {
    local p="$1" __v="$2" d="${3:-}" r
    ui_has_tty || { printf -v "$__v" '%s' "$d"; return 0; }
    if [[ -n "$d" ]]; then printf '? %s (%s) ' "$p" "$d" >&2
    else printf '? %s ' "$p" >&2; fi
    read -r r </dev/tty || r=""; printf -v "$__v" '%s' "${r:-$d}"
  }
fi

has() { command -v "$1" >/dev/null 2>&1; }

# ask() wraps ui_ask so that --yes/ASSUME_YES takes the supplied default without
# prompting (ui_ask itself still prompts on a TTY even under --yes). This makes a
# fully flag/env-driven run truly hands-off, while a plain run stays interactive.
ask() {
  local prompt="$1" __var="$2" default="${3:-}"
  if [[ -n "${ASSUME_YES:-}" ]]; then printf -v "$__var" '%s' "$default"; return 0; fi
  ui_ask "$prompt" "$__var" "$default"
}

usage() {
  cat >&2 <<'USAGE'
n8n installer: generates & launches an n8n + PostgreSQL + Caddy Docker stack.

Usage:
  install.sh [options]
  curl -fsSL .../n8n/install.sh | bash -s -- [options]

Options (each also settable via the env var in parentheses):
  --domain <host>      Root domain, e.g. example.com   (N8N_DOMAIN)
  --base-path <path>   Public subpath, default /routine (N8N_BASE_PATH)
  --email <addr>       Let's Encrypt / TLS email        (LETSENCRYPT_EMAIL)
  --timezone <tz>      e.g. Asia/Tehran, default auto   (GENERIC_TIMEZONE)
  --tag <tag>          n8n image tag, default latest    (N8N_IMAGE_TAG)
  --dir <path>         Where to write the stack files   (N8N_DIR)
                       default: this folder, or ./n8n when piped
  --yes, -y            Non-interactive: never prompt (all values must be given)
  --generate-only      Write files but do not start the stack
  --print-compose      Also print the generated compose file
  -h, --help           Show this help

Anything not supplied by a flag or env var is asked for interactively (prompts
read your terminal even under `curl | bash`).
USAGE
}

# --- arguments ---------------------------------------------------------------
# Normalise `--opt=value` into `--opt value` so both forms work.
_argv=()
for _a in "$@"; do
  case "$_a" in
    --*=*) _argv+=("${_a%%=*}" "${_a#*=}") ;;
    *)     _argv+=("$_a") ;;
  esac
done
set -- ${_argv[@]+"${_argv[@]}"}

GENERATE_ONLY="" PRINT_COMPOSE=""
CLI_DOMAIN="" CLI_BASE_PATH="" CLI_EMAIL="" CLI_TZ="" CLI_TAG="" CLI_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)        CLI_DOMAIN="${2:-}"; shift ;;
    --base-path)     CLI_BASE_PATH="${2:-}"; shift ;;
    --email)         CLI_EMAIL="${2:-}"; shift ;;
    --timezone)      CLI_TZ="${2:-}"; shift ;;
    --tag)           CLI_TAG="${2:-}"; shift ;;
    --dir)           CLI_DIR="${2:-}"; shift ;;
    --yes|-y)        export ASSUME_YES=1 ;;
    --generate-only) GENERATE_ONLY=1 ;;
    --print-compose) PRINT_COMPOSE=1 ;;
    -h|--help)       usage; exit 0 ;;
    *)               ui_warn "Unknown argument: $1" ;;
  esac
  shift
done

# --- decide where the stack files live ---------------------------------------
# Priority: --dir > $N8N_DIR > the folder we run from > ./n8n (when piped).
if   [[ -n "$CLI_DIR" ]];        then N8N_ROOT="$CLI_DIR"
elif [[ -n "${N8N_DIR:-}" ]];    then N8N_ROOT="$N8N_DIR"
elif [[ -n "$SCRIPT_DIR" ]];     then N8N_ROOT="$SCRIPT_DIR"
else                                  N8N_ROOT="$PWD/n8n"
fi
mkdir -p "$N8N_ROOT"
N8N_ROOT="$(cd "$N8N_ROOT" && pwd)"

# --- load existing answers/secrets so re-runs are idempotent -----------------
# On a second run we must NOT regenerate the encryption key or DB password, or
# n8n would lose access to its encrypted credentials and its database. Flags and
# env passed for this run still take precedence over the stored values (applied
# below), so you can safely change the domain/path/tag on a re-run.
if [[ -f "$N8N_ROOT/.env" ]]; then
  set -a; # shellcheck disable=SC1091
  source "$N8N_ROOT/.env"; set +a
  ui_info "Loaded existing settings from ${N8N_ROOT}/.env"
fi

# --- resolve config: flag > env/.env > (prompt default computed later) -------
N8N_DOMAIN="${CLI_DOMAIN:-${N8N_DOMAIN:-}}"
N8N_BASE_PATH="${CLI_BASE_PATH:-${N8N_BASE_PATH:-}}"
LETSENCRYPT_EMAIL="${CLI_EMAIL:-${LETSENCRYPT_EMAIL:-}}"
GENERIC_TIMEZONE="${CLI_TZ:-${GENERIC_TIMEZONE:-}}"
N8N_IMAGE_TAG="${CLI_TAG:-${N8N_IMAGE_TAG:-}}"

# --- helpers -----------------------------------------------------------------
# Strong URL-safe secret; falls back to /dev/urandom when openssl is absent.
gen_secret() {
  if has openssl; then openssl rand -hex 24
  else head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n'; fi
}

detect_tz() {
  if has timedatectl; then
    timedatectl show -p Timezone --value 2>/dev/null && return
  fi
  [[ -f /etc/timezone ]] && { cat /etc/timezone; return; }
  [[ -L /etc/localtime ]] && { readlink /etc/localtime | sed 's#.*/zoneinfo/##'; return; }
  echo "UTC"
}

# Guess a sensible default TLS-registration email from git config.
default_email() { git config --get user.email 2>/dev/null || true; }

# ---------------------------------------------------------------------------
main() {
  ui_banner
  ui_section "n8n · professional Docker stack"
  ui_info "Generates n8n + PostgreSQL + Caddy (auto-HTTPS) and can launch it."

  # --- gather configuration --------------------------------------------------
  ui_section "Configuration"

  local domain base_path le_email tz image_tag
  ask "Domain n8n will be served from (e.g. n8n.example.com, no https://)" \
    domain "${N8N_DOMAIN:-}"
  domain="${domain#http://}"; domain="${domain#https://}"; domain="${domain%%/*}"
  [[ -n "$domain" ]] || ui_die "A domain is required (its DNS must point at this server). Pass --domain or N8N_DOMAIN."

  # Base path. "/" (the recommended default) serves n8n at the domain root.
  # A subpath is supported but discouraged: n8n's own N8N_PATH handling is buggy
  # (static assets get returned as HTML -> MIME errors, and some redirects
  # break). Prefer a dedicated (sub)domain served at "/".
  ask "Public base path ('/' serves at the domain root, recommended)" \
    base_path "${N8N_BASE_PATH:-/}"
  # Normalise: "" means root; otherwise a single leading slash, no trailing one.
  base_path="/${base_path#/}"; base_path="${base_path%/}"
  if [[ -n "$base_path" ]]; then
    ui_warn "Subpath mode (${base_path}) is unreliable: n8n's N8N_PATH support is"
    ui_warn "buggy (assets served as HTML -> the MIME errors you may have seen,"
    ui_warn "plus broken redirects). A (sub)domain at '/' is strongly recommended."
    ui_confirm "Use the subpath anyway?" N || ui_die "Re-run with --base-path / (or just press Enter at the prompt) to serve at the root."
  fi

  ask "Email for Let's Encrypt / TLS notifications" le_email "${LETSENCRYPT_EMAIL:-$(default_email)}"
  [[ -n "$le_email" ]] || ui_die "A TLS registration email is required for automatic HTTPS. Pass --email or LETSENCRYPT_EMAIL."

  ask "Timezone" tz "${GENERIC_TIMEZONE:-$(detect_tz)}"
  ask "n8n image tag" image_tag "${N8N_IMAGE_TAG:-latest}"

  # Reuse existing secrets on re-run; otherwise mint fresh ones.
  local pg_pass enc_key
  pg_pass="${POSTGRES_PASSWORD:-$(gen_secret)}"
  enc_key="${N8N_ENCRYPTION_KEY:-$(gen_secret)}"

  local full_url="https://${domain}${base_path}/"

  echo >&2
  ui_info "Domain      : ${UI_BOLD}${domain}${UI_RESET}"
  ui_info "Public URL  : ${UI_BOLD}${full_url}${UI_RESET}"
  ui_info "TLS email   : ${le_email}"
  ui_info "Timezone    : ${tz}"
  ui_info "n8n image   : docker.n8n.io/n8nio/n8n:${image_tag}"
  ui_info "Output dir  : ${N8N_ROOT}"
  echo >&2

  if ! ui_confirm "Write the stack files with these settings?" Y; then
    ui_warn "Aborted, nothing written."
    exit 0
  fi

  # --- write .env ------------------------------------------------------------
  write_env "$domain" "$base_path" "$le_email" "$tz" "$image_tag" "$pg_pass" "$enc_key"
  ui_ok "Wrote ${N8N_ROOT}/.env"

  # --- write docker-compose.yml ---------------------------------------------
  write_compose
  ui_ok "Wrote ${N8N_ROOT}/docker-compose.yml"

  # --- write Caddyfile (base path baked in) ----------------------------------
  write_caddyfile "$base_path"
  ui_ok "Wrote ${N8N_ROOT}/Caddyfile"

  mkdir -p "$N8N_ROOT/local-files"

  [[ -n "$PRINT_COMPOSE" ]] && { echo >&2; cat "$N8N_ROOT/docker-compose.yml" >&2; }

  # --- launch ----------------------------------------------------------------
  ui_section "Launch"
  ui_info "Before starting, make sure:"
  ui_info "  1. DNS ${UI_BOLD}${domain}${UI_RESET} points to this server's public IP (A/AAAA record)."
  ui_info "  2. TCP ports ${UI_BOLD}80${UI_RESET} and ${UI_BOLD}443${UI_RESET} are open (Caddy needs 80 to issue the certificate)."

  if [[ -n "$GENERATE_ONLY" ]]; then
    ui_skip "Launch skipped (--generate-only). Start later with: cd \"$N8N_ROOT\" && docker compose up -d"
    print_summary "$full_url"; return 0
  fi

  local compose
  if has docker && docker compose version >/dev/null 2>&1; then
    compose="docker compose"
  elif has docker-compose; then
    compose="docker-compose"
  else
    ui_warn "Docker Compose not found on this host."
    ui_info "Install Docker (the repo's setup.sh module 40-docker does this), then run: cd \"$N8N_ROOT\" && docker compose up -d"
    print_summary "$full_url"; return 0
  fi

  if ui_confirm "Start the n8n stack now with '${compose} up -d'?" Y; then
    ( cd "$N8N_ROOT" && $compose up -d )
    ui_ok "Stack started."
    ui_info "Follow logs with: ${UI_BOLD}cd \"$N8N_ROOT\" && ${compose} logs -f${UI_RESET}"
    ui_info "Caddy may take up to a minute to obtain the TLS certificate on first run."
  else
    ui_skip "Not started. Launch later with: cd \"$N8N_ROOT\" && ${compose} up -d"
  fi

  print_summary "$full_url"
}

# ---------------------------------------------------------------------------
# File writers
# ---------------------------------------------------------------------------
write_env() {
  local domain="$1" base_path="$2" le_email="$3" tz="$4" image_tag="$5" pg_pass="$6" enc_key="$7"
  # Subshell so the tightened umask (secrets -> 0600) does not leak to the
  # compose/Caddyfile writes that follow.
  ( umask 077
  cat >"$N8N_ROOT/.env" <<EOF
# n8n stack configuration: GENERATED by install.sh. Contains secrets.
# This file is git-ignored. Keep the encryption key & DB password safe: losing
# the encryption key makes all stored credentials unrecoverable.

# --- Public addressing (used by compose interpolation + Caddy) --------------
N8N_DOMAIN=${domain}
N8N_BASE_PATH=${base_path}
LETSENCRYPT_EMAIL=${le_email}
N8N_IMAGE_TAG=${image_tag}

# --- n8n runtime ------------------------------------------------------------
N8N_HOST=${domain}
N8N_PORT=5678
N8N_PROTOCOL=https
N8N_PATH=${base_path}/
WEBHOOK_URL=https://${domain}${base_path}/
N8N_EDITOR_BASE_URL=https://${domain}${base_path}/
N8N_PROXY_HOPS=1
N8N_ENCRYPTION_KEY=${enc_key}
GENERIC_TIMEZONE=${tz}
TZ=${tz}
N8N_RUNNERS_ENABLED=true
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
N8N_DIAGNOSTICS_ENABLED=false

# --- Database (PostgreSQL) --------------------------------------------------
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=postgres
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=n8n
DB_POSTGRESDB_PASSWORD=${pg_pass}

# Consumed by the postgres service (compose interpolation).
POSTGRES_USER=n8n
POSTGRES_DB=n8n
POSTGRES_PASSWORD=${pg_pass}
EOF
  )
}

write_compose() {
  cat >"$N8N_ROOT/docker-compose.yml" <<'EOF'
# n8n production stack: GENERATED by install.sh.
# n8n + PostgreSQL + Caddy (automatic HTTPS). Edit .env to reconfigure, then
# re-run `docker compose up -d`.
name: n8n

x-shared: &shared
  restart: unless-stopped
  networks: [n8n_net]

services:
  postgres:
    <<: *shared
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 30s

  n8n:
    <<: *shared
    image: docker.n8n.io/n8nio/n8n:${N8N_IMAGE_TAG:-latest}
    env_file: .env
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - n8n_data:/home/node/.n8n
      - ./local-files:/files
    expose:
      - "5678"
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:5678/healthz >/dev/null 2>&1 || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s

  caddy:
    <<: *shared
    image: caddy:2-alpine
    environment:
      N8N_DOMAIN: ${N8N_DOMAIN}
      LETSENCRYPT_EMAIL: ${LETSENCRYPT_EMAIL}
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - n8n

volumes:
  postgres_data:
  n8n_data:
  caddy_data:
  caddy_config:

networks:
  n8n_net:
EOF
}

write_caddyfile() {
  local base_path="$1"
  # domain + email stay dynamic via env from the compose file.
  if [[ -z "$base_path" ]]; then
    # Root mode (recommended): serve the whole site to n8n. Simple and reliable.
    cat >"$N8N_ROOT/Caddyfile" <<EOF
# Caddy reverse proxy for n8n: GENERATED by install.sh.
# Automatic HTTPS: Caddy obtains & renews Let's Encrypt certificates for the
# domain below. n8n is served at the domain root.
{
	email {\$LETSENCRYPT_EMAIL}
}

{\$N8N_DOMAIN} {
	encode zstd gzip
	reverse_proxy n8n:5678 {
		# Long-lived connections for the editor's push/streaming channel.
		flush_interval -1
	}
}
EOF
    return 0
  fi

  # Subpath mode (discouraged; n8n's N8N_PATH support is buggy). The base path is
  # baked in (Caddy path matchers can't read env at parse time). The prefix is
  # NOT stripped, so requests reach n8n as ${base_path}/... as N8N_PATH expects.
  cat >"$N8N_ROOT/Caddyfile" <<EOF
# Caddy reverse proxy for n8n: GENERATED by install.sh.
# Automatic HTTPS: Caddy obtains & renews Let's Encrypt certificates for the
# domain below. n8n is served under ${base_path}/ (subpath mode).
{
	email {\$LETSENCRYPT_EMAIL}
}

{\$N8N_DOMAIN} {
	encode zstd gzip

	# Send the bare domain to the n8n editor.
	redir / ${base_path}/ 302
	# Normalise "${base_path}" -> "${base_path}/".
	redir ${base_path} ${base_path}/ 308

	handle ${base_path}/* {
		reverse_proxy n8n:5678 {
			flush_interval -1
		}
	}

	# Anything else is not part of n8n.
	handle {
		respond "Not found" 404
	}
}
EOF
}

print_summary() {
  local url="$1"
  ui_section "Done"
  ui_ok "n8n stack files are in ${UI_BOLD}${N8N_ROOT}${UI_RESET}"
  ui_info "Public URL   : ${UI_BOLD}${url}${UI_RESET}"
  ui_info "First visit  : create the owner account in the browser to secure the instance."
  ui_info "Manage       : ${UI_DIM}cd \"$N8N_ROOT\" && docker compose {ps,logs -f,restart,down}${UI_RESET}"
  ui_info "Reconfigure  : edit ${N8N_ROOT}/.env (or re-run the installer), then docker compose up -d"
  ui_warn "Back up ${N8N_ROOT}/.env; the N8N_ENCRYPTION_KEY there is required to decrypt stored credentials."
}

main "$@"
