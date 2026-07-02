# n8n, one-command production stack

A **standalone** installer that provisions [n8n](https://n8n.io) on any Docker
host. It runs like a small CLI: it asks for what it needs, generates a complete
`docker-compose.yml` (n8n + PostgreSQL + Caddy with automatic HTTPS), and can
bring the stack up for you.

This folder is independent of the machine-setup in the repo root, run it
whenever you like, on its own, without touching `setup.sh`.

n8n is published at the **root of your domain** (recommended):

```txt
https://<your-domain>/
```

> **Serve n8n at a domain root, not a subpath.** n8n's own subpath support
> (`N8N_PATH`) is buggy: static assets get returned as HTML (causing
> `Failed to load module script … MIME type 'text/html'` errors in the browser
> console) and some redirects break. Use a dedicated (sub)domain instead, e.g.
> `n8n.example.com`. No domain of your own? A wildcard DNS host works with zero
> setup, e.g. `n8n.<server-ip>.nip.io`. The installer still offers a subpath
> mode, but warns and asks for confirmation.

## What you get

| Service    | Image                     | Role                                            |
| ---------- | ------------------------- | ----------------------------------------------- |
| `n8n`      | `docker.n8n.io/n8nio/n8n` | The workflow engine + editor                    |
| `postgres` | `postgres:16-alpine`      | Durable database (production-grade, not SQLite) |
| `caddy`    | `caddy:2-alpine`          | Reverse proxy + **automatic** Let's Encrypt TLS |

Data lives in named Docker volumes (`postgres_data`, `n8n_data`, `caddy_data`)
so it survives restarts and upgrades.

## Requirements

- A Docker host with **Docker Engine + Compose plugin** (the repo's
  `setup.sh` module `40-docker` installs these).
- A **domain** whose DNS `A`/`AAAA` record points at the server's public IP.
- Ports **80** and **443** open (Caddy needs 80 to issue the certificate).

## Usage

The installer is fully self-contained: it needs **no `.env` file and no repo
checkout**, so you can pipe it straight from the web, exactly like the machine
bootstrap in the repo root.

### One-liner (curl | bash)

Fully interactive (it asks for domain, email, etc.; prompts read your terminal
even through the pipe):

```bash
curl -fsSL https://raw.githubusercontent.com/raminr77/zero-day/main/n8n/install.sh | bash
```

Hands-off, passing the requirements up front. Use `bash -s --` to forward flags
through the pipe:

```bash
# via flags
curl -fsSL https://raw.githubusercontent.com/raminr77/zero-day/main/n8n/install.sh \
  | bash -s -- --domain example.com --email you@example.com --yes

# or via environment variables
curl -fsSL https://raw.githubusercontent.com/raminr77/zero-day/main/n8n/install.sh \
  | N8N_DOMAIN=example.com LETSENCRYPT_EMAIL=you@example.com bash -s -- --yes
```

When piped without `--dir`, the stack files are written to `./n8n` in the
current directory.

### From a checkout

```bash
cd n8n
./install.sh                                   # interactive
./install.sh --domain example.com --email you@example.com --yes   # hands-off
```

### What it configures

Anything not supplied by a flag or env var is **asked for interactively**;
missing values under `--yes` abort with a clear message.

| Setting             | Flag          | Env var             | Default                            |
| ------------------- | ------------- | ------------------- | ---------------------------------- |
| Root domain         | `--domain`    | `N8N_DOMAIN`        | (required)                         |
| Base path           | `--base-path` | `N8N_BASE_PATH`     | `/` (root; subpath discouraged)    |
| Let's Encrypt email | `--email`     | `LETSENCRYPT_EMAIL` | (required)                         |
| Timezone            | `--timezone`  | `GENERIC_TIMEZONE`  | auto-detected                      |
| n8n image tag       | `--tag`       | `N8N_IMAGE_TAG`     | `latest`                           |
| Output dir          | `--dir`       | `N8N_DIR`           | this folder, or `./n8n` when piped |

Precedence is **flag > env / existing `.env` > interactive prompt**.

It then writes `.env`, `docker-compose.yml`, and `Caddyfile`, and offers to run
`docker compose up -d`. Caddy obtains the TLS certificate automatically on first
start (this can take up to a minute).

On first visit, create the **owner account** in the browser to secure the
instance, n8n's built-in user management handles authentication.

### Behaviour flags

| Flag              | Effect                                                    |
| ----------------- | --------------------------------------------------------- |
| `--yes`, `-y`     | Non-interactive: never prompt (all values must be given). |
| `--generate-only` | Write files but don't start the stack.                    |
| `--print-compose` | Also print the generated compose file.                    |
| `-h`, `--help`    | Show help.                                                |

### Unattended install from an `.env`

An `.env` is entirely optional (the installer writes one for you), but you can
also pre-fill it:

```bash
cp .env.example .env   # fill in domain, email, etc.
./install.sh --yes
```

## Day-two operations

```bash
cd n8n
docker compose ps          # status
docker compose logs -f     # follow logs
docker compose pull && docker compose up -d   # upgrade to a newer n8n image
docker compose restart     # restart
docker compose down        # stop (volumes/data are kept)
```

## Re-running is safe

Re-running `install.sh` reuses the existing `N8N_ENCRYPTION_KEY` and database
password from `.env`, so it won't lock you out of stored credentials or the
database. You can change the domain, path, timezone, or image tag freely.

## ⚠️ Back up `.env`

`.env` holds `N8N_ENCRYPTION_KEY`. **Losing it makes all stored credentials
unrecoverable.** Back it up somewhere safe; it is intentionally git-ignored.

## Troubleshooting

### Browser console: `Failed to load module script … MIME type 'text/html'`

You deployed n8n under a **subpath** (e.g. `/routine`). n8n's subpath support is
buggy: it returns its `index.html` for JavaScript/CSS asset requests, so the
browser refuses them and the editor never loads. Switch to serving n8n at a
**domain root**. Re-run the installer against the same stack directory (this
reuses your encryption key and database, so nothing is lost):

```bash
cd <your stack dir>
curl -fsSL https://raw.githubusercontent.com/raminr77/zero-day/main/n8n/install.sh \
  | bash -s -- --domain n8n.example.com --base-path / --email you@example.com \
               --dir "$PWD" --yes --generate-only
docker compose down && docker compose up -d
```

No domain of your own? Use a wildcard DNS host, e.g.
`--domain n8n.<server-ip>.nip.io`. Then open `https://<that-domain>/`.

## How addressing works

- **Root mode (recommended):** Caddy proxies the whole site to `n8n:5678`;
  `WEBHOOK_URL` / `N8N_EDITOR_BASE_URL` are `https://<domain>/`. Webhooks are
  published under `https://<domain>/webhook/…`.
- **Subpath mode (discouraged):** n8n runs with `N8N_PATH=/<path>/` and Caddy
  proxies `/<path>/*` without stripping the prefix. Works only partially (see
  Troubleshooting above).
