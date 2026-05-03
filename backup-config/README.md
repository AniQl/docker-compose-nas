# Config Backup

Config-only disaster recovery backups for this homelab.

The backup service stores encrypted Restic snapshots directly in Google Drive through rclone. It does not create a local Restic repository. Local Restic and rclone caches live under `/tmp` in the container and are removed after each run.

## What It Backs Up

- App configuration directories needed to avoid manual reconfiguration.
- App state databases that are effectively configuration, such as Sonarr/Radarr/Prowlarr/qBittorrent settings.
- The newest existing Home Assistant backup archive from `homeassistant/backups` as a separate Restic snapshot tag.

It intentionally excludes media roots, downloads, logs, caches, thumbnails, transcodes, Jellyfin artwork metadata, Prometheus TSDB data, and Home Assistant history DB files.

## Setup

Copy the example environment file:

```bash
cp backup-config/backup.env.example backup-config/backup.env
```

Generate and store a strong Restic password:

```bash
openssl rand -base64 32
```

Set it in `backup-config/backup.env` as `RESTIC_PASSWORD`.

Create the rclone config directory:

```bash
mkdir -p backup-config/rclone
```

Create an rclone remote named `gdrive`:

```bash
docker compose -f compose.backup-config.yml run --rm -it config-backup rclone config
```

Store both of these outside the machine too:

- `RESTIC_PASSWORD`
- `backup-config/rclone/rclone.conf`

Without both, the Google Drive backup cannot be restored after host loss.

## Manual Commands

Run a backup immediately:

```bash
docker compose -f compose.backup-config.yml run --rm config-backup backup
```

List snapshots:

```bash
docker compose -f compose.backup-config.yml run --rm config-backup snapshots
```

Check repository health:

```bash
docker compose -f compose.backup-config.yml run --rm config-backup check
```

Restore latest snapshot to `backup-config/restore`:

```bash
docker compose -f compose.backup-config.yml run --rm config-backup restore latest
```

Print the resolved config include list and latest Home Assistant backup path:

```bash
docker compose -f compose.backup-config.yml run --rm config-backup list
```

## Scheduled Service

Add `compose.backup-config.yml` to `COMPOSE_FILE`, then append `backup-config` to `COMPOSE_PROFILES`:

```env
COMPOSE_PROFILES=existing-profiles,backup-config
```

Or start it explicitly:

```bash
docker compose -f compose.backup-config.yml --profile backup-config up -d config-backup
```

The default schedule is `30 3 * * *`, configured by `BACKUP_CRON` in `backup-config/backup.env`.

## Snapshot Tags

- `config`: strict config-only backup set.
- `homeassistant-backup`: newest Home Assistant backup tar.
- `homelab`: common tag on both snapshot groups.

Retention is applied separately for config snapshots and Home Assistant backup archive snapshots.
