#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BACKREST_URL="${BACKREST_URL:-http://127.0.0.1:9898}"
BACKREST_URL="${BACKREST_URL%/}"

BACKREST_REPO_ID="${BACKREST_REPO_ID:-gdrive-config}"
BACKREST_REPO_URI="${BACKREST_REPO_URI:-rclone:gdrive:/docker-compose-nas/config-backups}"
BACKREST_INSTANCE="${BACKREST_INSTANCE:-docker-compose-nas}"
BACKREST_BACKUP_CRON="${BACKREST_BACKUP_CRON:-0 6 */3 * *}"
BACKREST_PRUNE_CRON="${BACKREST_PRUNE_CRON:-0 7 * * 0}"
BACKREST_CHECK_CRON="${BACKREST_CHECK_CRON:-0 8 1 * *}"
BACKREST_PRUNE_MAX_UNUSED_PERCENT="${BACKREST_PRUNE_MAX_UNUSED_PERCENT:-10}"
BACKREST_CONFIG_PLAN_ID="${BACKREST_CONFIG_PLAN_ID:-homelab-config}"
BACKREST_HA_PLAN_ID="${BACKREST_HA_PLAN_ID:-homeassistant-backups}"
BACKREST_PATHS_FILE="${BACKREST_PATHS_FILE:-${SCRIPT_DIR}/homelab-config-paths.txt}"
BACKREST_EXCLUDES_FILE="${BACKREST_EXCLUDES_FILE:-${SCRIPT_DIR}/homelab-config-excludes.txt}"

log() {
  printf '[%s] %s\n' "$(date -Iseconds)" "$*" >&2
}

fail() {
  log "ERROR: $*"
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

prompt_if_missing() {
  local var_name="$1"
  local prompt="$2"
  local secret="${3:-false}"

  if [ -n "${!var_name:-}" ]; then
    return
  fi

  if [ ! -t 0 ]; then
    fail "${var_name} is required in non-interactive mode"
  fi

  if [ "$secret" = "true" ]; then
    read -r -s -p "$prompt" "$var_name"
    printf '\n' >&2
  else
    read -r -p "$prompt" "$var_name"
  fi

  export "$var_name"
}

curl_backrest() {
  local endpoint="$1"
  local payload="$2"
  local auth_args=()

  if [ "${BACKREST_NO_AUTH:-false}" != "true" ]; then
    auth_args=(-u "${BACKREST_USERNAME}:${BACKREST_PASSWORD}")
  fi

  curl -fsS \
    "${auth_args[@]}" \
    -H 'Content-Type: application/json' \
    -X POST \
    "${BACKREST_URL}/${endpoint}" \
    --data "$payload"
}

json_array_from_file() {
  local file="$1"

  [ -f "$file" ] || fail "File not found: $file"

  jq -Rsc '
    split("\n")
    | map(sub("\r$"; ""))
    | map(gsub("^\\s+"; "") | gsub("\\s+$"; ""))
    | map(select(. != "" and (startswith("#") | not)))
  ' "$file"
}

main() {
  require_command curl
  require_command jq

  if [ "${BACKREST_NO_AUTH:-false}" != "true" ]; then
    prompt_if_missing BACKREST_USERNAME 'Backrest username: '
    prompt_if_missing BACKREST_PASSWORD 'Backrest password: ' true
  fi
  prompt_if_missing RESTIC_PASSWORD 'Restic repository password: ' true

  local paths_json
  local excludes_json
  local current_config
  local next_config

  paths_json="$(json_array_from_file "$BACKREST_PATHS_FILE")"
  excludes_json="$(json_array_from_file "$BACKREST_EXCLUDES_FILE")"

  log "Fetching current Backrest config from ${BACKREST_URL}"
  current_config="$(curl_backrest 'v1.Backrest/GetConfig' '{}')"

  log "Building Backrest repository and backup plans"
  next_config="$(jq \
    --arg instance "$BACKREST_INSTANCE" \
    --arg repoId "$BACKREST_REPO_ID" \
    --arg repoUri "$BACKREST_REPO_URI" \
    --arg repoPassword "$RESTIC_PASSWORD" \
    --arg backupCron "$BACKREST_BACKUP_CRON" \
    --arg pruneCron "$BACKREST_PRUNE_CRON" \
    --arg checkCron "$BACKREST_CHECK_CRON" \
    --argjson pruneMaxUnusedPercent "$BACKREST_PRUNE_MAX_UNUSED_PERCENT" \
    --arg configPlanId "$BACKREST_CONFIG_PLAN_ID" \
    --arg haPlanId "$BACKREST_HA_PLAN_ID" \
    --argjson paths "$paths_json" \
    --argjson excludes "$excludes_json" \
    '
      def upsert_by_id($item):
        (. // []) as $items
        | if any($items[]?; .id == $item.id) then
            $items | map(if .id == $item.id then $item else . end)
          else
            $items + [$item]
          end;

      {
        id: $repoId,
        uri: $repoUri,
        password: $repoPassword,
        env: [],
        flags: [],
        autoUnlock: true,
        autoInitialize: true,
        prunePolicy: {
          schedule: {
            cron: $pruneCron,
            clock: "CLOCK_LOCAL"
          },
          maxUnusedPercent: $pruneMaxUnusedPercent
        },
        checkPolicy: {
          schedule: {
            cron: $checkCron,
            clock: "CLOCK_LOCAL"
          },
          structureOnly: true
        }
      } as $repo

      | {
        id: $configPlanId,
        repo: $repoId,
        paths: $paths,
        excludes: $excludes,
        schedule: {
          cron: $backupCron,
          clock: "CLOCK_LOCAL"
        },
        retention: {
          policyTimeBucketed: {
            daily: 14,
            weekly: 8,
            monthly: 12
          }
        },
        skipIfUnchanged: true
      } as $configPlan

      | {
        id: $haPlanId,
        repo: $repoId,
        paths: ["/source/homeassistant/backups"],
        excludes: [],
        schedule: {
          cron: $backupCron,
          clock: "CLOCK_LOCAL"
        },
        retention: {
          policyKeepLastN: 3
        },
        skipIfUnchanged: true
      } as $haPlan

      | .instance = (.instance // $instance)
      | .repos = ((.repos // []) | upsert_by_id($repo))
      | .plans = ((.plans // []) | upsert_by_id($configPlan) | upsert_by_id($haPlan))
    ' <<< "$current_config")"

  if [ "${BACKREST_DRY_RUN:-false}" = "true" ]; then
    log "Dry run enabled; generated config follows with repository password masked"
    jq --arg repoId "$BACKREST_REPO_ID" '
      (.repos[]? | select(.id == $repoId) | .password) = "********"
    ' <<< "$next_config"
    exit 0
  fi

  log "Writing Backrest config"
  curl_backrest 'v1.Backrest/SetConfig' "$next_config" >/dev/null

  log "Backrest config updated"
  log "Repository: ${BACKREST_REPO_ID} -> ${BACKREST_REPO_URI}"
  log "Plans: ${BACKREST_CONFIG_PLAN_ID}, ${BACKREST_HA_PLAN_ID}"
  log "Backup schedule: ${BACKREST_BACKUP_CRON} (container timezone should be Europe/Warsaw)"
}

main "$@"
