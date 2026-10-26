#!/usr/bin/env bash
# Bring the app up without spending Maestro commands.
# usage: relaunch.sh [--cold] [--lang <code>] [--url <deeplink>] <udid|booted>
#   --cold  terminate first (clean start; the passcode screen will show)
#   --lang  launch with -AppleLanguages "(<code>)" — per-launch localisation check
#           without changing the simulator language (the app reads it at start)
#   --url   open a deeplink / universal link instead of a plain launch
#           (tonkeeper://…, ton://transfer/…, https://app.tonkeeper.com/…)
# The passcode itself stays in Maestro (steps/unlock_passcode_if_needed.yaml):
# on the simulator four taps are cheap and there is no adb-style input injection.
set -u
. "$(dirname "$0")/_lib.sh"
COLD=0; LANG_CODE=""; URL=""
while [ "${1:-}" != "" ]; do
  case "$1" in
    --cold) COLD=1; shift;;
    --lang) LANG_CODE="$2"; shift 2;;
    --url) URL="$2"; shift 2;;
    *) break;;
  esac
done
qa_require_udid "${1:-}"
[ "$COLD" = "1" ] && xcrun simctl terminate "$UDID" "$APP_ID" >/dev/null 2>&1
if [ -n "$URL" ]; then
  xcrun simctl openurl "$UDID" "$URL"
elif [ -n "$LANG_CODE" ]; then
  xcrun simctl launch "$UDID" "$APP_ID" -AppleLanguages "($LANG_CODE)" -AppleLocale "$LANG_CODE"
else
  xcrun simctl launch "$UDID" "$APP_ID"
fi
