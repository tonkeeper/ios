#!/usr/bin/env bash
set -uo pipefail

if [[ "${#}" -lt 1 ]]; then
  echo "run_maestro_failed_paths.sh: no flow paths supplied" >&2
  exit 0
fi

: "${ART:?ART (maestro artifacts dir) not set}"
: "${RUNNER_TEMP:?RUNNER_TEMP not set}"
: "${PB_COPY_SCRIPT:?PB_COPY_SCRIPT not set}"
MAESTRO_NATIVE_TOKEN_ENV="${MAESTRO_NATIVE_TOKEN_ENV:-$(cd "$(dirname "$0")" && pwd)/native_token_env.sh}"
source "$MAESTRO_NATIVE_TOKEN_ENV"

mkdir -p "$ART/retry"
: > "$ART/maestro-retry.log"

retry_exit=0

for _raw in "$@"; do
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

  # Import flows need TON_v4 on UIPasteboard; Maestro setClipboard is not enough on iOS.
  if [[ "$p" == */import/* || "$p" == */import_wallet_ton_v*.yaml ]]; then
    if [[ -z "${MAESTRO_TON_V4:-}" ]]; then
      echo "::error::MAESTRO_TON_V4 is required to retry import flow: $p"
      retry_exit=1
      continue
    fi
    echo "::notice::Pasteboard primed with MAESTRO_TON_V4 for retry: $safe"
    PHRASE="${MAESTRO_TON_V4}" bash "$PB_COPY_SCRIPT"
  else
    PHRASE="${MAESTRO_WALLET_WITH_MONEY:-${WALLET_WITH_MONEY:-}}" \
      bash "$PB_COPY_SCRIPT"
  fi

  set +e
  maestro --verbose test \
    -e PASSWORD_KEY="$PASSWORD_KEY" \
    -e "NATIVE_TOKEN_DISPLAY_TEXT=${NATIVE_TOKEN_DISPLAY_TEXT}" \
    -e "NATIVE_TOKEN_SHORT_TEXT=${NATIVE_TOKEN_SHORT_TEXT}" \
    -e "MNEMONIC_PHRASE=${MAESTRO_MNEMONIC_PHRASE}" \
    -e "WALLET_WITH_MONEY=${MAESTRO_WALLET_WITH_MONEY}" \
    -e "WALLET_WITH_MONEY_ADDR=${MAESTRO_WALLET_WITH_MONEY_ADDR}" \
    -e "auth=${MAESTRO_AUTH}" \
    -e "RECIEVE_WALLET=${MAESTRO_RECIEVE_WALLET}" \
    -e "TESTNET_MNEM=${MAESTRO_TESTNET_MNEM}" \
    -e "TON_v4=${MAESTRO_TON_V4:-}" \
    -p ios \
    --test-output-dir "$out" \
    --debug-output "$dbg" \
    --flatten-debug-output \
    "$p"
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
exit "$retry_exit"
