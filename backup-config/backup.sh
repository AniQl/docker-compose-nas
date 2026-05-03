#!/usr/bin/env bash
set -Eeuo pipefail

TMP_FILES=()

log() {
  printf '[%s] %s\n' "$(date -Iseconds)" "$*" >&2
}

fail() {
  log "ERROR: $*"
  exit 1
}

make_tmp_file() {
  local file
  file="$(mktemp)"
  TMP_FILES+=("$file")
  printf '%s' "$file"
}

cleanup() {
  if [ "${#TMP_FILES[@]}" -gt 0 ]; then
    rm -f "${TMP_FILES[@]}"
  fi

  # The repository lives remotely. Keep local cache ephemeral.
  rm -rf "${RESTIC_CACHE_DIR:-/tmp/restic-cache}" "${RCLONE_CACHE_DIR:-/tmp/rclone-cache}"
}

trap cleanup EXIT

require_env() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    fail "Required environment variable ${name} is not set"
  fi
}

prepare_environment() {
  export BACKUP_SOURCE_ROOT="${BACKUP_SOURCE_ROOT:-/source}"
  export BACKUP_INCLUDE_FILE="${BACKUP_INCLUDE_FILE:-/app/include.txt}"
  export BACKUP_EXCLUDE_FILE="${BACKUP_EXCLUDE_FILE:-/app/exclude.txt}"
  export BACKUP_RESTORE_TARGET="${BACKUP_RESTORE_TARGET:-/restore}"
  export RESTIC_CACHE_DIR="${RESTIC_CACHE_DIR:-/tmp/restic-cache}"
  export RCLONE_CACHE_DIR="${RCLONE_CACHE_DIR:-/tmp/rclone-cache}"
  export RCLONE_CONFIG="${RCLONE_CONFIG:-/config/rclone/rclone.conf}"

  require_env RESTIC_REPOSITORY
  require_env RESTIC_PASSWORD

  if [[ "$RESTIC_REPOSITORY" == rclone:* ]] && [ ! -f "$RCLONE_CONFIG" ]; then
    fail "Rclone config not found at ${RCLONE_CONFIG}. Run: docker compose run --rm -it config-backup rclone config"
  fi

  mkdir -p "$RESTIC_CACHE_DIR" "$RCLONE_CACHE_DIR"
}

init_repo_if_needed() {
  if restic snapshots >/dev/null 2>&1; then
    return
  fi

  log "Restic repository is not initialized or not reachable. Trying restic init."
  restic init
}

build_config_files_from() {
  local files_from
  local line
  local path

  files_from="$(make_tmp_file)"

  [ -f "$BACKUP_INCLUDE_FILE" ] || fail "Include file not found: ${BACKUP_INCLUDE_FILE}"

  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="${line%$'\r'}"

    if [ -z "$line" ]; then
      continue
    fi

    path="${BACKUP_SOURCE_ROOT}/${line}"
    if [ -e "$path" ]; then
      printf '%s\n' "$path" >> "$files_from"
    else
      log "Skipping missing path: ${line}"
    fi
  done < "$BACKUP_INCLUDE_FILE"

  if [ ! -s "$files_from" ]; then
    fail "No existing config paths found from ${BACKUP_INCLUDE_FILE}"
  fi

  printf '%s' "$files_from"
}

latest_homeassistant_backup() {
  local candidate
  local latest=""

  for candidate in \
    "$BACKUP_SOURCE_ROOT"/homeassistant/backups/*.tar \
    "$BACKUP_SOURCE_ROOT"/homeassistant/backups/*.tar.gz; do
    [ -e "$candidate" ] || continue

    if [ -z "$latest" ] || [ "$candidate" -nt "$latest" ]; then
      latest="$candidate"
    fi
  done

  printf '%s' "$latest"
}

backup_config_paths() {
  local files_from

  files_from="$(build_config_files_from)"
  log "Backing up config paths listed in ${BACKUP_INCLUDE_FILE}"

  restic backup \
    --files-from "$files_from" \
    --exclude-file "$BACKUP_EXCLUDE_FILE" \
    --tag homelab \
    --tag config
}

backup_latest_homeassistant_backup() {
  local latest_backup

  latest_backup="$(latest_homeassistant_backup)"
  if [ -z "$latest_backup" ]; then
    log "No Home Assistant backup archive found under homeassistant/backups; skipping HA backup archive snapshot"
    return
  fi

  log "Backing up latest Home Assistant backup archive: ${latest_backup#${BACKUP_SOURCE_ROOT}/}"
  restic backup \
    "$latest_backup" \
    --tag homelab \
    --tag homeassistant-backup
}

print_backup_plan() {
  local files_from
  local path
  local latest_backup

  files_from="$(build_config_files_from)"
  log "Config paths that would be considered for backup:"
  while IFS= read -r path; do
    printf '%s\n' "${path#${BACKUP_SOURCE_ROOT}/}"
  done < "$files_from"

  latest_backup="$(latest_homeassistant_backup)"
  if [ -n "$latest_backup" ]; then
    log "Latest Home Assistant backup archive:"
    printf '%s\n' "${latest_backup#${BACKUP_SOURCE_ROOT}/}"
  else
    log "No Home Assistant backup archive found under homeassistant/backups"
  fi
}

apply_retention() {
  local config_forget_args
  local ha_forget_args

  config_forget_args="${RESTIC_FORGET_ARGS:---keep-last 14 --keep-daily 14 --keep-weekly 8 --keep-monthly 12}"
  ha_forget_args="${HA_RESTIC_FORGET_ARGS:---keep-last 3 --keep-daily 3}"

  log "Applying config snapshot retention: ${config_forget_args}"
  # shellcheck disable=SC2086
  restic forget --tag config $config_forget_args

  log "Applying Home Assistant backup archive retention: ${ha_forget_args}"
  # shellcheck disable=SC2086
  restic forget --tag homeassistant-backup $ha_forget_args

  log "Pruning remote Restic repository"
  restic prune
}

run_backup() {
  prepare_environment
  init_repo_if_needed
  backup_config_paths
  backup_latest_homeassistant_backup
  apply_retention
  log "Backup completed successfully"
}

run_restore() {
  prepare_environment

  local snapshot="${1:-latest}"
  local target="${2:-$BACKUP_RESTORE_TARGET}"

  mkdir -p "$target"
  log "Restoring snapshot ${snapshot} into ${target}"
  restic restore "$snapshot" --target "$target"
}

run_daemon() {
  local schedule="${BACKUP_CRON:-30 3 * * *}"
  local cron_parts

  read -r -a cron_parts <<< "$schedule"
  if [ "${#cron_parts[@]}" -ne 5 ]; then
    fail "BACKUP_CRON must use 5-field cron syntax, for example: 30 3 * * *"
  fi

  if [ "${RUN_ON_STARTUP:-false}" = "true" ]; then
    run_backup
  fi

  log "Starting cron with schedule: ${schedule}"
  {
    printf 'SHELL=/bin/bash\n'
    printf 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n'
    printf '%s /usr/local/bin/config-backup backup >> /proc/1/fd/1 2>> /proc/1/fd/2\n' "$schedule"
  } > /etc/crontabs/root

  exec crond -f -l "${CRON_LOG_LEVEL:-8}"
}

run_rclone() {
  export RCLONE_CONFIG="${RCLONE_CONFIG:-/config/rclone/rclone.conf}"
  mkdir -p "$(dirname "$RCLONE_CONFIG")"

  if [ "$#" -eq 0 ]; then
    set -- config
  fi

  exec rclone --config "$RCLONE_CONFIG" "$@"
}

command="${1:-daemon}"
shift || true

case "$command" in
  daemon)
    run_daemon "$@"
    ;;
  backup)
    run_backup "$@"
    ;;
  restore)
    run_restore "$@"
    ;;
  snapshots)
    prepare_environment
    restic snapshots "$@"
    ;;
  check)
    prepare_environment
    restic check "$@"
    ;;
  list)
    prepare_environment
    print_backup_plan
    ;;
  rclone)
    run_rclone "$@"
    ;;
  *)
    fail "Unknown command: ${command}. Use daemon, backup, restore, snapshots, check, list, or rclone."
    ;;
esac
