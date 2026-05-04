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

## Repository Setup

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

```text
/source/.env
/source/letsencrypt
/source/homepage
/source/adguardhome/conf
/source/adguardhome/work
/source/sonarr
/source/radarr
/source/prowlarr
/source/bazarr
/source/lidarr
/source/seerr
/source/qbittorrent
/source/autobrr
/source/cross-seed
/source/sabnzbd
/source/pia
/source/pia-shared
/source/cleanuparr
/source/homeassistant/.storage
/source/homeassistant/automations.yaml
/source/homeassistant/configuration.yaml
/source/homeassistant/scenes.yaml
/source/homeassistant/scripts.yaml
/source/homeassistant/secrets.yaml
/source/homeassistant/custom_components
/source/homeassistant/www
/source/homeassistant/blueprints
/source/homeassistant/zigbee.db
/source/homeassistant/mosquitto/config
/source/mqtt/config
/source/zigbee2mqtt
/source/matter-data
/source/wg-easy
/source/portainer
/source/prometheus/prometheus.yml
/source/grafana/data/grafana.db
/source/grafana-config
/source/netdata/config
/source/frigate/config.yaml
/source/frigate/frigate.db
/source/frigate/backup.db
/source/asterisk
/source/speedtest-tracker
/source/jellyfin/database.xml
/source/jellyfin/encoding.xml
/source/jellyfin/network.xml
/source/jellyfin/system.xml
/source/jellyfin/logging.default.json
/source/jellyfin/data/data/jellyfin.db
/source/jellyfin/data/data/library.db
/source/jellyfin/data/data/library.db-shm
/source/jellyfin/data/data/library.db-wal
/source/jellyfin/data/data/ScheduledTasks
/source/jellyfin/data/data/playlists
/source/jellyfin/data/plugins
/source/calibre-web
```

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
