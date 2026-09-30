#!/usr/bin/env bash
# Run Maestro flows for one CI shard (first attempt + optional per-flow retry).
#
# Required env:
#   ART              — debug/summary artifacts directory (absolute)
#   FLOW_DIR         — directory with *.yaml flows (absolute)
#   SHARD_ID         — shard id for summaries / retry state (e.g. backup, multichain-history)
#   REPO_ROOT        — repository root (absolute)
#   SCRIPTS          — maestro_ui_tests/scripts (absolute)
#   RUNNER_TEMP      — GitHub Actions temp dir
#   GHA_STATE_DIR    — optional prior failed-state dir for workflow re-run
#
# Optional env:
#   MAESTRO_RETRY_FAILED_FLOWS=1|0
#   GITHUB_RUN_ATTEMPT
#   WALLET_WITH_MONEY and other Maestro -e secrets (passed through by caller)

set -euo pipefail

: "${ART:?ART not set}"
: "${FLOW_DIR:?FLOW_DIR not set}"
: "${SHARD_ID:?SHARD_ID not set}"
: "${REPO_ROOT:?REPO_ROOT not set}"
: "${SCRIPTS:?SCRIPTS not set}"
: "${RUNNER_TEMP:?RUNNER_TEMP not set}"

source "${REPO_ROOT}/maestro_ui_tests/ci/native_token_env.sh"
maestro --version

mkdir -p "$ART" "$RUNNER_TEMP/maestro-test-output" "$RUNNER_TEMP/maestro-test-output-retry"

# Import shard pastes TON_v4 (TON-only v3/v4). Everything else pastes the shard's funded
# wallet — the workflow maps MAESTRO_WALLET_WITH_MONEY* to the TON or multichain seed per shard.
# Maestro setClipboard cannot feed the app Paste button on iOS — only UIPasteboard works.
prime_simulator_pasteboard() {
  local phrase
  if [[ "$SHARD_ID" == "import" || "$FLOW_DIR" == */import ]]; then
    phrase="${MAESTRO_TON_V4:-}"
    if [[ -z "$phrase" ]]; then
      echo "::error::MAESTRO_TON_V4 is required for import shard (${SHARD_ID})"
      return 1
    fi
    echo "::notice::Pasteboard primed with MAESTRO_TON_V4 for ${SHARD_ID}"
  else
    phrase="${MAESTRO_WALLET_WITH_MONEY:-}"
  fi
  PHRASE="$phrase" bash "$SCRIPTS/ci/simulator_pbcopy_phrase.sh"
}

run_maestro() {
  local debug_dir="$1"
  local out_dir="$2"
  shift 2
  prime_simulator_pasteboard
  set +e
  maestro --verbose test \
    -e PASSWORD_KEY=5 \
    -e "NATIVE_TOKEN_DISPLAY_TEXT=${NATIVE_TOKEN_DISPLAY_TEXT}" \
    -e "NATIVE_TOKEN_SHORT_TEXT=${NATIVE_TOKEN_SHORT_TEXT}" \
    -e "MNEMONIC_PHRASE=${MAESTRO_MNEMONIC_PHRASE:-}" \
    -e "WALLET_WITH_MONEY=${MAESTRO_WALLET_WITH_MONEY:-}" \
    -e "WALLET_WITH_MONEY_ADDR=${MAESTRO_WALLET_WITH_MONEY_ADDR:-}" \
    -e "auth=${MAESTRO_AUTH:-}" \
    -e "RECIEVE_WALLET=${MAESTRO_RECIEVE_WALLET:-}" \
    -e "TESTNET_MNEM=${MAESTRO_TESTNET_MNEM:-}" \
    -e "TON_v4=${MAESTRO_TON_V4:-}" \
    -p ios \
    --test-output-dir "$out_dir" \
    --debug-output "$debug_dir" \
    --flatten-debug-output \
    "$@"
  local code=$?
  set -e
  return "$code"
}

retry_failed_paths_loop() {
  mkdir -p "$ART/retry"
  : > "$ART/maestro-retry.log"
  local retry_exit=0
  for _raw in "${FAILED_PATHS[@]}"; do
    p="${_raw//$'\r'/}"
    [[ -n "$p" ]] || continue
    if [[ ! -f "$p" ]]; then
      echo "::warning::Retry path missing or not a file (skip): $p"
      retry_exit=1
      continue
    fi
    safe="$(basename "$p" .yaml)"
    dbg="$ART/retry/$safe"
    out="$RUNNER_TEMP/maestro-test-output-retry-$safe"
    mkdir -p "$dbg" "$out"
    echo "::notice::Maestro retry: $p"
    set +e
    run_maestro "$dbg" "$out" "$p"
    code=$?
    set -e
    if [[ "$code" -ne 0 ]]; then
      retry_exit="$code"
    fi
    if [[ -f "$dbg/maestro.log" ]]; then
      {
        echo "===== RETRY: $p (exit $code) ====="
        cat "$dbg/maestro.log"
        echo ""
      } >> "$ART/maestro-retry.log"
    fi
  done
  printf '%s' "$retry_exit" > "$ART/maestro-exit.txt"
  return "$retry_exit"
}

GHA_STATE_DIR="${GHA_STATE_DIR:-}"

if [[ "${GITHUB_RUN_ATTEMPT:-1}" -gt 1 ]] && [[ -n "$GHA_STATE_DIR" ]] && [[ -s "$GHA_STATE_DIR/failed_paths.txt" ]]; then
  echo "::notice::GitHub workflow re-run (attempt ${GITHUB_RUN_ATTEMPT}): only previously failed flows"
  touch "$ART/maestro-gha-rerun.flag"
  cp -f "$GHA_STATE_DIR/state.json" "$ART/gha-rerun-prior-state.json"
  FAILED_PATHS=()
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line//$'\r'/}"
    [[ -n "${line}" ]] || continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    FAILED_PATHS+=("$line")
  done < "$GHA_STATE_DIR/failed_paths.txt"
  if [[ ${#FAILED_PATHS[@]} -eq 0 ]]; then
    echo "::warning::failed_paths.txt was empty; running the full shard directory as fallback."
    rm -f "$ART/maestro-gha-rerun.flag" "$ART/gha-rerun-prior-state.json"
  else
    printf '%s' "1" > "$ART/maestro-exit-first.txt"
    printf '%s\n' "${FAILED_PATHS[@]}" > "$ART/maestro-retry-flow-paths.txt"
    echo "Re-running ${#FAILED_PATHS[@]} failed flow(s) from prior workflow attempt"
    set +e
    retry_failed_paths_loop
    rerun_code=$?
    set -e
    exit "$rerun_code"
  fi
fi

set +e
run_maestro "$ART" "$RUNNER_TEMP/maestro-test-output" "$FLOW_DIR"
FIRST_EXIT=$?
set -e
printf '%s' "$FIRST_EXIT" > "$ART/maestro-exit-first.txt"

if [[ "$FIRST_EXIT" -eq 0 ]]; then
  printf '%s' "0" > "$ART/maestro-exit.txt"
  exit 0
fi

RETRY_ENABLED="${MAESTRO_RETRY_FAILED_FLOWS:-1}"
if [[ "$RETRY_ENABLED" == "0" ]]; then
  printf '%s' "$FIRST_EXIT" > "$ART/maestro-exit.txt"
  exit "$FIRST_EXIT"
fi

if [[ ! -f "$ART/maestro.log" ]]; then
  echo "::warning::No maestro.log after first run; cannot resolve failed flows for retry."
  printf '%s' "$FIRST_EXIT" > "$ART/maestro-exit.txt"
  exit "$FIRST_EXIT"
fi

FAILED_PATHS=()
while IFS= read -r line || [[ -n "${line}" ]]; do
  line="${line//$'\r'/}"
  [[ -n "$line" ]] || continue
  FAILED_PATHS+=("$line")
done < <(python3 "$SCRIPTS/ci/list_failed_maestro_flow_paths.py" \
  --log "$ART/maestro.log" \
  --flow-dir "$FLOW_DIR" \
  --shard-id "$SHARD_ID" \
  --repo-root "$REPO_ROOT")

if [[ ${#FAILED_PATHS[@]} -eq 0 ]]; then
  echo "::warning::First Maestro run failed but no failed flows parsed for retry."
  printf '%s' "$FIRST_EXIT" > "$ART/maestro-exit.txt"
  exit "$FIRST_EXIT"
fi

printf '%s\n' "${FAILED_PATHS[@]}" > "$ART/maestro-retry-flow-paths.txt"
echo "Retrying ${#FAILED_PATHS[@]} failed flow(s): ${FAILED_PATHS[*]}"

set +e
retry_failed_paths_loop
retry_code=$?
set -e
exit "$retry_code"
