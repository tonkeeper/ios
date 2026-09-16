#!/usr/bin/env bash
# Copy a recovery phrase into the booted simulator pasteboard (UIPasteboard).
# Maestro setClipboard does NOT populate iOS Paste — the app's Paste button reads
# UIPasteboard, so CI must use simctl pbcopy.
#
# Phrase source (first non-empty):
#   1. PHRASE
#   2. WALLET_WITH_MONEY
set -euo pipefail

PHRASE="${PHRASE:-${WALLET_WITH_MONEY:-}}"

if [[ -z "$PHRASE" ]]; then
  echo "simulator_pbcopy_phrase: PHRASE/WALLET_WITH_MONEY is unset; skipping." >&2
  exit 0
fi

if ! xcrun simctl list devices booted 2>/dev/null | grep -q '(Booted)'; then
  echo "simulator_pbcopy_phrase: no booted simulator; skipping." >&2
  exit 0
fi

printf '%s' "$PHRASE" | xcrun simctl pbcopy booted
sleep 2
