#!/usr/bin/env bash
# QA runner: screen-records the simulator while a Maestro flow runs, collects the
# JUnit report, Maestro debug output (screenshots on failure, logs), the app's
# unified log, and sweeps crash reports that appeared during the run.
#
# usage: maestro_ui_tests/tools/qa_run.sh [--wallet <profile>] [--no-video] [--cold] <udid|booted> <flow.yaml> <case-name> <out-dir> [maestro -e args...]
#
# --wallet   seed profile from secrets/wallets.env (ton_only · multichain · ton_v4),
#            mapped onto WALLET_WITH_MONEY / WALLET_WITH_MONEY_ADDR and primed into
#            the simulator pasteboard for the import steps
# --no-video skip the recording while iterating; the run that goes into the report
#            is always recorded
# --cold     terminate the app first so the case starts from a cold launch
#
# For several cases prefer tools/qa_suite.sh, which pays Maestro's startup once.
# <out-dir> is usually build/maestro-qa/<date>/<ticket>.
set -u
. "$(dirname "$0")/_lib.sh"

PROFILE=""; VIDEO=1; COLD=0
while [ "${1:-}" != "" ]; do
  case "$1" in
    --wallet) PROFILE="$2"; shift 2;;
    --no-video) VIDEO=0; shift;;
    --cold) COLD=1; shift;;
    *) break;;
  esac
done
[ $# -ge 4 ] || qa_die "usage: qa_run.sh [--wallet p] [--no-video] [--cold] <udid> <flow.yaml> <case> <out> [-e ...]"
qa_require_udid "$1"; FLOW="$2"; NAME="$3"; OUT="$4"; shift 4
[ -f "$FLOW" ] || qa_die "flow not found: $FLOW"
CASE_DIR="$OUT/$NAME"; mkdir -p "$CASE_DIR"

qa_load_profile "$PROFILE" "$@"
qa_prime_pasteboard "$QA_SEED"
trap 'qa_restore_pasteboard' EXIT INT TERM

[ "$COLD" = "1" ] && xcrun simctl terminate "$UDID" "$APP_ID" >/dev/null 2>&1

MARKER="$CASE_DIR/.started"; qa_touch_marker "$MARKER"
{
  echo "device: $(qa_device_name "$UDID") · $(qa_device_runtime "$UDID") · $UDID"
  echo "app: $APP_ID $(qa_app_version 2>/dev/null || echo 'not installed')"
  echo "flow: $FLOW"; echo "cold: $COLD"; echo "wallet: ${PROFILE:-<device wallet>}"
  echo "head: $(git -C "$QA_IOS_DIR" rev-parse --short HEAD 2>/dev/null)"
} >"$CASE_DIR/env.txt"

[ "$VIDEO" = "1" ] && qa_start_video "$CASE_DIR/qa_${NAME}_1.mp4"
qa_start_applog "$CASE_DIR/app.log"

START=$(date +%s)
"$MAESTRO" --device "$UDID" test "$FLOW" "${EXTRA[@]}" "$@" \
  --format junit --output "$CASE_DIR/junit.xml" \
  --test-output-dir "$CASE_DIR/maestro" \
  --debug-output "$CASE_DIR/maestro-debug" 2>&1 | tee "$CASE_DIR/console.txt"
RC=${PIPESTATUS[0]}
END=$(date +%s)

qa_stop_video
qa_stop_applog
"$QA_TOOLS_DIR/sweep_crashes.sh" --since "$MARKER" "$UDID" "$CASE_DIR" | tee -a "$CASE_DIR/console.txt"

echo "RESULT=$RC DURATION=$((END-START))s CASE=$NAME" | tee "$CASE_DIR/result.txt"
exit $RC
