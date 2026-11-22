# AGENTS.md — Homelab Docker Compose

This repo is a personal, layered fork of [`AdrienPoupa/docker-compose-nas`](https://github.com/AdrienPoupa/docker-compose-nas) that runs ~40 Docker Compose services on a single Ubuntu 24.04 homelab host. Changes go through pull requests into the `live` branch.

Operating priorities, in order:

1. Do not break running services or data.
2. Do not leak or commit secrets.
3. Keep changes scoped, validated, and reviewable.

If `AGENTS.local.md` exists in the repo root, read it for non-committed host/SSH details. Never commit that file.

## Non-negotiable rules

- Never print, copy, or commit the contents of `.env`, `*.env`, `backup-config/rclone/`, `backup-config/backrest/config/`, cloudflared credentials, `letsencrypt/acme.json`, API keys, tokens, or passwords. `docker compose config` without `--quiet` prints secrets; never paste its output.
- Never use `git add .` or `git add -A`. Stage explicit paths only. Secrets and runtime state live next to tracked files.
- Assume a dirty working tree. Do not run `git reset --hard`, `git checkout -- .`, `git clean`, or `git stash` unless the user explicitly asks.
- Never run `docker compose down`, `docker compose up -d` without a service name, `docker system prune`, `docker volume rm`, or delete containers/images/volumes. Target named services only.
- Ask before restarting `traefik`, `vpn`, `homeassistant`, `backrest`, or anything that interrupts ingress, VPN, automation, or backups. Ask before editing `.env` or any secret file.
- `sudo` requires a password, so unattended `sudo` hangs. Docker works without sudo (user is in the `docker` group). Ask the user to run privileged commands.
- Do not modify host paths outside this repo (`/DATA/AppData`, `/mnt/*`, systemd, network config) without explicit approval.
- Never disable or bypass the VPN/firewall path used by qBittorrent or other torrent traffic.
- Do not push to `live`/`master`, force-push, merge PRs, or sync upstream unless explicitly asked. Do not commit unless explicitly asked.

## Branch model

| Branch | Role |
| --- | --- |
| `master` | Mirror of upstream `AdrienPoupa/docker-compose-nas` and the GitHub default branch. Do not deploy from it or PR to it. |
| `live` | Integration and deployment branch. All personal PRs target `live`. |
| `feat/*`, `fix/*`, `docs/*`, `chore/*` | Short-lived work branches created from `origin/live`. |
| `origin/docs/recovery-runbook` | Unmerged docs: `BACKUP-MATRIX.md` and `RECOVERY.md`. Read via `git show`. |

`master` is heavily diverged from `upstream/master`. Do not assume fast-forward; upstream sync requires a plan and explicit user approval.

Remotes: `origin = git@github.com:AniQl/docker-compose-nas.git`, `upstream = https://github.com/AdrienPoupa/docker-compose-nas.git`. SSH push works. `gh` is installed but its token is currently invalid (`gh auth login` required). If `gh pr create` fails, push the branch and give the user:

```text
https://github.com/AniQl/docker-compose-nas/compare/live...<branch>?expand=1
```

## Repository layout and compose layering

`COMPOSE_FILE` in `.env` is a colon-separated list (`COMPOSE_PATH_SEPARATOR=:`) that defines the merged stack. `.env` is gitignored; `.env.example` is the committed template. The production `.env` differs from `.env.example` (profiles, extra layers, paths) — inspect only specific non-secret keys when needed. Never overwrite the production `.env`.

| Path | Purpose |
| --- | --- |
| `docker-compose.yml` | Upstream base services. |
| `compose.overrides.yml` | Personal overrides for upstream services (preferred over editing the base). |
| `compose.cloud.yml` | Nextcloud + MariaDB + Redis, Cloudflare Tunnel, wg-easy. |
| `compose.ai.yml` | Ollama (AMD ROCm) and Open WebUI. |
| `compose.infra.yml` | Portainer, Speedtest Tracker, Samba, Asterisk, Frigate. |
| `compose.monitoring.yml` | Netdata, Prometheus, Grafana, image renderer, Grafana Discord daily reporter. |
| `compose.home-auto.yml` | Mosquitto MQTT, Zigbee2MQTT, Matter server. |
| `compose.media-extras.yml` | Cleanuparr, Cross-Seed, stalled-download cleaner. |
| `compose.backup-config.yml` | Backrest (Restic UI) for config/secrets backup. |
| `adguardhome/`, `homeassistant/`, `immich/`, `joplin/`, `paperless/`, `tandoor/`, `vaultwarden/` | Upstream profile stacks, each with its own compose file, README, and `.env.example`. |
| `.env` / `.env.example` | Runtime config / committed template. |
| `compose-diff.sh` | Running-vs-desired inspection snapshots (invokes `sudo docker`). |
| `backup-config/` | Backrest setup script, backup path/exclude lists, rclone and restore state. |
| `update-config.sh` | Legacy first-run helper that edits app configs and `.env`; do not run on a live stack. |
| `README.md` | Upstream documentation (apps, profiles, VPN, Traefik, optional services). |
| `tests/` | Untracked scratch compose files/snapshots that contain hardcoded secrets. Do not commit or copy from it as-is. |

Personal compose files each start with a header listing required `.env` variables. Keep that header accurate. Services in subdirectory stacks are included via `COMPOSE_FILE`, not via `-f` includes.

Check the real merged state before changing anything:

```bash
docker compose config --quiet
docker compose config --services
docker compose config --profiles
```

## Services (current merged config)

- Ingress/dashboard: `traefik`, `homepage`, `autoheal`, `watchtower`
- Media/download: `sonarr`, `radarr`, `bazarr`, `prowlarr`, `seerr`, `jellyfin`, `qbittorrent`, `vpn`, `unpackerr`, `flaresolverr`, `autobrr`, `cleanuparr`, `cross-seed`, `stalled-download-cleaner`
- Cloud: `nextcloud`, `nextcloud-db`, `nextcloud-redis`, `cloudflared`, `wgeasy`
- AI: `ollama`, `open-webui`
- Monitoring: `netdata`, `prometheus`, `grafana`, `grafana-image-renderer`, `grafana-discord-daily`
- Home automation: `homeassistant`, `mqtt`, `zigbee2mqtt`, `matter-server`
- Infra: `portainer`, `speedtest-tracker`, `samba`, `asterisk`, `frigate`
- Backups: `backrest`

Optional profile stacks that can be enabled via `COMPOSE_PROFILES` include `adguardhome`, `calibre-web`, `immich`, `joplin`, `lidarr`, `paperless`, `privoxy`, `sabnzbd`, `suggestarr`, `tandoor`, `vaultwarden`, and backup variants. The enabled profile list lives in the production `.env`; never assume it matches `.env.example`. This service list is a snapshot — verify with `docker compose config --services`.

## Working safely on the host

- The canonical checkout is on the homelab host; use the SSH target and path the user provides (or `AGENTS.local.md`).
- Runtime uses the currently checked-out working tree, not a specific branch. Containers keep running while the checkout sits on a feature branch with uncommitted changes.
- Do not `git pull`, `git checkout`, or switch branches in the main checkout during an active session. Use a separate worktree for unrelated work:

```bash
git worktree add ../dcn-<slug> -b <type>/<slug> origin/live
```

- A worktree does not have `.env` (gitignored). For validation with real values, use `--env-file <main-checkout>/.env` or ask the user; never copy secrets into new locations.
- App state directories in the repo root (`sonarr/`, `radarr/`, `homeassistant/`, etc.) are gitignored bind mounts containing live data. Do not delete or edit them.
- Some files/dirs are root-owned and unreadable by the login user (e.g. parts of `grafana-config/`, `asterisk/`, `frigate/`, `wg-easy/`). `git status` may print permission warnings. Do not chmod/chown to silence them; ask the user.
- Read `DATA_ROOT`, `DOWNLOAD_ROOT`, and other paths from `.env`; do not assume upstream defaults.

## Change workflow

1. Reconcile state: `git status`, `git branch -vv`, `git log --oneline -5`, `docker compose ps`, `docker compose config --quiet`. Determine the current branch and whether the tree is dirty.
2. Isolate the change: create a branch from `origin/live` using a worktree (preferred if the main tree is dirty) or `git switch -c <type>/<slug> origin/live` if it is clean.
3. Edit the right layer: personal changes go in `compose.*.yml`; avoid editing `docker-compose.yml` when an override works. For a new service, choose the closest topic file, gate optional services with a `profiles:` entry, document required env vars in the file header, and add Traefik + Homepage labels.
4. Validate before committing (see below).
5. Stage explicit paths and commit with a conventional message: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`; imperative, lowercase after the prefix.
6. Push and open a PR against `live`. PR body should cover: what/why, files/services touched, validation performed, new env var names (not values), required runtime steps, rollback, and risk. Never include secrets or unredacted config output.
7. Apply to runtime only after user approval: `docker compose up -d <service>`, then `docker compose ps <service>` and recent logs. Label-only changes require recreating the service. Traefik label changes require `up -d traefik`, which briefly interrupts ingress. Compose edits do nothing until deployed.
8. Roll back with `git revert` and a targeted redeploy; never use destructive data operations as a rollback.

## Validation and testing

- `docker compose config --quiet` — full layered config parses with the production `.env`.
- `docker compose config --services` / `--profiles` — expected services/profiles are present.
- CI parity without secrets: copy `.env.example` to a temporary `.env`, run `docker compose config --quiet`, then remove the temporary file. GitHub Actions runs `docker-compose config` with `.env.example` on every push, so new required variables or defaults can fail CI.
- YAML/JSON: rely on `docker compose config`; use `python3 -m json.tool`/`jq` for JSON and `bash -n`/`shellcheck` (if installed) for scripts.
- No unit test suite. `tests/` is scratch and contains hardcoded secrets. `compose-diff.sh <project>` compares running containers with desired compose state but invokes `sudo docker`, so it will prompt for a password.
- Runtime smoke checks: `docker compose ps <service>`, `docker inspect --format '{{.State.Health.Status}}' <container>`, recent logs, HTTP endpoint, and the Traefik/Homepage route. Avoid unfiltered `docker inspect` (prints secrets).

## Compose conventions

- 2-space indentation; `services:` first; lowercase service names; keep existing `container_name` values.
- New personal service: place in the closest topic file, `restart: unless-stopped`, profile-gate if optional, document required env vars in the file header, add `traefik.*` router labels with `Host(...)` and `homepage.*` labels, use `${CONFIG_ROOT:-.}` for config mounts and `${VAR:-default}` for optional values.
- Add new compose files to `COMPOSE_FILE` in `.env.example` and (after asking) the production `.env`.
- Add variable names/defaults to `.env.example`; never real secrets. Follow the existing `UPPER_SNAKE` naming and update the README variable table for upstream-shared variables.
- Prefer subdomain routing (`Host(\`svc.${BASE_HOSTNAME}\`)`) over path prefixes. Path-prefix apps need their own base URL (`/sonarr`, `/radarr`, etc.). TLS uses `myresolver` with the Cloudflare DNS challenge; do not change ACME settings without approval.
- Avoid `network_mode: host` except where required (Home Assistant, Matter). qBittorrent must remain `network_mode: service:vpn` and is reached internally as `vpn:8080`.
- Overriding Traefik's `command` replaces the entire list; copy the complete command when editing.
- Pin images where a floating tag has caused breakage (Traefik 3.4, Portainer 2.21.1, wg-easy v15 are pinned). Dependabot opens weekly PRs for Docker Compose and GitHub Actions; treat them as normal PRs and do not auto-merge.
- Keep unrelated formatting churn out of functional PRs.

## Backups and recovery

- Backrest (`profile: backup-config`) backs up config and secrets (including `.env`) to an rclone Google Drive repository; restores go to `/restore` (`backup-config/restore`).
- Do not delete or rewrite `backup-config/backrest/`, `backup-config/rclone/`, or the Restic repository password. Any backup/restore change needs user approval.
- Recovery docs live on `origin/docs/recovery-runbook` (`BACKUP-MATRIX.md`, `RECOVERY.md`), not on `live`. A host rebuild uses `live`, restores secrets first, then state, then starts in stages.
- Never restore over the live checkout or live data without explicit approval and a verified backup.

## Known pitfalls

- GitHub's default branch is `master`, but integration/deployment is `live`. PRs must target `live`.
- The current checkout may be on a feature branch; git branch/commit has no effect on running containers.
- `jellyseerr/` is untracked runtime data (logs); it is not currently gitignored. Do not commit or delete it.
- `tests/` contains hardcoded credentials/API keys. Never commit it as-is; sanitize first.
- `gh` CLI authentication is invalid; `git push` over SSH still works.
- `compose-diff.sh` and `update-config.sh` are privileged/disruptive; do not run them without approval.
- Root-owned directories cause `git status` permission warnings; do not chmod them.
- The Traefik dashboard is exposed on host port 8199 with the insecure API enabled. Do not widen its exposure.
- qBittorrent shares the `vpn` network namespace. Restarting `vpn` affects download connectivity; verify no leak after changes.
- Jellyfin publishes 8096 and maps 1901/udp because Home Assistant (host network) uses 1900/udp.
- Netdata NAS metrics depend on the `/mnt/nas1` mount and container configuration. Moving mounts breaks dashboards and alerts.
- Grafana 13 uses `AUTH_TOKEN` for the image renderer, and alert templates need nil-safe `$values.B.Value` handling.
- wg-easy has IPv6 disabled because the host kernel lacks `ip6_tables`; do not re-enable blindly.
- `docker compose config` prints secrets; always use `--quiet` in logs.
- On a fresh host, the external `docker-compose-nas` network may need `docker network create docker-compose-nas`.
- `.env` and `.env.example` intentionally differ. Never overwrite the production `.env` from the example.
- Watchtower auto-updates images and autoheal restarts unhealthy containers, so deployed state can change without a git commit.
- Upstream sync conflicts are most likely in `docker-compose.yml` and `README.md`; personal overrides exist to reduce that churn.

## When to ask the user first

- Any secret or `.env` change.
- Any restart/recreate of `traefik`, `vpn`, `homeassistant`, `backrest`, or more than one service.
- Any data deletion, prune, volume removal, or restore.
- Any branch switch or checkout over a dirty tree.
- Any commit, push, PR, merge, or upstream sync.
- Any `sudo`/host-level action.
- Any change to networking, firewall, DNS, or ACME/TLS.
