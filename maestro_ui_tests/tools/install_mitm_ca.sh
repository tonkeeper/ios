#!/usr/bin/env bash
# Trust the mitmproxy CA inside one simulator (once per simulator, idempotent).
# usage: install_mitm_ca.sh <udid|booted>
# Generates the CA first if ~/.mitmproxy is empty (by starting mitmdump for a moment).
# Records the install under build/maestro-qa/.state so preflight can tell.
set -u
. "$(dirname "$0")/_lib.sh"
qa_require_udid "${1:-}"
command -v mitmdump >/dev/null || qa_die "mitmdump missing: brew install mitmproxy"
if [ ! -f "$MITM_CA_PEM" ]; then
  echo "generating the mitmproxy CA…"
  mitmdump -q --listen-port 18080 >/dev/null 2>&1 & P=$!; sleep 3; kill $P 2>/dev/null
  [ -f "$MITM_CA_PEM" ] || qa_die "CA still missing after running mitmdump: $MITM_CA_PEM"
fi
xcrun simctl keychain "$UDID" add-root-cert "$MITM_CA_PEM" || qa_die "simctl keychain add-root-cert failed"
mkdir -p "$QA_STATE_DIR"
date '+%F %T' >"$QA_STATE_DIR/ca_$UDID"
echo "mitmproxy CA trusted on $(qa_device_name "$UDID") ($UDID)"
