Upstream merge from AdrienPoupa/docker-compose-nas, plus personal adjustments
for the layered compose architecture.

## ⚠️ Breaking: Jellyseerr → Seerr migration

Upstream migrated from `ghcr.io/fallenbagel/jellyseerr` to
`ghcr.io/seerr-team/seerr`. Your data migrates automatically on first
startup, but the config folder must be owned by UID 1000 first:

```bash
# Fix permissions before deploying
docker run --rm \
  -v /home/angelo/Downloads/docker-compose-nas/jellyseerr:/data \
  alpine chown -R 1000:1000 /data

# Stop old container
sudo docker stop jellyseerr && sudo docker rm jellyseerr

# Start new seerr container
sudo docker compose up -d seerr
```

A `seerr → jellyseerr` symlink is in place — no data is lost.
Env vars renamed: `JELLYSEERR_API_KEY` → `SEERR_API_KEY`,
`JELLYSEERR_HOSTNAME` → `SEERR_HOSTNAME` (same values kept).

## New upstream services

- `suggestarr` — automated media content recommendations (enable with `COMPOSE_PROFILES=suggestarr`)
- `paperless` — Paperless-NGX document management (enable with `COMPOSE_PROFILES=paperless`)
- `immich-backup` — Restic backup for Immich photos
- `cross-seed`, `huntarr`, `autobrr` — moved from personal `compose.media-extras.yml` to upstream base `docker-compose.yml`

## Upstream service updates

- **Traefik** — bumped to 3.6 in base (personal overrides still pin 3.4)
- **Watchtower** — switched to `nicholas-fedor/watchtower` fork; added `WATCHTOWER_DEBUG=true`, `WATCHTOWER_INCLUDE_STOPPED=true`
- **qBittorrent** — added `drop-encoding` middleware (VueTorrent fix #2718)
- **VPN** — added `ACTIVE_HEALTHCHECKS=1`, `RECONNECT=1`
- **Cleanuparr** — improved healthcheck; volumes for logs and `ignored.txt`
- **AdGuard Home** — healthcheck now verifies IP binding + `start_period`
- **Immich** — updated to Immich 2, new Postgres image, updated upload path
- **Mosquitto** — logging configuration added
- **Tandoor** — updated Nginx upstream configuration

## Personal changes since v1.0.0

- `autobrr` removed from `compose.media-extras.yml` (now managed by upstream base)
- `compose.overrides.yml` seerr block updated (all jellyseerr references renamed to seerr)
