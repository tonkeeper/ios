#!/bin/sh
# PreToolUse(Edit|Write): block hand-edits to generated / lockfile paths.
# Exit 2 => block the tool and feed the message back to the model.
# Mirrors AGENTS.md "never hand-edit" rules + .swiftformat generated excludes.
# Fails open (no jq -> allow): a convenience guard, not a security boundary.
command -v jq >/dev/null 2>&1 || exit 0
f="$(jq -r '.tool_input.file_path // empty')"
[ -n "$f" ] || exit 0

block() { printf '%s\n' "$1" >&2; exit 2; }

case "$f" in
  */TKLocalize/Sources/TKLocalize/TKLocales.swift)
    block "Blocked: TKLocales.swift is generated. Edit en.lproj/Localizable.strings, then regenerate: make locale" ;;
  */TKCore/Sources/TKCore/Analytics/Events/Generated/*|*/TKCore/Sources/TKCore/Analytics/Events/Deprecated/*)
    block "Blocked: analytics events are generated. Edit scripts/analytics/event_model_whitelist.txt, then: make analytics" ;;
  */TKUIKit/TKUIKit/Sources/TKUIKit/Generated/*)
    block "Blocked: TKUIKit resources are generated. Regenerate: make resources" ;;
  */KeeperCore/Packages/TonConnectAPI/Sources/*)
    block "Blocked: generated API. Regenerate: make tonconnect_generate" ;;
  */KeeperCore/Packages/TKTonkeeperAPI/Sources/*)
    block "Blocked: generated API. Regenerate: make tonkeeper_generate" ;;
  */KeeperCore/Packages/TKTradingAPI/Sources/*)
    block "Blocked: generated API. Regenerate: make trading_generate" ;;
  */KeeperCore/Packages/MultichainAPI/Sources/*)
    block "Blocked: generated API. Regenerate: make multichain_generate" ;;
  */KeeperCore/Packages/SwapAPI/Sources/*)
    block "Blocked: generated API. Regenerate: make swap_generate" ;;
  *Package.resolved)
    block "Blocked: Package.resolved is managed by SwiftPM resolution; do not hand-edit." ;;
esac
exit 0
