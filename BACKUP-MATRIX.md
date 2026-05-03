# Backup Matrix

This document defines what must be backed up to rebuild this homelab quickly.

Use with `RECOVERY.md`.

## Backup Classes

- **Class A (critical-small)**: secrets, app configs, DB state, certificates.
- **Class B (large-content)**: media libraries, photos, downloads, long-term assets.

Recommended baseline:

- Class A: daily (or more often for volatile DB/config).
- Class B: daily or weekly depending on growth and tolerance.
- Keep offsite encrypted copy for both classes.

## Secrets and Sensitive Files (encrypt, restricted access)

| Path | Why it matters | Class | Suggested cadence |
|---|---|---|---|
| `.env` | Master runtime config and secrets for most services | A | Daily + on change |
| `homeassistant/backup.env` | Backup destination credentials | A | On change |
| `immich/backup.env` | Restic repository and password/env | A | On change |
| `paperless/backup.env` | Restic repository and password/env | A | On change |
| `joplin/backup.env` | Backup credentials and retention settings | A | On change |
| `tandoor/backup.env` | Backup credentials and retention settings | A | On change |
| `vaultwarden/backup.env` | Backup credentials and retention settings | A | On change |
| `joplin/.env` | Joplin runtime configuration | A | On change |
| `paperless/.env` | Paperless runtime configuration | A | On change |
| `tandoor/.env` | Tandoor runtime configuration | A | On change |
| `vaultwarden/.env` | Vaultwarden runtime configuration | A | On change |
| `${CLOUDFLARED_DIR}` | Cloudflare tunnel config + credentials JSON | A | On change |

## Core Platform State

| Path | Service(s) | Notes | Class | Suggested cadence |
|---|---|---|---|---|
| `letsencrypt/` | Traefik | ACME certificate state (`acme.json`) | A | Daily |
| `homepage/` | Homepage | Dashboard config and customizations | A | Daily |
| `adguardhome/work` | AdGuard Home | Runtime state | A | Daily |
| `adguardhome/conf` | AdGuard Home | DNS/filter config | A | Daily |
| `adguardhome/certs` | AdGuard Home | Exported cert/key material | A | Daily |

## Media and Download Automation State

| Path | Service(s) | Notes | Class | Suggested cadence |
|---|---|---|---|---|
| `sonarr/` | Sonarr | Library and downloader mappings | A | Daily |
| `radarr/` | Radarr | Library and downloader mappings | A | Daily |
| `lidarr/` | Lidarr | Optional profile service state | A | Daily |
| `prowlarr/` | Prowlarr | Indexers and app integrations | A | Daily |
| `bazarr/` | Bazarr | Subtitle provider and app links | A | Daily |
| `seerr/` | Seerr/Jellyseerr | User requests/settings | A | Daily |
| `qbittorrent/` | qBittorrent | Download session/config state | A | Daily |
| `autobrr/` | Autobrr | Rules, auth and feeds | A | Daily |
| `cross-seed/` | Cross-seed | Matching config and cache | A | Daily |
| `sabnzbd/` | SABnzbd | Optional profile service state | A | Daily |
| `pia/` | WireGuard PIA | VPN runtime state | A | Daily |
| `pia-shared/` | WireGuard PIA helper scripts | Port-forward sync script and state | A | Daily |
| `cleanuparr/` | Cleanuparr | Ignore/blacklist/runtime logs | A | Daily |

## Home Automation State

| Path | Service(s) | Notes | Class | Suggested cadence |
|---|---|---|---|---|
| `homeassistant/` | Home Assistant | Includes configs, addons, backups | A | Daily |
| `homeassistant/mosquitto/` | Mosquitto (profile `mqtt`) | Config, data, and logs | A | Daily |
| `mqtt/` | Mosquitto (compose.home-auto) | Alternate mqtt path in layered compose | A | Daily |
| `zigbee2mqtt/` | Zigbee2MQTT | Device/network settings and keys | A | Daily |
| `matter-data/` | Matter server | Fabric and pairing state | A | Daily |

## Infra and Observability State

| Path | Service(s) | Notes | Class | Suggested cadence |
|---|---|---|---|---|
| `wg-easy/` | WireGuard Easy | Peer definitions and keys | A | Daily |
| `portainer/` | Portainer | Endpoint and stack metadata | A | Daily |
| `prometheus/` | Prometheus | Config and TSDB data | A/B | Daily |
| `grafana/` | Grafana | Dashboards, users, sqlite db | A | Daily |
| `grafana-config/` | Grafana provisioning | Declarative alerting/datasources | A | On change |
| `netdata/` | Netdata | Runtime and cache state | A/B | Daily |
| `frigate/` | Frigate | Config + runtime DB/event metadata | A | Daily |
| `asterisk/` | Asterisk | PBX config/state | A | Daily |
| `speedtest-tracker/` | Speedtest Tracker | Historical speed data | A | Daily |

## App-Specific Stateful Paths

| Path | Service(s) | Notes | Class | Suggested cadence |
|---|---|---|---|---|
| `joplin/database` | Joplin | Main sqlite database | A | Daily |
| `joplin/storage` | Joplin | Attachments/files | A | Daily |
| `tandoor/database` | Tandoor | Main sqlite database | A | Daily |
| `tandoor/mediafiles` | Tandoor | User media content | A | Daily |
| `vaultwarden/vw-data` | Vaultwarden | sqlite DB + attachments + key files | A | Daily |
| `paperless/consume` | Paperless | Inbound ingestion queue | A | Daily |
| `paperless/export` | Paperless | Exported docs | A | Daily |
| `immich/postgresql` | Immich | Postgres database files | A | Daily |

## Named Docker Volumes

If these are kept as named volumes, include them in backup jobs. Alternative: migrate critical ones to bind mounts.

| Volume | Service(s) | Notes | Class | Suggested cadence |
|---|---|---|---|---|
| `nextcloud-data` | Nextcloud | App/content state | A/B | Daily |
| `nextcloud-db-data` | Nextcloud MariaDB | Database state | A | Daily |
| `nextcloud-redis-data` | Nextcloud Redis | Cache/session data | A | Daily |
| `paperless-data` | Paperless | Main app data | A | Daily |
| `paperless-media` | Paperless | Document payloads | B | Daily |
| `paperless-redis` | Paperless | Cache/queue state | A | Daily |
| `tandoor-staticfiles` | Tandoor | Generated/static assets | A | Weekly |
| `ollama-data` | Ollama | Model blobs and metadata | B | Weekly |
| `openwebui-data` | Open WebUI | User state/chats/config | A | Daily |
| `immich-model-cache` | Immich ML | Rebuildable cache, optional backup | B | Weekly or skip |

## Large External Data Roots

These are typically biggest and should have dedicated retention policy.

| Path (from `.env`) | Purpose | Class | Suggested cadence |
|---|---|---|---|
| `DATA_ROOT` | Main persistent content root | B | Daily |
| `DOWNLOAD_ROOT` | Torrent/usenet working set | B | Daily |
| `IMMICH_UPLOAD_LOCATION` | Immich originals/videos | B | Daily |
| `NAS1_ROOT` | Additional media/storage root | B | Daily |

## Minimum Viable Recovery Set

For fastest rebuild with acceptable data risk, never skip these:

1. `.env` and all app `*.env` secret files.
2. `letsencrypt/` and `${CLOUDFLARED_DIR}`.
3. `sonarr/`, `radarr/`, `prowlarr/`, `qbittorrent/`, `seerr/`, `homeassistant/`, `vaultwarden/vw-data`.
4. Any active DB-backed app state (`paperless`, `immich`, `nextcloud`, `tandoor`, `joplin`).

## Verification Policy

- Run a restore drill at least quarterly on non-production host.
- Record results in `RECOVERY.md` drill log.
- Confirm backups are newer than target RPO.
- Verify service login and critical workflows after drill.
