#!/usr/bin/env bash
# Batch QA runner: several cases in ONE `maestro test` invocation, one recording,
# one junit.xml with a row per case.
#
# Why: starting the Maestro CLI (JVM + iOS driver handshake) costs a fixed ~15 s no
# matter how short the flow is. Running ten cases one by one burns minutes before
# a single assert executes; this pays that once.
#
# usage: qa_suite.sh [--wallet <profile>] [--no-video] [--cold] <udid|booted> <suite-name> <out-dir> <flow.yaml>... [-- maestro -e args...]
#
# Each flow keeps its own screenshot namespace: pass -e OUT=<out>/<suite> and have
# every flow write to "${OUT}/<case>_NN_name". Flows run in the order given.
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
[ $# -ge 4 ] || qa_die "usage: qa_suite.sh [--wallet p] [--no-video] [--cold] <udid> <suite> <out> <flow>... [-- -e ...]"
qa_require_udid "$1"; NAME="$2"; OUT="$3"; shift 3

FLOWS=()
while [ "${1:-}" != "" ] && [ "$1" != "--" ]; do FLOWS+=("$1"); shift; done
[ "${1:-}" = "--" ] && shift
[ ${#FLOWS[@]} -gt 0 ] || qa_die "no flows given"

CASE_DIR="$OUT/$NAME"; mkdir -p "$CASE_DIR"
qa_load_profile "$PROFILE" "$@"
qa_prime_pasteboard "$QA_SEED"

# Maestro takes ONE path, so the flows are staged as an ordered directory of
# symlinks. The staging dir MUST sit at flows/<a>/<b>/ depth: a flow resolves its
# `runFlow: ../../../steps/...` against the path it was opened through, and every
# shard flow (flows/multichain/<section>/) and local flow (flows/local/<area>/)
# lives at that depth.
SUITE_DIR="$QA_TESTS_DIR/flows/.suite/$NAME"
rm -rf "$SUITE_DIR"; mkdir -p "$SUITE_DIR"
trap 'rm -rf "$SUITE_DIR"; qa_restore_pasteboard' EXIT INT TERM
i=0
ORDER=()
for f in "${FLOWS[@]}"; do
  i=$((i+1))
  [ -f "$f" ] || qa_die "flow not found: $f"
  NAME_I="$(printf '%02d' $i)_$(basename "$f" .yaml)"
  ln -s "$(cd "$(dirname "$f")" && pwd)/$(basename "$f")" "$SUITE_DIR/$NAME_I.yaml"
  ORDER+=("$NAME_I")
done
# Maestro does not run a directory's flows in filename order; the staging dir gets a
# workspace config that pins the order given on the command line and keeps going after a
# failure, so one red case does not skip the rest of the suite.
{
  echo "flows:"; echo "  - \"*.yaml\""
  echo "executionOrder:"; echo "  continueOnFailure: true"; echo "  flowsOrder:"
  for n in "${ORDER[@]}"; do echo "    - $n"; done
} >"$SUITE_DIR/config.yaml"

[ "$COLD" = "1" ] && xcrun simctl terminate "$UDID" "$APP_ID" >/dev/null 2>&1

MARKER="$CASE_DIR/.started"; qa_touch_marker "$MARKER"
{
  echo "device: $(qa_device_name "$UDID") · $(qa_device_runtime "$UDID") · $UDID"
  echo "app: $APP_ID $(qa_app_version 2>/dev/null || echo 'not installed')"
  printf 'flows:\n'; printf '  %s\n' "${FLOWS[@]}"
  echo "cold: $COLD"; echo "wallet: ${PROFILE:-<device wallet>}"
  echo "head: $(git -C "$QA_IOS_DIR" rev-parse --short HEAD 2>/dev/null)"
} >"$CASE_DIR/env.txt"

[ "$VIDEO" = "1" ] && qa_start_video "$CASE_DIR/qa_${NAME}_1.mp4"
qa_start_applog "$CASE_DIR/app.log"

START=$(date +%s)
"$MAESTRO" --device "$UDID" test "$SUITE_DIR" "${EXTRA[@]}" "$@" \
  --format junit --output "$CASE_DIR/junit.xml" \
  --test-output-dir "$CASE_DIR/maestro" \
  --debug-output "$CASE_DIR/maestro-debug" 2>&1 | tee "$CASE_DIR/console.txt"
RC=${PIPESTATUS[0]}
END=$(date +%s)

qa_stop_video
qa_stop_applog
"$QA_TOOLS_DIR/sweep_crashes.sh" --since "$MARKER" "$UDID" "$CASE_DIR" | tee -a "$CASE_DIR/console.txt"

qa_junit_per_case "$CASE_DIR/junit.xml"
echo "RESULT=$RC DURATION=$((END-START))s CASES=${#FLOWS[@]} SUITE=$NAME" | tee "$CASE_DIR/result.txt"
exit $RC
