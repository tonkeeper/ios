#!/bin/bash
# Generate the swift-openapi-generator client for one API, or for all of them. The spec is
# <repo>/shared/api/<api>.yaml for an API shared with Android, otherwise scripts/apigen/schemas/<api>.yml.
#
# Every client is generated with types/client modes and public access. Per-API data is the
# spec, destination target, optional configs/<api>.yaml, and whether its enums are open.
# Each API used to carry its own copy of this script plus its own generator
# package; three of those committed a lockfile and two did not, so the generator
# version — and therefore the generated code — depended on who ran it.
#
# Usage:
#   scripts/apigen/generate.sh <api|all>
#   scripts/apigen/generate.sh --check <api|all>   # diff against the checked-in sources
set -euo pipefail

# Physical, like GIT_ROOT: the staged target is the package path relative to it.
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
GIT_ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)
PACKAGES_DIR="${REPO_ROOT}/LocalPackages/KeeperCore/Packages"
SPECS_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)/shared/api"
[ -d "$SPECS_DIR" ] || SPECS_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)/api"

# <api name> <destination target under LocalPackages/KeeperCore/Packages>
APIS=(
  "multichain MultichainAPI"
  "swap SwapAPI"
  "tonconnect TonConnectAPI"
  "tonkeeper TKTonkeeperAPI"
  "trading TKTradingAPI"
  "perps TKPerpsAPI"
  "battery TKBatteryAPI"
  "kandelabr TKKandelabrAPI"
  "tonapi TonAPI"
)

# APIs whose string enums decode a value the spec does not list as `unknown` instead of failing
# the whole response; their call sites handle `unknown`.
OPEN_ENUM_APIS=(trading perps battery multichain tonapi)

api_names() {
  local entry
  for entry in "${APIS[@]}"; do
    echo "${entry%% *}"
  done
}

target_of() {
  local entry
  for entry in "${APIS[@]}"; do
    if [ "${entry%% *}" = "$1" ]; then
      echo "${entry#* }"
      return 0
    fi
  done
  return 1
}

sources_of() {
  echo "$PACKAGES_DIR/$(target_of "$1")/Sources/$(target_of "$1")"
}

spec_of() {
  if [ -n "${API_SPEC_PATH:-}" ]; then
    echo "$API_SPEC_PATH"
  elif [ -f "${SPECS_DIR}/$1.yaml" ]; then
    echo "${SPECS_DIR}/$1.yaml"
  else
    echo "${SCRIPT_DIR}/schemas/$1.yml"
  fi
}

spec_label() {
  local spec
  spec="$(spec_of "$1")"
  echo "${spec#"$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"/}"
}

has_open_enums() {
  local api
  for api in "${OPEN_ENUM_APIS[@]}"; do
    [ "$api" = "$1" ] && return 0
  done
  return 1
}

# swift-openapi-generator emits a closed `@frozen enum` for every string enum. Give each one an
# `unknown` case that unknown values decode to; an enum whose spec already has `unknown` falls
# back to that.
open_enums() {
  python3 "$SCRIPT_DIR/open_enums.py" "$1"
}

usage() {
  echo "usage: $0 [--check] <$(api_names | paste -sd '|' -)|all>" >&2
  exit 2
}

generate_into() {
  local api="$1" out="$2" schema
  schema="$(spec_of "$api")"

  if [ ! -f "$schema" ]; then
    echo "error: schema not found: $schema" >&2
    return 1
  fi

  mkdir -p "$out" || return $?
  local args=(--mode types --mode client --access-modifier public)
  if [ -f "$SCRIPT_DIR/configs/$api.yaml" ]; then
    args+=(--config "$SCRIPT_DIR/configs/$api.yaml")
  fi
  (
    cd "$SCRIPT_DIR" || exit $?
    swift run --disable-automatic-resolution swift-openapi-generator generate \
      "${args[@]}" \
      --output-directory "$out" \
      "$schema"
  ) || return $?
  if has_open_enums "$api"; then
    open_enums "$out"
  fi
}

generate_api() {
  local api="$1" target relative
  target="$(target_of "$api")"
  relative="$(sources_of "$api")"
  relative="${relative#"$GIT_ROOT"/}"
  echo "generating ${target} from $(spec_label "$api")"
  generate_into "$api" "$STAGE/$relative"
  printf '%s\n' "$relative" >> "$STAGE/.api-generation-targets"
}

check_api() {
  local api="$1" target tmp status=0
  target="$(target_of "$api")"
  tmp="$TMP/$api"
  mkdir -p "$tmp" || return $?

  echo "checking ${target} against $(spec_label "$api")"
  # Explicit status: errexit does not apply inside a function called in a || list,
  # so a failed generation would otherwise be reported as a source mismatch.
  if ! generate_into "$api" "$tmp"; then
    echo "error: generating ${target} from $(spec_label "$api") failed" >&2
    rm -rf "$tmp"
    return 1
  fi

  # One diff, captured: `diff | head` would leave diff killed by SIGPIPE on a long diff,
  # and `sed -n` reads its input to the end, so nothing can abort the function before the
  # temp dir is removed. Capturing stderr too keeps a diff failure (a missing destination,
  # say) reported as a mismatch rather than silently passing.
  local diff_output diff_status=0
  diff_output="$(diff -ru "$(sources_of "$api")" "$tmp" 2>&1)" || diff_status=$?
  if [ "$diff_status" -ne 0 ]; then
    echo "error: ${target} does not match $(spec_label "$api"); run: make ${api}_generate" >&2
    printf '%s\n' "$diff_output" | sed -n '1,50p' >&2
    status=1
  fi

  rm -rf "$tmp"
  return $status
}

mode=generate
if [ "${1:-}" = "--check" ]; then
  mode=check
  shift
fi

selector="${1:-}"
[ -n "$selector" ] || usage
if [ "$selector" = --list ]; then
  printf '%s\n' "${APIS[@]}"
  exit 0
fi
[ -z "${API_SPEC_PATH:-}" ] || [ "$selector" != all ] || usage

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
STAGE=${API_GENERATION_STAGE:-$TMP}

if [ "$selector" = "all" ]; then
  selected=$(api_names)
else
  target_of "$selector" >/dev/null || usage
  selected="$selector"
fi

status=0
while IFS= read -r api; do
  [ -n "$api" ] || continue
  if [ "$mode" = "check" ]; then
    check_api "$api" || status=1
  else
    generate_api "$api"
  fi
done <<EOF
$selected
EOF

if [ "$mode" = generate ] && [ -z "${API_GENERATION_STAGE:-}" ]; then
  publisher="$GIT_ROOT/shared/tools/api-generation.py"
  [ -f "$publisher" ] || publisher="$GIT_ROOT/tools/api-generation.py"
  python3 "$publisher" "$STAGE" "$GIT_ROOT"
fi

exit $status
