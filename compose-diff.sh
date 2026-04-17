#!/usr/bin/env bash
# Usage: ./compose-diff.sh <project_name>
# Example: ./compose-diff.sh myproj
set -euo pipefail

PROJECT="${1:-}"
if [[ -z "$PROJECT" ]]; then
  echo "Usage: $0 <project_name>"
  exit 1
fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1"; exit 1; }; }
need jq
need diff

TS="$(date +%Y%m%d-%H%M%S)"
OUTDIR="compose-diff-$PROJECT-$TS"
mkdir -p "$OUTDIR"
echo "Output dir: $OUTDIR"

# 1) CURRENT (running) -> running.json
CONTAINERS=$(sudo docker compose -p "$PROJECT" ps -q || true)
if [[ -z "$CONTAINERS" ]]; then
  echo "No running containers found for project '$PROJECT'." | tee "$OUTDIR/NOTE.txt"
  # Still capture desired state for inspection
else
  sudo docker inspect $CONTAINERS \
  | jq -c '.[] | {
      Name: .Name,
      Image: .Config.Image,
      ImageID: .Image,
      Env: (.Config.Env // []),
      Ports: (.NetworkSettings.Ports // {}),
      Binds: (.HostConfig.Binds // []),
      Mounts: ( .Mounts
                | map({ type: .Type, source: .Source, target: .Destination, rw: .RW }) ),
      Labels: (.Config.Labels // {}),
      Command: (.Config.Cmd // []),
      Entrypoint: (.Config.Entrypoint // []),
      Networks: ( .NetworkSettings.Networks | keys // [] )
    }' > "$OUTDIR/running.json"
fi

# 2) DESIRED (compose convert) -> desired.json
sudo docker compose -p "$PROJECT" convert --format json \
| jq -c '
  .services
  | to_entries[]
  | {
      Name: ("/" + .key),
      Image: (.value.image // null),
      Env: (
        (.value.environment // {})
        | to_entries | map("\(.key)=\(.value)")
      ),
      Ports: (
        # Normalize ports (just for diffing readability)
        (.value.ports // [])
        | map(
            if type=="string" then .
            else
              ( ( (.target|tostring)
                  + (if has("protocol") then "/" + .protocol else "" end) )
                + ":" + (.published|tostring) )
            end
          )
      ),
      Binds: (
        (.value.volumes // [])
        | map(
            select(.type=="bind" or has("source"))
            | ((.source // "") + ":" + (.target // "") + (if (.read_only // false) then ":ro" else "" end))
          )
      ),
      Mounts: (
        (.value.volumes // [])
        | map({
            type: (if has("type") then .type else (if has("source") then "bind" else "volume" end) end),
            source: (.source // .type // ""),
            target: (.target // ""),
            rw: (if (.read_only // false) then false else true end)
          })
      ),
      Labels: (.value.labels // {}),
      Command: (
        if (.value.command|type)=="string" then [ .value.command ]
        else (.value.command // [])
        end
      ),
      Entrypoint: (
        if (.value.entrypoint|type)=="string" then [ .value.entrypoint ]
        else (.value.entrypoint // [])
        end
      ),
      Networks: (
        (.value.networks // {})
        | (if type=="array" then . else (keys) end)
      )
    }' > "$OUTDIR/desired.json"

# 3) Sort by Name
if [[ -f "$OUTDIR/running.json" ]]; then
  jq -s 'sort_by(.Name)[]' "$OUTDIR/running.json"  > "$OUTDIR/running.sorted.json"
else
  echo "[]" | jq -s '.[0]' > "$OUTDIR/running.sorted.json"
fi
jq -s 'sort_by(.Name)[]' "$OUTDIR/desired.json"  > "$OUTDIR/desired.sorted.json"

# 4) Produce diffs
report() {
  local field="$1"
  local pretty="${2:-0}"  # 1 => raw, 0 => compact
  local L R
  if [[ "$pretty" == "1" ]]; then
    L='.Name, .'$field
    R='.Name, .'$field
    diff -u <(jq -r "$L" "$OUTDIR/running.sorted.json") \
            <(jq -r "$R" "$OUTDIR/desired.sorted.json") || true
  else
    L='.Name, .'$field
    R='.Name, .'$field
    diff -u <(jq -c "$L" "$OUTDIR/running.sorted.json") \
            <(jq -c "$R" "$OUTDIR/desired.sorted.json") || true
  fi
}

{
  echo "### Image"
  report Image 1
  echo
  echo "### Env"
  report Env
  echo
  echo "### Ports"
  report Ports
  echo
  echo "### Binds"
  report Binds
  echo
  echo "### Mounts"
  report Mounts
  echo
  echo "### Labels"
  report Labels
  echo
  echo "### Command"
  report Command
  echo
  echo "### Entrypoint"
  report Entrypoint
  echo
  echo "### Networks"
  report Networks
} | tee "$OUTDIR/diff-report.txt"

echo "Done. See:"
echo "  $OUTDIR/running.sorted.json   # current containers (normalized)"
echo "  $OUTDIR/desired.sorted.json   # compose convert (normalized)"
echo "  $OUTDIR/diff-report.txt       # field-by-field differences"

