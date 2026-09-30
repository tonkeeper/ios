#!/bin/sh
# Build one or more LocalPackages SwiftPM modules for the iOS Simulator without
# the full `make compile` app build. Intended for fast per-package checks and to
# give sourcekit-lsp / the swift-lsp plugin a resolved build to index against.
#
# Why this is not a plain `swift build`:
#   1. The modules import UIKit and friends, so the build must target the iOS
#      Simulator SDK.
#   2. Per-package Package.resolved files were intentionally removed from the repo
#      so that standalone resolution never becomes the default workflow. We reuse
#      the app-level lockfile read-only and disable automatic resolution, so
#      dependency versions stay pinned and no lockfile is ever rewritten.
#
# Usage: scripts/spm_build.sh <PackageName> [<PackageName> ...]
#   IOS_MIN   override the iOS deployment target used for the triple (default 15.0)

set -eu

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT"

if [ "$#" -eq 0 ]; then
	echo "usage: scripts/spm_build.sh <PackageName> [<PackageName> ...]" >&2
	exit 1
fi

APP_LOCKFILE="$REPO_ROOT/Keeper.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
if [ ! -f "$APP_LOCKFILE" ]; then
	echo "error: app lockfile missing: $APP_LOCKFILE" >&2
	exit 1
fi

IOS_MIN="${IOS_MIN:-15.0}"
TRIPLE="arm64-apple-ios${IOS_MIN}-simulator"
SWIFT_BUILD_QUIET_FLAG=
if [ "${QUIET:-0}" = "1" ]; then
	SWIFT_BUILD_QUIET_FLAG="--quiet"
fi

# Resolve toolchain paths dynamically (no hardcoded absolute paths).
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
TOOLCHAIN_BIN=$(dirname "$(xcrun -f swiftc)")

# Share the global Xcode clang module cache so SDK/system .pcm precompiled by xcodebuild
# (make compile / test_* / GUI) are reused here instead of rebuilt under .build. The cache
# is content-addressed (keyed by full compile context), so cross-tool sharing is safe.
MODULE_CACHE="${MODULE_CACHE:-$HOME/Library/Developer/Xcode/DerivedData/ModuleCache.noindex}"

DEST_DIR="$REPO_ROOT/build/spm"
mkdir -p "$DEST_DIR"
DEST_JSON="$DEST_DIR/ios-sim-destination.json"
cat >"$DEST_JSON" <<EOF
{
  "version": 1,
  "sdk": "$SDK",
  "toolchain-bin-dir": "$TOOLCHAIN_BIN",
  "target": "$TRIPLE",
  "extra-cc-flags": ["-isysroot", "$SDK", "-arch", "arm64"],
  "extra-swiftc-flags": ["-sdk", "$SDK", "-target", "$TRIPLE"],
  "extra-cpp-flags": ["-isysroot", "$SDK"]
}
EOF

build_one() {
	pkg="$1"

	# Resolve the package directory (top-level module or AppModules submodule).
	if [ -f "LocalPackages/$pkg/Package.swift" ]; then
		pkg_dir="LocalPackages/$pkg"
	elif [ -f "LocalPackages/AppModules/$pkg/Package.swift" ]; then
		pkg_dir="LocalPackages/AppModules/$pkg"
	else
		echo "error: package '$pkg' not found under LocalPackages/" >&2
		return 1
	fi

	# In a fresh worktree, clone the main tree's already-resolved dependency store
	# into this package's scratch dir instead of re-cloning and re-extracting it.
	"$REPO_ROOT/scripts/provision_spm_deps.sh" "$pkg_dir/.build"

	# Provide the pinned lockfile inside the package dir for the duration of the
	# build, then remove it. Copy (not symlink) so a rewrite can never corrupt
	# the shared app lockfile. LocalPackages/**/Package.resolved is gitignored.
	lock_copy="$REPO_ROOT/$pkg_dir/Package.resolved"
	cp "$APP_LOCKFILE" "$lock_copy"
	trap 'rm -f "$lock_copy"' EXIT INT TERM

	echo "building $pkg ($pkg_dir) for $TRIPLE ..."

	swift build \
		${SWIFT_BUILD_QUIET_FLAG:+"$SWIFT_BUILD_QUIET_FLAG"} \
		--package-path "$pkg_dir" \
		--destination "$DEST_JSON" \
		--disable-automatic-resolution \
		-Xswiftc -module-cache-path -Xswiftc "$MODULE_CACHE" \
		-Xcc -fmodules-cache-path="$MODULE_CACHE"

	rm -f "$lock_copy"
	trap - EXIT INT TERM
}

for pkg in "$@"; do
	build_one "$pkg"
done
