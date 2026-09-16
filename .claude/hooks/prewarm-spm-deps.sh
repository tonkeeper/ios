#!/bin/sh
# PostToolUse(EnterWorktree) + SessionStart: pre-warm the app-level SwiftPM store
# of a fresh worktree in the background, so a later build — including one started
# from the Xcode GUI or a bare xcodebuild, which have no `make` prereq to fall
# back on — finds it already resolved.
#
# The `make` targets seed synchronously anyway; this only moves the wait off the
# build. provision_spm_deps.sh installs a store with a single rename and stands down
# if one already exists, so this can never write into a store a build is using.
#
# Fails open (no jq / no target -> do nothing): a convenience warm-up.
set -eu
command -v jq >/dev/null 2>&1 || exit 0

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

is_worktree() { [ -n "$1" ] && [ -d "$1" ] && [ -e "$1/.git" ]; }

# EnterWorktree's payload shape is not contracted, so take any absolute path in it that
# looks like a worktree — from the tool's own fields first, then from anywhere in the
# payload. The session cwd is excluded from that search and used only as the fallback
# (SessionStart, or a session already inside the worktree): entering worktree B from
# worktree A carries both paths, and B, the one that still needs warming, is not the cwd.
cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)"
# Always succeeds: a failing probe as the last command would abort the caller's
# assignment under `set -e` and skip the cwd fallback below.
pick_worktree() {
	for p in $(printf '%s' "$payload" | jq -r "$1" 2>/dev/null | grep '^/.*/worktrees/' | sort -u); do
		[ "$p" != "$cwd" ] || continue
		if is_worktree "$p"; then
			printf '%s' "$p"
			break
		fi
	done
	return 0
}
target="$(pick_worktree '[.tool_response, .tool_input | .. | strings] | .[]')"
[ -n "$target" ] || target="$(pick_worktree '[.. | strings] | .[]')"
if [ -z "$target" ]; then
	target="$cwd"
	is_worktree "$target" || exit 0
fi

# The worktree's branch may predate these scripts, so fall back to the copies next to
# this hook; either is equivalent because both derive every path from their cwd.
MAIN_SCRIPTS="$(cd "$(dirname "$0")/../.." && pwd)/scripts"
script_for() {
	if [ -f "$target/scripts/$1" ]; then echo "$target/scripts/$1"; else echo "$MAIN_SCRIPTS/$1"; fi
}
SEED="$(script_for provision_spm_deps.sh)"
[ -f "$SEED" ] || exit 0
XCODE_DD="$(script_for xcode_derived_data.sh)"

# Keep this tree's GUI DerivedData in-tree and seed the store it resolves into as
# well; the script prints that store's path, or nothing when the location is global
# and not worth seeding.
(
	cd "$target" || exit 0
	nohup sh "$SEED" build/SourcePackages >/dev/null 2>&1 &
	if [ -f "$XCODE_DD" ]; then
		store="$(sh "$XCODE_DD" 2>/dev/null || true)"
		if [ -n "$store" ]; then
			nohup sh "$SEED" "$store" >/dev/null 2>&1 &
		fi
	fi
) >/dev/null 2>&1 &
exit 0
