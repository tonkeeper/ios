#!/bin/sh
# PostToolUse(Edit|Write): format edited .swift files with the repo config so the
# commit-msg git hook (which rejects commits swiftformat would reformat) passes
# first try. Generated .swift paths can't reach here — guard-generated.sh blocks
# their edits in PreToolUse — so no exclude handling is needed. Fails open.
set -e
command -v jq >/dev/null 2>&1 || exit 0

f="$(jq -r '.tool_input.file_path // empty')"
case "$f" in
  *.swift) ;;
  *) exit 0 ;;
esac
[ -f "$f" ] || exit 0

# Report a missing toolchain here rather than leaving edits silently unformatted until
# the commit-msg hook rejects the commit for the same reason.
"$CLAUDE_PROJECT_DIR/scripts/tools/tool.sh" swiftformat --version >/dev/null || exit 0

"$CLAUDE_PROJECT_DIR/scripts/tools/tool.sh" swiftformat \
  --quiet --config "$CLAUDE_PROJECT_DIR/.swiftformat" "$f" || true
exit 0
