#!/usr/bin/env bash
# Write Maestro CI summary files for one shard (first attempt + optional retry merge).
#
# Required env:
#   ART, SCRIPTS, SHARD_ID
# Optional env:
#   FLOW_DIR — shard flow directory; disambiguates yaml line resolution when the same
#   stem exists in several shards (tonstakers_* in staking and ton_staking).

set -euo pipefail

: "${ART:?ART not set}"
: "${SCRIPTS:?SCRIPTS not set}"
: "${SHARD_ID:?SHARD_ID not set}"

FLOW_DIR_ARGS=()
if [[ -n "${FLOW_DIR:-}" ]]; then
  FLOW_DIR_ARGS=(--flow-dir "$FLOW_DIR")
fi

CODE=1
if [[ -f "$ART/maestro-exit.txt" ]]; then
  read -r _code < "$ART/maestro-exit.txt" || _code=1
  if [[ -n "$_code" && "$_code" =~ ^[0-9]+$ ]]; then
    CODE="$_code"
  fi
fi

FIRST_CODE="$CODE"
if [[ -f "$ART/maestro-exit-first.txt" ]]; then
  read -r _fc < "$ART/maestro-exit-first.txt" || _fc=""
  if [[ -n "$_fc" && "$_fc" =~ ^[0-9]+$ ]]; then
    FIRST_CODE="$_fc"
  fi
fi

if [[ -f "$ART/maestro-gha-rerun.flag" ]] && [[ -f "$ART/gha-rerun-prior-state.json" ]]; then
  if [[ ! -f "$ART/maestro-retry.log" ]]; then
    echo "::warning::GitHub re-run mode but maestro-retry.log missing; summary may be incomplete." >&2
  fi
  python3 "$SCRIPTS/ci/merge_maestro_github_rerun_summary.py" \
    --prior-state "$ART/gha-rerun-prior-state.json" \
    --retry-log "$ART/maestro-retry.log" \
    --flow-group "$SHARD_ID" \
    --exit "$CODE" \
    --out "$ART/maestro-ci-summary.txt" \
    "${FLOW_DIR_ARGS[@]}"
  cp -f "$ART/maestro-ci-summary.txt" "$ART/maestro-ci-summary-retry.txt"
  echo "(merged GitHub workflow re-run summary)" > "$ART/maestro-ci-summary-first.txt"
elif [[ -f "$ART/maestro.log" ]]; then
  python3 "$SCRIPTS/ci/summarize_maestro_log.py" \
    --log "$ART/maestro.log" \
    --out "$ART/maestro-ci-summary-first.txt" \
    --flow-group "$SHARD_ID" \
    --exit "$FIRST_CODE" \
    "${FLOW_DIR_ARGS[@]}"
  if [[ -f "$ART/maestro-retry.log" ]]; then
    python3 "$SCRIPTS/ci/summarize_maestro_log.py" \
      --log "$ART/maestro-retry.log" \
      --out "$ART/maestro-ci-summary-retry.txt" \
      --flow-group "$SHARD_ID" \
      --exit "$CODE" \
      "${FLOW_DIR_ARGS[@]}"
    {
      cat "$ART/maestro-ci-summary-first.txt"
      echo ""
      echo "=== Retry (failed YAML flows only) ==="
      cat "$ART/maestro-ci-summary-retry.txt"
    } > "$ART/maestro-ci-summary.txt"
  else
    cp -f "$ART/maestro-ci-summary-first.txt" "$ART/maestro-ci-summary.txt"
  fi
else
  echo "No $ART/maestro.log; skipping maestro-ci-summary." >&2
fi

if [[ -f "$ART/maestro-ci-summary.txt" && -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  echo "### Maestro ($SHARD_ID)" >> "$GITHUB_STEP_SUMMARY"
  echo "" >> "$GITHUB_STEP_SUMMARY"
  echo '```' >> "$GITHUB_STEP_SUMMARY"
  cat "$ART/maestro-ci-summary.txt" >> "$GITHUB_STEP_SUMMARY"
  echo '```' >> "$GITHUB_STEP_SUMMARY"
fi
