#!/bin/sh
# Seed a SwiftPM dependency store (checkouts + repositories + artifacts +
# workspace-state.json) from an already-resolved store on this machine.
#
# Why this exists: dependency stores are per-worktree and per-package, so a fresh
# `git worktree` (or a package that has never been built) starts empty. Nothing is
# downloaded again — the global SwiftPM cache already holds every repository and
# artifact zip — but SwiftPM still copies every repository out of that cache, checks
# it out, and re-extracts every binary xcframework, which dominates the first build
# of a worktree and costs its full size in real disk. Cloning an existing store with
# clonefile(2) skips all of it and costs no extra physical disk on APFS: unchanged
# files stay shared blocks.
#
# Stores stay per-worktree, so builds in different worktrees never contend and a
# diverging Package.resolved just re-checks-out the pins that differ, from the
# global cache.
#
# Source is the first already-resolved store of: this tree's app-level store,
# the main working tree's store at the same relative path, the main working
# tree's app-level store. The app-level store is a valid source for any package
# store because scripts/spm_build.sh builds every package against the app
# lockfile, so the pins are identical and the app graph is a superset.
#
# Usage: scripts/provision_spm_deps.sh <store-dir-relative-to-ios/>
#   e.g. build/SourcePackages          (xcodebuild -clonedSourcePackagesDirPath)
#        LocalPackages/App/.build      (swift build scratch dir)
set -eu

# An empty path must not fall through: it would resolve to the project root and stage a
# full clone of the store beside the working tree.
[ "$#" -eq 1 ] && [ -n "$1" ] || { echo "usage: scripts/provision_spm_deps.sh <store-dir-relative-to-ios/>" >&2; exit 1; }
APP_STORE_REL="build/SourcePackages"
MARKER="workspace-state.json"

# The iOS project lives in ios/ of the repository; roots here are project roots. Both are
# derived from the cwd (not $0) so a main-tree stand-in copy of this script, run by the
# checkout hooks, still operates on the tree it was started in.
REPO_ROOT="$(git rev-parse --show-toplevel)/ios"
# --git-common-dir points at the shared `.git`; its parent is the main working tree.
COMMON_GIT_DIR="$(cd "$(git rev-parse --git-common-dir)" && pwd)"
MAIN_ROOT="$(dirname "$COMMON_GIT_DIR")/ios"

# Callers pass the path they have — the make targets hand over ./build/SourcePackages
# through BUILD_DIR — while workspace-state.json records normalized paths. A `./` left
# in the destination makes every prefix rewrite and existence check below miss, so
# normalize once here and derive the display path from the result.
norm() { printf '%s' "$1" | sed -e 's|/\./|/|g' -e 's|//*|/|g' -e 's|/$||'; }
case "$1" in
	/*) DEST="$(norm "$1")" ;;
	*) DEST="$(norm "$REPO_ROOT/$1")" ;;
esac
REL="${DEST#"$REPO_ROOT"/}"
# Hot path: already seeded (or resolved in place) — nothing to do.
[ ! -f "$DEST/$MARKER" ] || exit 0

SRC=""
for candidate in "$REPO_ROOT/$APP_STORE_REL" "$MAIN_ROOT/$REL" "$MAIN_ROOT/$APP_STORE_REL"; do
	[ "$candidate" != "$DEST" ] || continue
	[ -f "$candidate/$MARKER" ] || continue
	SRC="$candidate"
	break
done
# Nothing resolved to copy from: leave it to the normal SwiftPM resolve.
[ -n "$SRC" ] || exit 0

# The store is built beside its final path and moved into place with one rename, so
# nothing is ever written into a store another process may be using. SwiftPM and
# xcodebuild hold no lock this script could take — and to them a partially populated
# store is simply one they must finish resolving — so an in-place seed could delete
# checkouts underneath a running resolve. Concurrent seeders each fill their own
# staging dir; the first rename wins and the rest stand down.
STAGING="$DEST.seeding.$$"
cleanup() { rm -rf "$STAGING"; }
# The signal traps must exit: a trap that only cleans up replaces the default
# terminate action, and the copy would carry on unsupervised after Ctrl+C.
trap cleanup EXIT
trap 'cleanup; trap - INT; kill -INT $$' INT
trap 'cleanup; trap - TERM; kill -TERM $$' TERM

rm -rf "$STAGING"
mkdir -p "$(dirname "$STAGING")"

echo "Seeding SwiftPM dependencies for $REL from ${SRC#"$MAIN_ROOT"/}..."

clone_into() {
	# clonefile copy; falls back to a plain copy on a non-APFS volume.
	cp -Rc "$1" "$2" 2>/dev/null || cp -R "$1" "$2"
}

# clonefile(2) called on a directory clones the whole hierarchy in one syscall,
# where `cp -Rc` issues one clonefile per file — tens of thousands for a resolved
# store. There is no CLI for the directory form, hence ctypes; python3 ships with
# the Command Line Tools this repo already requires. Clone only dependency entries:
# a package .build can also contain products and incremental state from another tree.
clone_tree() {
	python3 - "$1" "$2" <<-'PY' 2>/dev/null
		import ctypes, sys
		libc = ctypes.CDLL("libc.dylib", use_errno=True)
		libc.clonefile.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint32]
		sys.exit(0 if libc.clonefile(sys.argv[1].encode(), sys.argv[2].encode(), 0) == 0 else 1)
	PY
}

mkdir -p "$STAGING"
for entry in checkouts repositories artifacts prebuilts; do
	[ -e "$SRC/$entry" ] || continue
	if [ -d "$SRC/$entry" ] && clone_tree "$SRC/$entry" "$STAGING/$entry"; then
		continue
	fi
	# A clone that failed after creating the destination would make cp nest its copy
	# inside it.
	rm -rf "$STAGING/$entry"
	clone_into "$SRC/$entry" "$STAGING/$entry"
done
clone_into "$SRC/$MARKER" "$STAGING/$MARKER"

# Artifact entries record absolute xcframework paths, and local-package entries the
# tree they belong to — repoint both at this store and this tree. A worktree can live
# inside the main tree (.claude/worktrees/), which makes MAIN_ROOT a prefix of paths
# that are already correct: a rewritten store path, and a local-package path a seeded
# source store already pointed at this tree. Both are parked behind a placeholder
# first, so MAIN_ROOT only ever rewrites a path that still belongs to the main tree
# and no path is rewritten twice. Order matters: most specific prefix first.
sed -e "s|$SRC/|@@SEEDED_STORE@@/|g" \
	-e "s|$REPO_ROOT/|@@SEEDED_TREE@@/|g" \
	-e "s|$MAIN_ROOT/|$REPO_ROOT/|g" \
	-e "s|@@SEEDED_STORE@@|$DEST|g" \
	-e "s|@@SEEDED_TREE@@|$REPO_ROOT|g" \
	"$STAGING/$MARKER" >"$STAGING/$MARKER.rewritten"
mv -f "$STAGING/$MARKER.rewritten" "$STAGING/$MARKER"

# A rewrite that produced a path nothing lives at would install a store that looks
# resolved but is not, and the marker would keep later runs from fixing it. Every
# absolute path in the state must resolve; store paths still live under STAGING.
# The sed hop rewrites store paths to where they live right now instead of trimming
# the prefix inline: /bin/sh is bash 3.2, which misparses a quoted ${var#"$x"} inside
# a command substitution.
missing="$(grep -o '"/[^"]*"' "$STAGING/$MARKER" | tr -d '"' | sed "s|^$DEST/|$STAGING/|" | sort -u | while IFS= read -r p; do
	[ -e "$p" ] || { printf '%s' "$p"; break; }
done)"
if [ -n "$missing" ]; then
	echo "warning: seeded state points at a missing path ($missing); leaving $REL to SwiftPM" >&2
	exit 0
fi

# Claim the store. An empty leftover directory is removed first — rmdir cannot touch
# a store anything has written to — and any other existing store means a resolve owns
# it already, where letting that resolve finish beats seeding underneath it.
rmdir "$DEST" 2>/dev/null || true
if [ -f "$DEST/$MARKER" ]; then
	exit 0
elif [ -e "$DEST" ]; then
	echo "note: $REL is already populated; leaving it to SwiftPM" >&2
	exit 0
fi
mv "$STAGING" "$DEST" 2>/dev/null || exit 0
# A store that appeared between the check and the rename swallows the staging dir
# instead of being replaced by it — undo that and stand down.
if [ -d "$DEST/$(basename "$STAGING")" ]; then
	rm -rf "$DEST/$(basename "$STAGING")"
	echo "note: lost the race to populate $REL; leaving it to SwiftPM" >&2
fi
