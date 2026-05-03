# Recovery Runbook

This runbook is for rebuilding this homelab quickly on a new machine after host loss.

Use it with `BACKUP-MATRIX.md`.

## Scope

- **Code and compose definitions**: this git repository.
- **Secrets**: `.env`, `*.env`, API tokens, tunnel credentials, backup passwords.
- **State**: bind-mounted config/data directories and named Docker volumes.

## Prerequisites

- Access to this git repo.
- Access to backup storage and decryption credentials.
- DNS control for hostnames used by Traefik/subdomains.
- A Linux host with Docker Engine + Docker Compose v2.

## Host Bootstrap

1. Install Docker and Compose plugin.
2. Recreate storage mount points used in `.env`:
   - `DATA_ROOT`
   - `DOWNLOAD_ROOT`
   - `IMMICH_UPLOAD_LOCATION`
   - `NAS1_ROOT`
3. Ensure the runtime user and group IDs match old host values:
   - `USER_ID`
   - `GROUP_ID`
4. Clone repository:

```bash
git clone git@github.com:AniQl/docker-compose-nas.git
cd docker-compose-nas
git checkout live
```

## Restore Secrets and Core Identity

Restore these first:

- `.env`
- service env files:
  - `homeassistant/backup.env`
  - `immich/backup.env`
  - `paperless/backup.env`
  - `joplin/backup.env`
  - `tandoor/backup.env`
  - `vaultwarden/backup.env`
  - `joplin/.env`
  - `paperless/.env`
  - `tandoor/.env`
  - `vaultwarden/.env`
- Cloudflare tunnel directory (`CLOUDFLARED_DIR` from `.env`).
- Traefik certificate state: `letsencrypt/acme.json` and related files.

## Restore State

Use `BACKUP-MATRIX.md` as source of truth. Restore in this order:

1. Core routing state:
   - `letsencrypt/`
   - `homepage/`
   - `adguardhome/` (if profile enabled)
2. Media automation stack:
   - `sonarr/`, `radarr/`, `prowlarr/`, `bazarr/`, `lidarr/`
   - `qbittorrent/`, `seerr/`, `autobrr/`, `cross-seed/`, `sabnzbd/`
   - `pia/`, `pia-shared/`, `cleanuparr/`
3. Home automation:
   - `homeassistant/`
   - `mqtt/` and/or `homeassistant/mosquitto/`
   - `zigbee2mqtt/`, `matter-data/`
4. Infra and observability:
   - `wg-easy/`, `portainer/`, `prometheus/`, `grafana/`, `netdata/`, `frigate/`, `asterisk/`, `speedtest-tracker/`
5. Named volumes used by compose files (if not migrated to bind mounts):
   - `nextcloud-data`, `nextcloud-db-data`, `nextcloud-redis-data`
   - `paperless-data`, `paperless-media`, `paperless-redis`
   - `tandoor-staticfiles`, `ollama-data`, `openwebui-data`, `immich-model-cache`

## Start Sequence

Start in stages to reduce troubleshooting blast radius.

### Stage 1: Ingress and dashboard

```bash
docker compose up -d traefik homepage
```

Validate:

- `docker compose ps`
- Traefik dashboard and homepage are reachable.
- TLS certificates load correctly.

### Stage 2: Base media stack

```bash
docker compose up -d sonarr radarr prowlarr bazarr qbittorrent vpn jellyfin seerr
```

Validate:

- Sonarr/Radarr can reach qBittorrent.
- Prowlarr indexer tests pass.
- VPN container healthy and qBittorrent bound behind VPN.

### Stage 3: Profile services

Bring up enabled profiles from `COMPOSE_PROFILES`:

```bash
docker compose up -d
```

Validate:

- Home Assistant entities and automations are restored.
- Immich/Paperless/Joplin/Tandoor/Vaultwarden data appears.
- Monitoring stack (Prometheus/Grafana/Netdata) shows data.

## Post-Restore Verification Checklist

- `docker compose config` completes successfully.
- `docker compose ps` shows expected services healthy.
- External and local DNS hostnames resolve as expected.
- Login tests pass for:
  - Sonarr/Radarr/Prowlarr/Bazarr
  - qBittorrent
  - Home Assistant
  - Immich
  - Paperless
  - Vaultwarden
  - Nextcloud (if enabled)
- Scheduled backup containers are running where expected.

## Security Follow-Up

If machine loss involved possible compromise, rotate:

- Cloudflare API tokens
- VPN credentials
- Grafana token and admin password
- webhook URLs and application API keys
- any long-lived access tokens in `.env`

## Restore Drill Policy

- Run a full restore drill at least quarterly.
- Record:
  - date
  - restore duration (RTO)
  - data age recovered (RPO)
  - failures and remediation items

Add this section after each drill:

```text
Restore drill date:
Recovered to point in time:
Total time to healthy stack:
Issues found:
Actions taken:
```
