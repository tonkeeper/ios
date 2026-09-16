#!/bin/bash
# Generate the swift-openapi-generator client for one API, or for all of them.
#
# Every client is produced identically (--mode types --mode client), so the only
# per-API data is the schema file and the destination target — the table below.
# Each API used to carry its own copy of this script plus its own generator
# package; three of those committed a lockfile and two did not, so the generator
# version — and therefore the generated code — depended on who ran it.
#
# Usage:
#   scripts/apigen/generate.sh <api|all>
#   scripts/apigen/generate.sh --check <api|all>   # diff against the checked-in sources
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
PACKAGES_DIR="${REPO_ROOT}/LocalPackages/KeeperCore/Packages"

# <api name> <destination target under LocalPackages/KeeperCore/Packages>
APIS=(
  "multichain MultichainAPI"
  "swap SwapAPI"
  "tonconnect TonConnectAPI"
  "tonkeeper TKTonkeeperAPI"
  "trading TKTradingAPI"
  "perps TKPerpsAPI"
  "kandelabr TKKandelabrAPI"
)

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

usage() {
  echo "usage: $0 [--check] <$(api_names | paste -sd '|' -)|all>" >&2
  exit 2
}

generate_into() {
  local api="$1" out="$2"
  local schema="${SCRIPT_DIR}/schemas/${api}.yml"

  if [ ! -f "$schema" ]; then
    echo "error: schema not found: $schema" >&2
    return 1
  fi

  mkdir -p "$out"
  (
    cd "$SCRIPT_DIR"
    swift run swift-openapi-generator generate \
      --mode types --mode client \
      --output-directory "$out" \
      "$schema"
  )
}

generate_api() {
  local api="$1" target
  target="$(target_of "$api")"
  echo "generating ${target} from schemas/${api}.yml"
  generate_into "$api" "${PACKAGES_DIR}/${target}/Sources/${target}"
}

check_api() {
  local api="$1" target tmp status=0
  target="$(target_of "$api")"
  tmp="$(mktemp -d)"

  echo "checking ${target} against schemas/${api}.yml"
  # Explicit status: errexit does not apply inside a function called in a || list,
  # so a failed generation would otherwise be reported as a source mismatch.
  if ! generate_into "$api" "$tmp"; then
    echo "error: generating ${target} from schemas/${api}.yml failed" >&2
    rm -rf "$tmp"
    return 1
  fi

  # One diff, captured: `diff | head` would leave diff killed by SIGPIPE on a long diff,
  # and `sed -n` reads its input to the end, so nothing can abort the function before the
  # temp dir is removed. Capturing stderr too keeps a diff failure (a missing destination,
  # say) reported as a mismatch rather than silently passing.
  local diff_output diff_status=0
  diff_output="$(diff -ru "${PACKAGES_DIR}/${target}/Sources/${target}" "$tmp" 2>&1)" || diff_status=$?
  if [ "$diff_status" -ne 0 ]; then
    echo "error: ${target} does not match schemas/${api}.yml; run: make ${api}_generate" >&2
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

exit $status
