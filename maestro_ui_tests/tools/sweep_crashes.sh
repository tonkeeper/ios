#!/usr/bin/env bash
# Crash / hang sweep for the simulator app (the iOS counterpart of Android's
# `dumpsys dropbox`). Run after every case batch and again at the end of a session.
#
# usage: sweep_crashes.sh [--since <marker-file>] [--sample] [--log-show] <udid|booted> <out-dir>
#
# What it collects into <out-dir>/crashes/:
#   *.ips / *.crash  — crash reports of the app process from
#                      ~/Library/Logs/DiagnosticReports (simulator apps crash into
#                      the HOST's report folder), newer than the marker
#   springboard.log  — SpringBoard / runningboardd / launchd lines naming the app:
#                      launches, exits, jetsam, watchdog-style terminations
#   errors.log       — the app's own error/fault-level unified-log lines
#   sample_<ts>.txt  — with --sample (the app is alive but nothing moves): `sample`
#                      of the live process, 5 s; the main thread's frames decide
#                      app-hang vs host starvation
#
# The two log files are cut from <out-dir>/app.log, the live stream the runners
# collect (compact style: "<ts> <type> <process>[pid] …", type E = error, F = fault).
# Without an app.log, --log-show falls back to `log show` over the simulator's
# archive — correct, but it takes minutes on a busy log store.
#
# Note: the simulator has NO watchdog — a frozen main thread is never killed and
# never produces a report. A hang shows up only as Maestro timeouts + a frozen
# recording; that is what --sample is for.
set -u
. "$(dirname "$0")/_lib.sh"

SINCE=""; SAMPLE=0; LOGSHOW=0
while [ "${1:-}" != "" ]; do
  case "$1" in
    --since) SINCE="$2"; shift 2;;
    --sample) SAMPLE=1; shift;;
    --log-show) LOGSHOW=1; shift;;
    *) break;;
  esac
done
[ $# -ge 2 ] || qa_die "usage: sweep_crashes.sh [--since marker] [--sample] [--log-show] <udid> <out>"
qa_require_udid "$1"; OUT="$2"
DIR="$OUT/crashes"; mkdir -p "$DIR"

if [ -n "$SINCE" ] && [ -f "$SINCE" ]; then
  NEWER=(-newer "$SINCE")
  START_TS="$(date -r "$(stat -f %m "$SINCE")" '+%Y-%m-%d %H:%M:%S')"
else
  NEWER=(-mmin -180)
  START_TS="$(date -v-3H '+%Y-%m-%d %H:%M:%S')"
fi

echo "--- crash/hang sweep ($APP_PROCESS on $UDID, since $START_TS) ---"
N=0
if [ -d "$CRASH_REPORTS_DIR" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    cp "$f" "$DIR/" && N=$((N+1))
    echo "CRASH REPORT: $(basename "$f")"
    # .ips = JSON header line + JSON body; pull the fields a human reads first.
    grep -oE '"(exception|termination)"[^}]*}' "$f" 2>/dev/null | head -3 | cut -c1-240
    grep -oE '"(bug_type|procName|bundleID|captureTime)"\s*:\s*"[^"]*"' "$f" 2>/dev/null | head -4 | tr '\n' ' '; echo
  done < <(find "$CRASH_REPORTS_DIR" -maxdepth 1 \( -name "${APP_PROCESS}-*.ips" -o -name "${APP_PROCESS}_*.ips" -o -name "${APP_PROCESS}-*.crash" -o -name "${APP_PROCESS}_*.crash" \) "${NEWER[@]}" 2>/dev/null | sort)
fi
echo "crash reports since marker: $N"

if [ -f "$OUT/app.log" ]; then
  # lifecycle lines only — SpringBoard also logs a launch-services record per icon
  grep -E "(SpringBoard|runningboardd|launchd)\[" "$OUT/app.log" | grep -iE 'launch|exit|terminat|crash|jetsam|watchdog|kill|died|assert' >"$DIR/springboard.log" || true
  # the app's own error/fault lines; Apple-framework subsystems inside the process (com.apple.network …) are counted, not listed
  grep -E "^[0-9-]+ [0-9:.]+[-+0-9]* +(E|F) " "$OUT/app.log" | grep -v '\] \[com\.apple\.' >"$DIR/errors.log" || true
  APPLE_ERR=$(grep -E "^[0-9-]+ [0-9:.]+[-+0-9]* +(E|F) " "$OUT/app.log" | grep -c '\] \[com\.apple\.' || true)
  SRC="app.log"
elif [ "$LOGSHOW" = "1" ]; then
  echo "no app.log — reading the simulator log archive (this can take minutes)…"
  xcrun simctl spawn "$UDID" log show --start "$START_TS" --style compact \
    --predicate "(process == \"SpringBoard\" OR process == \"runningboardd\" OR process == \"launchd\") AND eventMessage CONTAINS \"$APP_PROCESS\"" \
    >"$DIR/springboard.log" 2>/dev/null
  xcrun simctl spawn "$UDID" log show --start "$START_TS" --style compact \
    --predicate "process == \"$APP_PROCESS\" AND messageType IN {16, 17}" \
    >"$DIR/errors.log" 2>/dev/null
  SRC="log show"
else
  : >"$DIR/springboard.log"; : >"$DIR/errors.log"; SRC="none (no app.log; pass --log-show to read the archive)"
fi
EXITS=$(grep -ciE 'exit|terminat|crash|jetsam|watchdog|killed' "$DIR/springboard.log" 2>/dev/null || true); EXITS=${EXITS:-0}
echo "springboard/runningboard lines naming the app: $(wc -l <"$DIR/springboard.log" | tr -d ' ') (exit/terminate/crash-like: $EXITS) → crashes/springboard.log [source: $SRC]"
echo "app error/fault log lines: $(wc -l <"$DIR/errors.log" | tr -d ' ') → crashes/errors.log${APPLE_ERR:+ (plus $APPLE_ERR from Apple frameworks inside the process, kept in app.log)}"

PID="$(qa_app_pid)"
if [ -n "$PID" ]; then
  echo "app process alive: pid $PID"
  if [ "$SAMPLE" = "1" ]; then
    TS=$(date +%H%M%S)
    if sample "$PID" 5 -mayDie -file "$DIR/sample_$TS.txt" >/dev/null 2>&1; then
      echo "sample → crashes/sample_$TS.txt; main thread, dominant path (deepest frames last):"
      # Block = "NNNN Thread_x: Main Thread …" up to the next thread. Keep the frames
      # that carry ≥ half of the thread's samples — the hot path — and show its tail,
      # which is where the main thread actually sits (a runloop mach_msg idle vs. app code).
      awk '/Thread_[0-9]+.*(Main Thread|com\.apple\.main-thread)/{f=1; total=$1; next} f&&/Thread_[0-9]+/{exit} f{n=$0; gsub(/^[ +!:|]+/,"",n); split(n,a," "); if (a[1]+0 >= total/2) print "    " n}' "$DIR/sample_$TS.txt" | tail -12 | cut -c1-160
    else
      echo "sample failed (process gone mid-sample?)"
    fi
  fi
else
  echo "app process NOT running"
fi
echo "host load: $(uptime | sed 's/.*load averages*: //')"
