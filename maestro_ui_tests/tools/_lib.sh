# shellcheck shell=bash
# Shared helpers for the local Maestro QA runners (tk-qa-verify skill).
# Sourced, never executed. Every runner resolves paths from its own location,
# so the tools work from any cwd and from any worktree.
#
# Simulator apps are ordinary macOS processes: the app binary shows up in `pgrep`,
# `sample` can take its stack, and its crash reports land in the host's
# ~/Library/Logs/DiagnosticReports. There is no adb: the device side is
# `xcrun simctl`, the log side is `log stream` spawned inside the simulator.

QA_TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QA_TESTS_DIR="$(cd "$QA_TOOLS_DIR/.." && pwd)"
QA_IOS_DIR="$(cd "$QA_TESTS_DIR/.." && pwd)"
QA_STATE_DIR="$QA_IOS_DIR/build/maestro-qa/.state"

APP_ID="${APP_ID:-com.jbig.tonkeeper}"
APP_PROCESS="${APP_PROCESS:-Keeper}"
MAESTRO="${MAESTRO_BIN:-$QA_IOS_DIR/scripts/tools/maestro.sh}"
# The iOS driver (an XCUITest runner started through xcodebuild) needs well over
# Maestro's default 15 s on a loaded Mac the first time; later runs reuse it.
export MAESTRO_DRIVER_STARTUP_TIMEOUT="${MAESTRO_DRIVER_STARTUP_TIMEOUT:-120000}"
SECRETS="$QA_TESTS_DIR/secrets/wallets.env"
CRASH_REPORTS_DIR="$HOME/Library/Logs/DiagnosticReports"
MITM_CA_PEM="$HOME/.mitmproxy/mitmproxy-ca-cert.pem"

qa_ok()   { printf 'OK    %s\n' "$1"; }
qa_warn() { printf 'WARN  %s\n' "$1"; }
qa_fail() { printf 'FAIL  %s\n' "$1"; QA_RC=1; }
qa_die()  { echo "error: $*" >&2; exit 2; }

# Resolve a simulator: empty or "booted" → the first booted device; a UDID is
# returned as is; anything else is matched against the device name.
qa_resolve_udid() {
  local want="${1:-}"
  if [ -z "$want" ] || [ "$want" = "booted" ]; then
    xcrun simctl list devices booted 2>/dev/null | grep -oE '[0-9A-F]{8}-[0-9A-F-]{27}' | head -1
  elif printf '%s' "$want" | grep -qE '^[0-9A-Fa-f]{8}-[0-9A-Fa-f-]{27}$'; then
    printf '%s\n' "$want"
  else
    xcrun simctl list devices available 2>/dev/null | grep -F "$want (" | grep -oE '[0-9A-F]{8}-[0-9A-F-]{27}' | head -1
  fi
}

qa_require_udid() {
  UDID="$(qa_resolve_udid "${1:-}")"
  [ -n "$UDID" ] || qa_die "no booted simulator (or no simulator named '${1:-}'). Boot one with the device window app running (DeviceHub.app on Xcode 27, Simulator.app before), then: xcrun simctl boot <udid>"
  xcrun simctl list devices booted | grep -q "$UDID" || qa_die "simulator $UDID is not booted"
}

qa_device_name() {
  xcrun simctl list devices 2>/dev/null | grep -F "$1" | sed -E 's/^ *(.*) \([0-9A-F-]{36}\).*/\1/' | head -1
}

qa_device_runtime() {
  xcrun simctl list devices 2>/dev/null | awk -v u="$1" '/^-- /{rt=$0} index($0,u){gsub(/^-- | --$/,"",rt); print rt; exit}'
}

qa_app_container() { xcrun simctl get_app_container "$UDID" "$APP_ID" "${1:-app}" 2>/dev/null; }

qa_app_version() {
  local app; app="$(qa_app_container app)"
  [ -n "$app" ] || return 1
  printf '%s (%s)\n' \
    "$(plutil -extract CFBundleShortVersionString raw -o - "$app/Info.plist" 2>/dev/null)" \
    "$(plutil -extract CFBundleVersion raw -o - "$app/Info.plist" 2>/dev/null)"
}

# The simulator app process, if alive. simctl installs the bundle as
# <bundle-id>-<timestamp>.app, so match the installed container path exactly; a
# host app with the same executable name is never confused with it.
qa_app_pid() {
  local app; app="$(qa_app_container app)"
  [ -n "$app" ] || return 0
  pgrep -f "^${app}/${APP_PROCESS}( |$)" | head -1
}

# Load secrets/wallets.env and map --wallet <profile> onto the -e variables the
# shared steps expect. Fills the EXTRA array and QA_SEED (for the pasteboard).
# Usage: qa_load_profile "<profile or empty>" "$@"   ($@ = the caller's -e args,
# used to avoid overriding a value given on the command line)
qa_load_profile() {
  local profile="$1"; shift
  EXTRA=(); QA_SEED=""
  if [ -f "$SECRETS" ]; then
    set -a; . "$SECRETS"; set +a
    if [ -n "$profile" ]; then
      local P; P="$(printf '%s' "$profile" | tr '[:lower:]' '[:upper:]')"
      local seed addr
      seed="$(eval printf '%s' "\"\${WALLET_${P}:-}\"")"
      addr="$(eval printf '%s' "\"\${WALLET_${P}_ADDR:-}\"")"
      # The template ships "UQ..." placeholders; passing one on makes every API step 400.
      case "$addr" in *"..."*) echo "warning: WALLET_${P}_ADDR is still the template placeholder — API-backed steps (compare_ton_balance, …) will fail"; addr="";; esac
      [ -n "$seed" ] || qa_die "wallet profile '$profile' not found in $SECRETS (expected WALLET_${P}=...)"
      QA_SEED="$seed"
      EXTRA+=(-e "WALLET_WITH_MONEY=$seed")
      [ -n "$addr" ] && EXTRA+=(-e "WALLET_WITH_MONEY_ADDR=$addr")
      echo "wallet profile: $profile ($(printf '%s' "$seed" | wc -w | tr -d ' ') words)"
    fi
    local v val
    # The v3/v4 import steps read the TON_v4 phrase from the TON_v4 variable, whatever
    # --wallet says; it comes from the WALLET_TON_V4 profile (legacy name: TON_V4).
    for v in PASSWORD_KEY MAESTRO_AUTH RECIEVE_WALLET TESTNET_MNEM TON_V4; do
      val="$(eval printf '%s' "\"\${$v:-}\"")"
      [ "$v" = TON_V4 ] && [ -z "$val" ] && val="${WALLET_TON_V4:-}"
      [ -n "$val" ] || continue
      case "$v" in
        MAESTRO_AUTH) printf '%s\n' "$@" | grep -q '^auth=' || EXTRA+=(-e "auth=$val");;
        TON_V4)       printf '%s\n' "$@" | grep -q '^TON_v4=' || EXTRA+=(-e "TON_v4=$val");;
        *)            printf '%s\n' "$@" | grep -q "^${v}=" || EXTRA+=(-e "$v=$val");;
      esac
    done
  elif [ -n "$profile" ]; then
    qa_die "--wallet given but $SECRETS is missing — copy secrets/wallets.env.example and fill it in"
  fi
  # The CI shard runner always passes these; local flows expect them too.
  if [ -f "$QA_TESTS_DIR/ci/native_token_env.sh" ]; then
    # shellcheck disable=SC1091
    . "$QA_TESTS_DIR/ci/native_token_env.sh"
    printf '%s\n' "$@" | grep -q '^NATIVE_TOKEN_DISPLAY_TEXT=' || EXTRA+=(-e "NATIVE_TOKEN_DISPLAY_TEXT=${NATIVE_TOKEN_DISPLAY_TEXT:-}")
    printf '%s\n' "$@" | grep -q '^NATIVE_TOKEN_SHORT_TEXT=' || EXTRA+=(-e "NATIVE_TOKEN_SHORT_TEXT=${NATIVE_TOKEN_SHORT_TEXT:-}")
  fi
}

# The app's Paste button reads UIPasteboard; Maestro's setClipboard does not reach
# it. Prime the pasteboard with the phrase before an import flow.
#
# With DeviceHub (Xcode 27) the simulator pasteboard mirrors the Mac clipboard and
# `simctl pbcopy` is overridden within a second (verified 2026-09-21), so the phrase
# goes through the HOST clipboard; `simctl pbcopy` is kept for Simulator.app setups.
# The previous host clipboard is saved and put back by qa_restore_pasteboard, which
# the runners call on exit — the seed must not stay on the Mac's clipboard.
qa_prime_pasteboard() {
  [ -n "${1:-}" ] || return 0
  QA_SAVED_CLIPBOARD="$(pbpaste 2>/dev/null || true)"; QA_CLIPBOARD_PRIMED=1
  printf '%s' "$1" | pbcopy
  printf '%s' "$1" | xcrun simctl pbcopy "$UDID" 2>/dev/null
  sleep 1
  local got; got="$(xcrun simctl pbpaste "$UDID" 2>/dev/null | wc -w | tr -d ' ')"
  [ "$got" = "$(printf '%s' "$1" | wc -w | tr -d ' ')" ] || echo "warning: simulator pasteboard holds $got word(s) after priming — Paste in the app will not get the phrase"
}

qa_restore_pasteboard() {
  [ "${QA_CLIPBOARD_PRIMED:-0}" = "1" ] || return 0
  printf '%s' "${QA_SAVED_CLIPBOARD:-}" | pbcopy
  printf '%s' "${QA_SAVED_CLIPBOARD:-}" | xcrun simctl pbcopy "$UDID" 2>/dev/null
  QA_CLIPBOARD_PRIMED=0
}

# recordVideo and screenshots need a display port, and CoreSimulator creates one
# only when the device-window app is running at boot: Simulator.app up to Xcode 26,
# DeviceHub.app from Xcode 27. A simulator booted headless from the CLI answers
# "Device does not have a video capture port" and gets its display only after a
# reboot with the window app open — which restarts the app under test.
qa_device_window_app() {
  local dev; dev="$(xcode-select -p)"
  local c
  for c in "$dev/Applications/Simulator.app" "$dev/../Applications/DeviceHub.app" "$dev/../Applications/Simulator.app"; do
    [ -d "$c" ] && { cd "$c/.." && pwd -P | sed "s|\$|/$(basename "$c")|"; return 0; }
  done
  return 1
}

qa_has_display() { xcrun simctl io "$UDID" screenshot --type png "${TMPDIR:-/tmp}/qa_display_probe.png" >/dev/null 2>&1; }

qa_ensure_display() {
  qa_has_display && return 0
  local app; app="$(qa_device_window_app)" || { echo "no Simulator.app/DeviceHub.app found next to $(xcode-select -p) — cannot attach a display"; return 1; }
  if ! pgrep -xq "$(basename "$app" .app)"; then
    echo "opening $(basename "$app") — the simulator has no display port without it"
    open -a "$app" --args -CurrentDeviceUDID "$UDID"; sleep 6
    qa_has_display && return 0
  fi
  echo "simulator $UDID was booted before $(basename "$app") — rebooting it so a display attaches (the app under test restarts; the Maestro driver restarts too)"
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1; sleep 2
  xcrun simctl boot "$UDID" >/dev/null 2>&1
  xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1; sleep 4
  qa_has_display && return 0
  echo "still no display port on $UDID — open the device in $(basename "$app") by hand, then rerun"
  return 1
}

# Screen recording. simctl prints "Recording started" to stderr once the first
# frame is in; SIGINT finalizes the file. One file per case, no size cap.
qa_start_video() {
  local file="$1" dir; dir="$(dirname "$file")"
  qa_ensure_display || { echo "the case runs WITHOUT video"; QA_REC_PID=""; return 1; }
  xcrun simctl io "$UDID" recordVideo --codec h264 --force "$file" 2>"$dir/.rec.err" &
  QA_REC_PID=$!
  local i=0
  while [ $i -lt 60 ] && ! grep -q 'Recording started' "$dir/.rec.err" 2>/dev/null; do
    kill -0 "$QA_REC_PID" 2>/dev/null || break
    sleep 0.25; i=$((i+1))
  done
  grep -q 'Recording started' "$dir/.rec.err" 2>/dev/null && return 0
  kill "$QA_REC_PID" 2>/dev/null; QA_REC_PID=""
  echo "recordVideo failed to start — the case runs WITHOUT video: $(tr '\n' ' ' <"$dir/.rec.err")"
  return 1
}

qa_stop_video() {
  [ -n "${QA_REC_PID:-}" ] || return 0
  kill -INT "$QA_REC_PID" 2>/dev/null
  local i=0
  while [ $i -lt 40 ] && kill -0 "$QA_REC_PID" 2>/dev/null; do sleep 0.25; i=$((i+1)); done
  kill -0 "$QA_REC_PID" 2>/dev/null && kill "$QA_REC_PID" 2>/dev/null
  QA_REC_PID=""
}

# Live unified log: the app process, plus the SpringBoard/runningboardd lines that
# name it (launches, exits, jetsam). Debug builds log through OSLogBackend;
# analytics events appear as "🌠 Event logged: <name>, args: …". Collected live
# because `log show` over the archive afterwards takes minutes.
# QA_LOG_LEVEL=debug when a case needs the app's debug lines (≈2000 lines/s on this app).
qa_start_applog() {
  xcrun simctl spawn "$UDID" log stream --level "${QA_LOG_LEVEL:-info}" --style compact \
    --predicate "process == \"$APP_PROCESS\" OR ((process == \"SpringBoard\" OR process == \"runningboardd\" OR process == \"launchd\") AND eventMessage CONTAINS \"$APP_PROCESS\")" \
    >"$1" 2>&1 &
  QA_LOG_PID=$!
}

qa_stop_applog() {
  [ -n "${QA_LOG_PID:-}" ] && kill "$QA_LOG_PID" 2>/dev/null
  QA_LOG_PID=""
}

# Marker file for "anything new since the run started" sweeps.
qa_touch_marker() { mkdir -p "$(dirname "$1")"; : >"$1"; }

qa_junit_per_case() {
  [ -f "$1" ] || return 0
  echo "--- per case ---"
  grep -oE '<testcase[^>]*name="[^"]*"[^>]*status="[^"]*"' "$1" |
    sed -E 's/.*name="([^"]*)".*status="([^"]*)".*/\2  \1/' || true
}
