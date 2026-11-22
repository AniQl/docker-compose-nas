Personal fork of [AdrienPoupa/docker-compose-nas](https://github.com/AdrienPoupa/docker-compose-nas), refactored into a layered compose architecture and extended with additional stacks.

## Architecture

- `docker-compose.yml` — upstream base, kept close to upstream for easy future merging
- `compose.overrides.yml` — personal modifications to upstream services, isolated from upstream
- `compose.*.yml` — additional stacks for new services not in upstream
- `COMPOSE_FILE` chain in `.env` wires everything together

## New stacks added (not in upstream)

### AI (`compose.ai.yml`)
- `ollama` — local LLM inference (AMD ROCm / RX 6700 XT)
- `open-webui` — web UI for Ollama

### Cloud (`compose.cloud.yml`)
- `nextcloud` + `nextcloud-db` + `nextcloud-redis` — self-hosted cloud storage (MariaDB + Redis)
- `cloudflared` — Cloudflare Zero Trust tunnel
- `wgeasy` — WireGuard VPN server

### Home Automation (`compose.home-auto.yml`)
- `zigbee2mqtt` — Zigbee coordinator bridge
- `matter-server` — Matter/Thread fabric
- `mqtt` — standalone Mosquitto MQTT broker

### Infrastructure (`compose.infra.yml`)
- `portainer` — Docker management UI
- `speedtest-tracker` — ISP speed monitoring
- `samba` — SMB file sharing
- `asterisk` — PBX/SIP server
- `frigate` — AI NVR (AMD VAAPI hardware decoding)

### Media extras (`compose.media-extras.yml`)
- `autobrr` — torrent IRC/RSS automation
- `huntarr` — missing/upgradeable media hunting
- `cross-seed` — cross-seeding daemon
- `stalled-download-cleaner` — Sonarr/Radarr stalled queue cleaner

### Monitoring (`compose.monitoring.yml`)
- `netdata` — real-time system metrics
- `prometheus` — metrics backend
- `grafana` — dashboards
- `grafana-image-renderer` — headless panel rendering
- `grafana-discord-daily` — daily Grafana snapshots posted to Discord

## Modifications to upstream services (`compose.overrides.yml`)

- **traefik** — bumped to v3.4, Cloudflare DNS plugin env vars, dashboard on subdomain
- **jellyfin** — AMD GPU passthrough (`/dev/dri`), subdomain routing instead of `/jellyfin` path prefix
- **jellyseerr** — subdomain routing, rewrite middlewares cleared
- **calibre-web** — restricted to LAN-only (`LOCAL_HOSTNAME`) instead of public hostname
- **sonarr, radarr, lidarr, bazarr, prowlarr** — healthcheck interval bumped 30s → 1m

## Bug fixes

- Zigbee2MQTT frontend port corrected (`8088:8080` → `8088:8089`, frontend runs on port 8089 per `configuration.yaml`)
- Jellyfin `1900/udp` conflict with Home Assistant (host network) resolved (`1901:1900/udp`)
- Portainer container name typo fixed (`portainerr` → `portainer`)
- Nextcloud Redis hostname fixed (`redis` → `nextcloud-redis`, was silently unreachable)
- `grafana-discord-daily` cron env var escaping fixed (`$VAR` → `$$VAR`, variables were interpolated empty at deploy time)
- Zigbee2MQTT timezone corrected (`Europe/Berlin` → `Europe/Warsaw`)
- Homepage data mount extended to include both SSD (`/mnt/data`) and NAS (`/mnt/nas1`)
- Data paths migrated from `/DATA/AppData/` to project-relative paths
