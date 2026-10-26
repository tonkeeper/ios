#!/usr/bin/env bash
# Read the app's persisted state on the simulator — the iOS counterpart of
# `run-as <pkg> cat shared_prefs/*.xml`. Nothing here needs root; the Keychain is
# the one store that stays opaque (mnemonics, passcode) — assert those through the UI.
#
# usage: read_state.sh <udid|booted>                 # containers + every preferences plist
#        read_state.sh <udid|booted> prefs [grep]     # UserDefaults plists (app + app group), optionally filtered
#        read_state.sh <udid|booted> files            # Documents / Application Support / group container tree
#        read_state.sh <udid|booted> cat <path-in-container>   # pretty-print one plist/json file
set -u
. "$(dirname "$0")/_lib.sh"
qa_require_udid "${1:-}"; shift
DATA="$(qa_app_container data)"; [ -n "$DATA" ] || qa_die "$APP_ID has no data container on $UDID"
GROUP="$(qa_app_container "group.$APP_ID")"
WHAT="${1:-all}"; shift || true

show_prefs() {
  local dir f
  for dir in "$DATA/Library/Preferences" "${GROUP:+$GROUP/Library/Preferences}"; do
    [ -n "$dir" ] && [ -d "$dir" ] || continue
    for f in "$dir"/*.plist; do
      [ -f "$f" ] || continue
      echo "=== $f"
      if [ -n "${1:-}" ]; then plutil -p "$f" | grep -i -- "$1"; else plutil -p "$f"; fi
    done
  done
}

case "$WHAT" in
  all)
    echo "data container:  $DATA"; echo "group container: ${GROUP:-<none>}"; echo
    show_prefs;;
  prefs) show_prefs "${1:-}";;
  files)
    for d in "$DATA/Documents" "$DATA/Library/Application Support" "${GROUP:-}"; do
      [ -n "$d" ] && [ -d "$d" ] || continue
      echo "=== $d"; find "$d" -maxdepth 3 -not -name '.*' | sed "s|$d/||" | sort | head -200
    done;;
  cat)
    F="${1:?path}"; [ -f "$F" ] || F="$DATA/$1"; [ -f "$F" ] || qa_die "not found: $1"
    case "$F" in *.plist) plutil -p "$F";; *) python3 -m json.tool "$F" 2>/dev/null || cat "$F";; esac;;
  *) qa_die "unknown mode '$WHAT' (all | prefs [grep] | files | cat <path>)";;
esac
