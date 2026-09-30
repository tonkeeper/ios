#!/bin/sh
# Point the Xcode GUI's DerivedData at this working tree.
#
# Why: GUI builds ignore the `-derivedDataPath` the make targets pass, so Xcode
# resolves its own SwiftPM store into ~/Library/Developer/Xcode/DerivedData/
# Keeper-<hash>. That path is keyed by the workspace location, so every worktree
# earns another ~3.7 GB store of the same dependencies, and the directory outlives
# the worktree it belonged to. A workspace-relative location puts it in
# <worktree>/build/DerivedData-xcode instead: gitignored, thrown away with the
# worktree, and at a predictable path that provision_spm_deps.sh can seed.
#
# Xcode reads the DerivedData location only from per-user workspace settings. The
# same keys in the committed xcshareddata file are ignored — with them set there,
# `xcodebuild -showBuildSettings` keeps reporting the location from the user's
# global Xcode preferences — so this cannot be a committed file and is written per
# user and per working tree from here instead.
#
# Prints the repo-relative SwiftPM store path the GUI will use, or nothing when the
# tree is not on a workspace-relative location; notes go to stderr. A DerivedData
# location a developer already chose is left alone.
set -eu

REPO_ROOT="$(git rev-parse --show-toplevel)/ios"
cd "$REPO_ROOT"

PROJECT_NAME="Keeper"
WANT_STYLE="WorkspaceRelativePath"
WANT_LOCATION="build/DerivedData-xcode"
SETTINGS="$PROJECT_NAME.xcodeproj/project.xcworkspace/xcuserdata/$(id -un).xcuserdatad/WorkspaceSettings.xcsettings"
PB=/usr/libexec/PlistBuddy

# PlistBuddy announces a missing file on stdout, so never read through it.
read_key() {
	[ -f "$SETTINGS" ] || return 0
	$PB -c "Print :$1" "$SETTINGS" 2>/dev/null || true
}
write_key() {
	$PB -c "Add :$1 string $2" "$SETTINGS" >/dev/null 2>&1 ||
		$PB -c "Set :$1 $2" "$SETTINGS" >/dev/null
}

# The store lives under a subdirectory named after the project, without the path
# hash a default location carries.
store_path() { printf '%s/%s/SourcePackages\n' "$1" "$PROJECT_NAME"; }

style="$(read_key DerivedDataLocationStyle)"
location="$(read_key DerivedDataCustomLocation)"

if [ "$style" = "$WANT_STYLE" ] && [ "$location" = "$WANT_LOCATION" ]; then
	store_path "$WANT_LOCATION"
	exit 0
fi

if [ -n "$style" ] && [ "$style" != "Default" ]; then
	echo "note: keeping the DerivedData location already set for this tree ($style ${location:-})" >&2
	if [ "$style" = "WorkspaceRelativePath" ] && [ -n "$location" ]; then
		store_path "$location"
	fi
	exit 0
fi

mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || plutil -create xml1 "$SETTINGS"
write_key DerivedDataLocationStyle "$WANT_STYLE"
write_key DerivedDataCustomLocation "$WANT_LOCATION"

echo "Xcode DerivedData for this tree set to $WANT_LOCATION (reopen the project in Xcode to pick it up)." >&2
store_path "$WANT_LOCATION"
