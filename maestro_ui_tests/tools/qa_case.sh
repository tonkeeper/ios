#!/usr/bin/env bash
# Record a screen video + the app log around ANY QA action, Maestro or not
# (a Maestro MCP exploration, a simctl openurl, a manual tap-through).
# usage: qa_case.sh <udid|booted> <case-name> <out-dir> -- <command ...>
set -u
. "$(dirname "$0")/_lib.sh"
[ $# -ge 4 ] || qa_die "usage: qa_case.sh <udid> <case> <out> -- <command...>"
qa_require_udid "$1"; NAME="$2"; OUT="$3"; shift 3
[ "${1:-}" = "--" ] && shift
CASE_DIR="$OUT/$NAME"; mkdir -p "$CASE_DIR"

MARKER="$CASE_DIR/.started"; qa_touch_marker "$MARKER"
qa_start_video "$CASE_DIR/qa_${NAME}_1.mp4"
qa_start_applog "$CASE_DIR/app.log"
START=$(date +%s)
( "$@" ) 2>&1 | tee "$CASE_DIR/console.txt"; RC=${PIPESTATUS[0]}
qa_stop_video
qa_stop_applog
"$QA_TOOLS_DIR/sweep_crashes.sh" --since "$MARKER" "$UDID" "$CASE_DIR" | tee -a "$CASE_DIR/console.txt"
echo "RESULT=$RC DURATION=$(( $(date +%s) - START ))s CASE=$NAME" | tee -a "$CASE_DIR/result.txt"
exit $RC
