#!/usr/bin/env bash
# Force a feature flag through the app's dev-override store, the same store the
# Dev Menu → Feature Flags screen writes ("force true" / "force false" / "default").
# usage: set_flag.sh <udid|booted> <localKey> true|false|default
#        set_flag.sh <udid|booted> --list
# Keys are FeatureFlag.localKey (multichainEnabled, perpsEnabled, swapKitEnabled, …
# see LocalPackages/TKFeatureFlags/Sources/TKFeatureFlags/FeatureFlag.swift).
#
# The override is read at feature-check time by UserDefaultsLocalFeatureFlagsProvider
# (suite featureFlags.tkFeatureFlags.tonkeeper, non-App-Store builds only). Flags
# forced by the bundled FlagsOverride.json win over it — the Dev Menu shows those as
# "Ignored: forced by bundled FlagsOverride.json"; change the JSON and rebuild instead.
# The app is terminated first so cfprefsd does not overwrite the value with a cached one.
set -u
. "$(dirname "$0")/_lib.sh"
SUITE="featureFlags.tkFeatureFlags.tonkeeper"
qa_require_udid "${1:-}"; shift
DATA="$(qa_app_container data)"; [ -n "$DATA" ] || qa_die "$APP_ID has no data container on $UDID (not installed / never launched)"
PLIST="$DATA/Library/Preferences/$SUITE"
if [ "${1:-}" = "--list" ]; then
  [ -f "$PLIST.plist" ] && xcrun simctl spawn "$UDID" defaults read "$PLIST" || echo "(no dev overrides stored)"
  exit 0
fi
[ $# -eq 2 ] || qa_die "usage: set_flag.sh <udid> <localKey> true|false|default"
KEY="$1"; VAL="$2"
xcrun simctl terminate "$UDID" "$APP_ID" >/dev/null 2>&1
case "$VAL" in
  true|false) xcrun simctl spawn "$UDID" defaults write "$PLIST" "$KEY" -bool "$VAL";;
  default|clear) xcrun simctl spawn "$UDID" defaults delete "$PLIST" "$KEY" 2>/dev/null || true;;
  *) qa_die "value must be true, false or default";;
esac
echo "$SUITE now:"; xcrun simctl spawn "$UDID" defaults read "$PLIST" 2>/dev/null || echo "(empty)"
