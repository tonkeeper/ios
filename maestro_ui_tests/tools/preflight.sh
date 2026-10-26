#!/usr/bin/env bash
# Preflight for local Maestro QA runs (tk-qa-verify skill).
# usage: maestro_ui_tests/tools/preflight.sh [udid|device-name|booted]
# Checks the host tools, the simulator, the installed app, the pasteboard and
# proxy leftovers, and prints one OK/WARN/FAIL line per item. Exit code 1 when
# anything required is missing.
set -u
. "$(dirname "$0")/_lib.sh"
QA_RC=0

xcrun simctl help >/dev/null 2>&1 && qa_ok "xcrun simctl ($(xcodebuild -version 2>/dev/null | head -1))" || qa_fail "xcrun simctl unavailable — Xcode / xcode-select"
if "$MAESTRO" --version >/dev/null 2>&1; then qa_ok "maestro $("$MAESTRO" --version 2>/dev/null | head -1)"; else qa_fail "maestro not found: curl -fsSL https://get.maestro.mobile.dev | bash (scripts/tools/maestro.sh resolves ~/.maestro/bin)"; fi
command -v python3 >/dev/null && qa_ok "python3 $(python3 --version 2>&1 | awk '{print $2}')" || qa_fail "python3 missing"
if command -v mitmdump >/dev/null; then qa_ok "mitmdump $(mitmdump --version 2>/dev/null | head -1 | awk '{print $2}') (mocks available)"; else qa_warn "mitmdump missing — mocked scenarios unavailable: brew install mitmproxy"; fi
[ -f "$MITM_CA_PEM" ] && qa_ok "mitmproxy CA generated (~/.mitmproxy)" || qa_warn "no mitmproxy CA yet — run mitmdump once, then tools/install_mitm_ca.sh <udid>"
if [ -d "/Applications/Mitmproxy Redirector.app" ]; then qa_ok "Mitmproxy Redirector installed — app-scoped mocks (MOCK_MODE=local)"; else qa_warn "Mitmproxy Redirector not installed — mocks fall back to the macOS system proxy (MOCK_MODE=system, changes Wi-Fi proxy for the whole Mac while a mock runs); see references/setup.md §4"; fi
if gh auth status >/dev/null 2>&1; then qa_ok "gh authenticated"; else qa_warn "gh not authenticated — PR diff via 'git fetch origin pull/<n>/head' instead of the pr skill"; fi

UDID="$(qa_resolve_udid "${1:-}")"
if [ -z "$UDID" ]; then
  qa_fail "no booted simulator. Open the device window app first (open -a '$(qa_device_window_app 2>/dev/null || echo Simulator)'), then: xcrun simctl boot <udid>   (list: xcrun simctl list devices available | grep iPhone)"
  exit $QA_RC
fi
if ! xcrun simctl list devices booted | grep -q "$UDID"; then qa_fail "simulator $UDID is not booted"; exit $QA_RC; fi
BOOTED=$(xcrun simctl list devices booted | grep -c '(Booted)')
[ "$BOOTED" -gt 1 ] && qa_warn "$BOOTED simulators booted — pass the UDID explicitly to every tool and to maestro --device"
qa_ok "simulator: $(qa_device_name "$UDID") · $(qa_device_runtime "$UDID") · $UDID"

APP_PATH="$(qa_app_container app)"
if [ -n "$APP_PATH" ]; then
  qa_ok "$APP_ID installed: $(qa_app_version) · $APP_PATH"
  BIN_TS=$(stat -f %m "$APP_PATH/$APP_PROCESS" 2>/dev/null || echo 0)
  HEAD_TS=$(git -C "$QA_IOS_DIR" log -1 --format=%ct 2>/dev/null || echo 0)
  if [ "$BIN_TS" -ge "$HEAD_TS" ]; then
    qa_ok "app binary ($(date -r "$BIN_TS" '+%F %T')) is newer than HEAD $(git -C "$QA_IOS_DIR" rev-parse --short HEAD 2>/dev/null) ($(date -r "$HEAD_TS" '+%F %T'))"
  else
    qa_warn "app binary ($(date -r "$BIN_TS" '+%F %T')) is OLDER than HEAD ($(date -r "$HEAD_TS" '+%F %T')) — rebuild + reinstall: make compile; xcrun simctl install $UDID build/DerivedData/Build/Products/KeeperDebug-iphonesimulator/Keeper.app"
  fi
else
  qa_fail "$APP_ID not installed on $UDID — make -C ios compile && xcrun simctl install $UDID ios/build/DerivedData/Build/Products/KeeperDebug-iphonesimulator/Keeper.app"
fi

LANGS=$(xcrun simctl spawn "$UDID" defaults read .GlobalPreferences AppleLanguages 2>/dev/null | tr -d ' \n"' | sed 's/^(//;s/)$//')
case "$LANGS" in
  en*|"") qa_ok "simulator language English (${LANGS:-default})";;
  *) qa_warn "simulator language is '$LANGS' — flows assert English copy; relaunch with tools/relaunch.sh --lang en, or set the device language";;
esac

SYNC=$(defaults read com.apple.iphonesimulator PasteboardAutomaticSync 2>/dev/null || echo 1)
[ "$SYNC" = "0" ] && qa_ok "Simulator PasteboardAutomaticSync off" || qa_warn "Simulator pasteboard syncs with the Mac clipboard — a host copy between pbcopy and the Paste tap empties the import; defaults write com.apple.iphonesimulator PasteboardAutomaticSync -bool false; restart Simulator.app"

SERVICE="${QA_NET_SERVICE:-Wi-Fi}"
PROXY=$(networksetup -getwebproxy "$SERVICE" 2>/dev/null)
if printf '%s' "$PROXY" | grep -q 'Enabled: Yes'; then
  qa_warn "macOS web proxy on '$SERVICE' is ENABLED ($(printf '%s' "$PROXY" | awk '/Server|Port/{printf "%s ", $2}')) — leftover from a mock run? tools/qa_run_mock.sh restores it; by hand: networksetup -setwebproxystate '$SERVICE' off; networksetup -setsecurewebproxystate '$SERVICE' off"
else
  qa_ok "no macOS system proxy enabled on '$SERVICE'"
fi

if qa_has_display; then qa_ok "simulator has a display port (recordVideo / screenshot work)"; else qa_warn "simulator has NO display port — it was booted before $(basename "$(qa_device_window_app 2>/dev/null || echo 'Simulator.app')") was running; recordVideo and screenshots fail. The runner reboots it with the window app open (the app under test restarts), or do it now: open -a '$(qa_device_window_app 2>/dev/null)' && xcrun simctl shutdown $UDID && xcrun simctl boot $UDID"; fi

STALE=$(pgrep -fl 'mitmdump|simctl io .* recordVideo|log stream --level debug' 2>/dev/null | wc -l | tr -d ' ')
[ "$STALE" = "0" ] && qa_ok "no stale mitmdump / recordVideo / log stream processes" || qa_warn "$STALE stale process(es): $(pgrep -fl 'mitmdump|recordVideo|log stream --level debug' | cut -c1-90 | tr '\n' ';') — leftovers of a killed run"
DRIVER=$(pgrep -f 'xcodebuild test-without-building' | head -1)
[ -n "$DRIVER" ] && qa_ok "Maestro iOS driver already running (pid $DRIVER) — next run skips the startup" || qa_ok "no Maestro iOS driver yet — the first run starts it (MAESTRO_DRIVER_STARTUP_TIMEOUT=${MAESTRO_DRIVER_STARTUP_TIMEOUT} ms)"
pgrep -fq 'Maestro Studio.app' && qa_warn "Maestro Studio is running — it can hold the iOS driver port ('Failed to connect to /127.0.0.1:<port>', 'isScreenStatic … 500'); quit it before a run"

if [ -s "$HOME/.maestro/sessions" ]; then qa_warn "~/.maestro/sessions is not empty — a killed run left a session entry; if maestro fails at 'Getting device info': : > ~/.maestro/sessions"; else qa_ok "~/.maestro/sessions clean"; fi

[ -f "$SECRETS" ] && qa_ok "secrets/wallets.env present ($(grep -cE '^WALLET_[A-Z0-9_]+=' "$SECRETS") wallet vars)" || qa_warn "secrets/wallets.env missing — import-based cases need it: cp secrets/wallets.env.example secrets/wallets.env"
[ -f "$QA_STATE_DIR/ca_$UDID" ] && qa_ok "mitmproxy CA installed on this simulator ($(cat "$QA_STATE_DIR/ca_$UDID"))" || qa_warn "mitmproxy CA not recorded for $UDID — mocked runs need tools/install_mitm_ca.sh $UDID (idempotent)"

exit $QA_RC
