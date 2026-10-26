#!/usr/bin/env bash
# qa_run.sh + a mitmproxy mock scenario.
# usage: maestro_ui_tests/tools/qa_run_mock.sh <scenario> <udid|booted> <flow.yaml> <case-name> <out-dir> [qa_run.sh options] [maestro -e args...]
# Scenarios live in maestro_ui_tests/mocks/scenarios/<scenario>/ (see mocks/README.md).
#
# How the simulator reaches the proxy — MOCK_MODE (default auto):
#   local   mitmproxy's macOS local-redirect mode, scoped to the app process
#           (`--mode local:Keeper`). Needs "Mitmproxy Redirector.app" installed once
#           (setup.md §4). Nothing else on the Mac is touched. Preferred.
#   system  the macOS system web/https proxy of $QA_NET_SERVICE (default Wi-Fi) is
#           pointed at 127.0.0.1:$MOCK_PORT for the run and restored afterwards.
#           The simulator inherits it; so does every other app on the Mac while
#           the mock is up. networksetup may prompt for an administrator password.
#   auto    local when the Redirector is installed, otherwise system.
# Either way the mitmproxy CA must be trusted by the simulator: tools/install_mitm_ca.sh.
set -u
. "$(dirname "$0")/_lib.sh"
[ $# -ge 5 ] || qa_die "usage: qa_run_mock.sh <scenario> <udid> <flow.yaml> <case> <out> [opts] [-e ...]"
SCENARIO="$1"; DEV="$2"; FLOW="$3"; NAME="$4"; OUT="$5"; shift 5
qa_require_udid "$DEV"
MOCKS="$QA_TESTS_DIR/mocks"
MOCK_ADDON="$QA_IOS_DIR/tools/maestro/mock.py"
[ -f "$MOCK_ADDON" ] || MOCK_ADDON="$QA_IOS_DIR/../shared/tools/maestro/mock.py"
[ -d "$MOCKS/scenarios/$SCENARIO" ] || qa_die "scenario not found: $MOCKS/scenarios/$SCENARIO"
CASE_DIR="$OUT/$NAME"; mkdir -p "$CASE_DIR"
PORT="${MOCK_PORT:-8080}"
SERVICE="${QA_NET_SERVICE:-Wi-Fi}"
MODE="${MOCK_MODE:-auto}"
[ "$MODE" = "auto" ] && { [ -d "/Applications/Mitmproxy Redirector.app" ] && MODE=local || MODE=system; }
command -v mitmdump >/dev/null || qa_die "mitmdump missing: brew install mitmproxy"
[ -f "$QA_STATE_DIR/ca_$UDID" ] || echo "note: mitmproxy CA not recorded for $UDID — if mitm.log shows 'Client TLS handshake failed', run tools/install_mitm_ca.sh $UDID"

pkill -f "mitmdump.*mocks=$MOCKS" >/dev/null 2>&1
PREV_WEB=""; PREV_SEC=""
restore_proxy() {
  [ "$MODE" = "system" ] || return 0
  # Restore exactly what was there; an orphaned system proxy leaves the whole Mac offline.
  if printf '%s' "$PREV_WEB" | grep -q 'Enabled: Yes'; then
    networksetup -setwebproxy "$SERVICE" "$(printf '%s' "$PREV_WEB" | awk '/^Server/{print $2}')" "$(printf '%s' "$PREV_WEB" | awk '/^Port/{print $2}')"
  else
    networksetup -setwebproxystate "$SERVICE" off
  fi
  if printf '%s' "$PREV_SEC" | grep -q 'Enabled: Yes'; then
    networksetup -setsecurewebproxy "$SERVICE" "$(printf '%s' "$PREV_SEC" | awk '/^Server/{print $2}')" "$(printf '%s' "$PREV_SEC" | awk '/^Port/{print $2}')"
  else
    networksetup -setsecurewebproxystate "$SERVICE" off
  fi
}
cleanup() {
  [ -n "${MITM_PID:-}" ] && kill "$MITM_PID" >/dev/null 2>&1
  restore_proxy
}
trap cleanup EXIT INT TERM

case "$MODE" in
  local)
    mitmdump -q --mode "local:$APP_PROCESS" -s "$MOCK_ADDON" --set mocks="$MOCKS" --set scenario="$SCENARIO" >"$CASE_DIR/mitm.log" 2>&1 &
    ;;
  system)
    PREV_WEB="$(networksetup -getwebproxy "$SERVICE")"
    PREV_SEC="$(networksetup -getsecurewebproxy "$SERVICE")"
    mitmdump -q --listen-host 127.0.0.1 --listen-port "$PORT" -s "$MOCK_ADDON" --set mocks="$MOCKS" --set scenario="$SCENARIO" >"$CASE_DIR/mitm.log" 2>&1 &
    ;;
  *) qa_die "MOCK_MODE must be local, system or auto (got '$MODE')";;
esac
MITM_PID=$!
sleep 2
kill -0 "$MITM_PID" 2>/dev/null || { echo "mitmdump failed to start:"; cat "$CASE_DIR/mitm.log"; MITM_PID=""; exit 2; }
echo "mock: scenario=$SCENARIO mode=$MODE $( [ "$MODE" = system ] && echo "proxy=$SERVICE→127.0.0.1:$PORT" )"

if [ "$MODE" = "system" ]; then
  networksetup -setwebproxy "$SERVICE" 127.0.0.1 "$PORT" && networksetup -setsecurewebproxy "$SERVICE" 127.0.0.1 "$PORT" \
    || qa_die "could not set the macOS system proxy on '$SERVICE' (admin rights?) — install the Mitmproxy Redirector for MOCK_MODE=local instead"
  sleep 1
fi

"$QA_TOOLS_DIR/qa_run.sh" "$UDID" "$FLOW" "$NAME" "$OUT" "$@"
RC=$?

kill "$MITM_PID" >/dev/null 2>&1; MITM_PID=""
restore_proxy; MODE=none
echo "--- mock hits ---"; grep -E 'MOCK HIT' "$CASE_DIR/mitm.log" | sort | uniq -c
grep -q 'Client TLS handshake failed' "$CASE_DIR/mitm.log" && echo "TLS handshake failures in mitm.log — CA not trusted by the simulator? tools/install_mitm_ca.sh $UDID"
exit $RC
