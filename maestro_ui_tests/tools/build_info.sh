#!/usr/bin/env bash
# Is the fix under test actually in the installed app? Prints what a report's
# Environment section needs and, with --marker, greps the binary for a string the
# PR added (a new localisation key, a new accessibilityIdentifier, an analytics
# event name) — the only proof that works for a build that came from CI.
# usage: build_info.sh [--marker <string>]... <udid|booted>
set -u
. "$(dirname "$0")/_lib.sh"
MARKERS=()
while [ "${1:-}" = "--marker" ]; do MARKERS+=("$2"); shift 2; done
qa_require_udid "${1:-}"
APP="$(qa_app_container app)"; [ -n "$APP" ] || qa_die "$APP_ID not installed on $UDID"
BIN="$APP/$APP_PROCESS"
echo "simulator: $(qa_device_name "$UDID") · $(qa_device_runtime "$UDID") · $UDID"
echo "app:       $APP_ID $(qa_app_version)"
echo "bundle:    $APP"
echo "binary:    $(date -r "$(stat -f %m "$BIN")" '+%F %T') ($(du -h "$BIN" | cut -f1))"
echo "HEAD:      $(git -C "$QA_IOS_DIR" rev-parse --short HEAD) $(git -C "$QA_IOS_DIR" log -1 --format='%cI %s' | cut -c1-90)"
echo "branch:    $(git -C "$QA_IOS_DIR" rev-parse --abbrev-ref HEAD)"
DIRTY=$(git -C "$QA_IOS_DIR" status --porcelain -- . 2>/dev/null | grep -v 'Resources/FlagsOverride.json' | wc -l | tr -d ' ')
[ "$DIRTY" = "0" ] || echo "note:      $DIRTY uncommitted change(s) under ios/ — the build may contain them"
LOCAL_APP="$QA_IOS_DIR/build/DerivedData/Build/Products/KeeperDebug-iphonesimulator/$APP_PROCESS.app/$APP_PROCESS"
if [ -f "$LOCAL_APP" ]; then
  if cmp -s "$LOCAL_APP" "$BIN"; then echo "source:    identical to the local make-compile product"; else echo "source:    differs from the local make-compile product ($(date -r "$(stat -f %m "$LOCAL_APP")" '+%F %T')) — installed from elsewhere, or not reinstalled"; fi
fi
# The app binary is a thin launcher; the code lives in Frameworks/*.framework
# (SwiftPM dynamic products), so a marker is searched across all of them.
BINARIES=("$BIN"); for fw in "$APP"/Frameworks/*.framework; do [ -d "$fw" ] && BINARIES+=("$fw/$(basename "$fw" .framework)"); done
echo "code:      ${#BINARIES[@]} binaries (app + $(( ${#BINARIES[@]} - 1 )) frameworks)"
for m in "${MARKERS[@]:-}"; do
  [ -n "$m" ] || continue
  HIT=""
  for b in "${BINARIES[@]}"; do [ -f "$b" ] && strings -n 4 "$b" 2>/dev/null | grep -qF -- "$m" && { HIT="$(basename "$b")"; break; }; done
  if [ -n "$HIT" ]; then echo "marker:    '$m' FOUND in $HIT"; else echo "marker:    '$m' NOT found in the app or its frameworks (localised strings live in *.lproj, not in binaries — try an identifier, an event name or a symbol)"; fi
done
