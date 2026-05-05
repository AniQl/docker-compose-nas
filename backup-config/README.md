# Backrest Config Backup

Backrest provides a web UI and scheduler for Restic backups.

This stack is for config-only disaster recovery backups. It uses Backrest to manage a Restic repository stored in Google Drive through rclone.

## Access

Start the service with the `backup-config` profile:

```bash
docker compose -f compose.backup-config.yml --profile backup-config up -d backrest
```

Alternatively, add `compose.backup-config.yml` to `COMPOSE_FILE` and then run `docker compose --profile backup-config up -d backrest`.

Backrest is routed through Traefik at:

```text
https://backrest.${BASE_HOSTNAME}
```

The service is also added to Homepage under `Utilities`.

## Persistent Local State

Backrest keeps only its own UI/config/cache state locally:

- `backup-config/backrest/data`
- `backup-config/backrest/config`
- `backup-config/backrest/cache`
- `backup-config/backrest/tmp`
- `backup-config/rclone`
- `backup-config/restore`

The Restic backup repository itself should live remotely in Google Drive.

## Required One-Time Setup

Create the rclone config directory:

```bash
mkdir -p backup-config/rclone
```

Create an rclone remote named `gdrive`:

```bash
docker compose -f compose.backup-config.yml --profile backup-config run --rm --entrypoint rclone backrest config
```

Start Backrest:

```bash
docker compose -f compose.backup-config.yml --profile backup-config up -d backrest
```

Open `https://backrest.${BASE_HOSTNAME}` and complete first-run user setup.

Store these outside this machine:

- Backrest login credentials
- Restic repository password
- `backup-config/rclone/rclone.conf`
- `backup-config/backrest/config/config.json`

Without the Restic password and rclone config, Google Drive backups cannot be restored after host loss.

## Automated Repository and Plan Setup

After rclone and first-run Backrest user setup, configure the repository and both backup plans with:

```bash
BACKREST_URL="https://backrest.${BASE_HOSTNAME}" ./backup-config/configure-backrest.sh
```

The script prompts for:

- Backrest username
- Backrest password
- Restic repository password

It creates or updates:

- repository `gdrive-config`
- plan `homelab-config`
- plan `homeassistant-backups`
- backup schedule `0 6 */3 * *`
- config retention: 14 daily, 8 weekly, 12 monthly
- Home Assistant backup retention: keep last 3
- repository prune/check maintenance policies

Use `BACKREST_DRY_RUN=true` to preview the generated config without writing it:

```bash
BACKREST_DRY_RUN=true BACKREST_URL="https://backrest.${BASE_HOSTNAME}" ./backup-config/configure-backrest.sh
```

You can also provide credentials through environment variables for non-interactive usage:

```bash
BACKREST_URL="https://backrest.${BASE_HOSTNAME}" \
BACKREST_USERNAME="admin" \
BACKREST_PASSWORD="<backrest-password>" \
RESTIC_PASSWORD="<restic-repository-password>" \
./backup-config/configure-backrest.sh
```

Prefer prompts over inline secrets when possible, so passwords do not land in shell history.

## Manual Repository Setup

If you prefer to configure Backrest manually, use the settings below.

Create a Backrest repository with:

```text
Repository URI: rclone:gdrive:/docker-compose-nas/config-backups
```

Use a strong Restic repository password. Store it in a password manager.

## Backup Schedule

Set each backup plan schedule to run at 06:00 Europe/Warsaw every 3 days.

Recommended Backrest schedule:

```text
Policy: Cron
Cron: 0 6 */3 * *
Clock: Local
```

The container timezone defaults to `Europe/Warsaw` through `BACKUP_TIMEZONE`.

## Plan: homelab-config

Back up config-only paths from `/source`.

Recommended paths:

See `backup-config/homelab-config-paths.txt`.

This includes:

- active media/home automation configs (`sonarr`, `radarr`, `prowlarr`, `bazarr`, `lidarr`, `qbittorrent`, `seerr`, `cross-seed`, `autobrr`, `cleanuparr`)
- infrastructure config/state (`letsencrypt`, `wg-easy`, `prometheus/prometheus.yml`, `netdata/config`, `portainer`, `grafana-config`, `grafana/data/grafana.db`)
- Backrest/bootstrap secrets (`backup-config/backrest/config/config.json`, `backup-config/rclone/rclone.conf`, `cloudflared`)
- model/config volume state for Ollama (`/ollama-data`)

Recommended excludes:

```text
**/logs/**
**/*.log
**/*.log.*
**/logs.db*
**/cache/**
**/*cache*/**
**/Cache/**
**/Sentry/**
**/Backups/**
**/MediaCover/**
**/metadata/**
**/Metadata/**
**/subtitles/**
**/transcodes/**
**/Transcodes/**
**/home-assistant_v2.db*
**/homeassistant/backups/**
**/homeassistant/deps/**
**/homeassistant/tts/**
**/homeassistant/media/**
**/jellyfin/cache/**
**/jellyfin/data/metadata/**
**/jellyfin/data/data/subtitles/**
**/jellyfin/data/data/SQLiteBackups/**
**/jellyfin/log/**
**/frigate/model_cache/**
**/frigate/clips/**
**/frigate/recordings/**
**/frigate/exports/**
**/prometheus/data/**
**/netdata/cache/**
**/netdata/lib/**
```

The same list is available in `backup-config/homelab-config-excludes.txt`.

Recommended retention:

```text
Keep daily: 14
Keep weekly: 8
Keep monthly: 12
```

## Plan: homeassistant-backups

Back up Home Assistant backup archives separately:

```text
/source/homeassistant/backups
```

Recommended retention:

```text
Keep last: 3
```

Home Assistant backup tar files are already compressed, so keep fewer snapshots than the config plan.

## Restore Target

Restore files into:

```text
/restore
```

That maps to:

```text
backup-config/restore
```
