#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

ANALYTICS_SCHEMAS_REPO_URL=${ANALYTICS_SCHEMAS_REPO_URL:-git@github.com:tonkeeper/analytics-schemas.git}
# Checkouts shared across the repository live in .context at the repository root.
ANALYTICS_SCHEMAS_ROOT=${ANALYTICS_SCHEMAS_ROOT:-"$(git rev-parse --show-toplevel)/.context/analytics-schemas"}
SRC_DIR=${ANALYTICS_MODELS_SRC_DIR:-"$ANALYTICS_SCHEMAS_ROOT/generated/openapi-swift/TonkeeperAnalytics/Classes/OpenAPIs/Models"}
GENERATED_DIR=${ANALYTICS_GENERATED_DIR:-"$REPO_ROOT/LocalPackages/TKCore/Sources/TKCore/Analytics/Events/Generated"}
DEPRECATED_DIR=${ANALYTICS_DEPRECATED_DIR:-"$REPO_ROOT/LocalPackages/TKCore/Sources/TKCore/Analytics/Events/Deprecated"}
WHITELIST_FILE=${ANALYTICS_WHITELIST_FILE:-"$SCRIPT_DIR/event_model_whitelist.txt"}

tmp_whitelist=$(mktemp)
tmp_entries=$(mktemp)
tmp_list=$(mktemp)

cleanup() {
  rm -f "$tmp_whitelist" "$tmp_entries" "$tmp_list"
}

trap cleanup EXIT

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

mkdir -p "$GENERATED_DIR" "$DEPRECATED_DIR"

while IFS= read -r line || [ -n "$line" ]; do
  line=${line%$'\r'}
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
  generated_file="$GENERATED_DIR/$filename"
  deprecated_file="$DEPRECATED_DIR/$filename"

  if [ -f "$src_file" ]; then
    cp "$src_file" "$generated_file"

    if [ -f "$deprecated_file" ]; then
      rm -f "$deprecated_file"
      echo "Synced $filename to Generated and removed deprecated copy"
    else
      echo "Synced $filename to Generated"
    fi

    continue
  fi

  if [ -f "$generated_file" ]; then
    mv "$generated_file" "$deprecated_file"
    echo "Moved $filename to Deprecated (missing in schema)"
    continue
  fi

  if [ -f "$deprecated_file" ]; then
    echo "Kept $filename in Deprecated (missing in schema)"
    continue
  fi

  echo "Missing source model and no deprecated backport file found: $filename" >&2
  exit 1

done <"$WHITELIST_FILE"

for generated_file in "$GENERATED_DIR"/*.swift; do
  [ -e "$generated_file" ] || continue
  base_name=$(basename "$generated_file")
  if ! grep -qxF "$base_name" "$tmp_list"; then
    rm "$generated_file"
    echo "Removed $base_name (not in whitelist)"
  fi

done

for deprecated_file in "$DEPRECATED_DIR"/*.swift; do
  [ -e "$deprecated_file" ] || continue
  base_name=$(basename "$deprecated_file")
  if ! grep -qxF "$base_name" "$tmp_list"; then
    rm "$deprecated_file"
    echo "Removed deprecated $base_name (not in whitelist)"
  fi

done
