#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

ANALYTICS_SCHEMAS_REPO_URL=${ANALYTICS_SCHEMAS_REPO_URL:-git@github.com:tonkeeper/analytics-schemas.git}
ANALYTICS_SCHEMAS_ROOT=${ANALYTICS_SCHEMAS_ROOT:-"$REPO_ROOT/.context/analytics-schemas"}
SRC_DIR="$ANALYTICS_SCHEMAS_ROOT/generated/openapi-swift/TonkeeperAnalytics/Classes/OpenAPIs/Models"
DEST_DIR="$REPO_ROOT/LocalPackages/TKCore/Sources/TKCore/Analytics/Events/Generated"
WHITELIST_FILE="$SCRIPT_DIR/event_model_whitelist.txt"

if [ ! -d "$ANALYTICS_SCHEMAS_ROOT" ]; then
  mkdir -p "$(dirname "$ANALYTICS_SCHEMAS_ROOT")"
  git clone "$ANALYTICS_SCHEMAS_REPO_URL" "$ANALYTICS_SCHEMAS_ROOT"
else
  if [ -d "$ANALYTICS_SCHEMAS_ROOT/.git" ]; then
    git -C "$ANALYTICS_SCHEMAS_ROOT" fetch --prune origin
    git -C "$ANALYTICS_SCHEMAS_ROOT" pull --ff-only origin
  else
    echo "Analytics schemas path exists but is not a git repo: $ANALYTICS_SCHEMAS_ROOT" >&2
    exit 1
  fi
fi

if [ ! -d "$SRC_DIR" ]; then
  echo "Missing analytics schemas models directory: $SRC_DIR" >&2
  exit 1
fi

if [ ! -f "$WHITELIST_FILE" ]; then
  echo "Missing whitelist file: $WHITELIST_FILE" >&2
  exit 1
fi

# Keep whitelist entries sorted automatically on each sync.
tmp_whitelist=$(mktemp)
tmp_entries=$(mktemp)

while IFS= read -r line || [ -n "$line" ]; do
  line=${line%$'\r'}
  case "$line" in
  '')
    ;;
  \#*)
    echo "$line" >>"$tmp_whitelist"
    ;;
  *)
    echo "$line" >>"$tmp_entries"
    ;;
  esac
done <"$WHITELIST_FILE"

if [ -s "$tmp_entries" ]; then
  sort -u "$tmp_entries" >>"$tmp_whitelist"
fi

mv "$tmp_whitelist" "$WHITELIST_FILE"
rm -f "$tmp_entries"

mkdir -p "$DEST_DIR"

tmp_list=$(mktemp)

while IFS= read -r line || [ -n "$line" ]; do
  line=${line%$''}
  case "$line" in
  '' | \#*)
    continue
    ;;
  esac

  if [[ "$line" == *.swift ]]; then
    filename="$line"
  else
    filename="$line.swift"
  fi

  echo "$filename" >>"$tmp_list"
  src_file="$SRC_DIR/$filename"

  if [ ! -f "$src_file" ]; then
    echo "Missing source model: $src_file" >&2
    rm -f "$tmp_list"
    exit 1
  fi

  cp "$src_file" "$DEST_DIR/$filename"
  echo "Synced $filename"

done <"$WHITELIST_FILE"

for dest_file in "$DEST_DIR"/*.swift; do
  [ -e "$dest_file" ] || continue
  base_name=$(basename "$dest_file")
  if ! grep -qx "$base_name" "$tmp_list"; then
    rm "$dest_file"
    echo "Removed $base_name (not in whitelist)"
  fi

done

rm -f "$tmp_list"
