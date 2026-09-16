#!/bin/sh
# Provision the gitignored Firebase config (Tonkeeper/Resources/Firebase) into the
# current working tree. Idempotent: returns immediately if already present.
#
# Why this exists: the Firebase config dir is gitignored, so a fresh `git worktree`
# never gets it.
set -eu

cd "$(git rev-parse --show-toplevel)"
DEST="Tonkeeper/Resources/Firebase"

# Already provisioned — nothing to do (this is the hot path on every build).
[ -f "$DEST/Tonkeeper/GoogleService-Info.plist" ] && exit 0

# Prefer the main working tree's copy: no network, no SSH. --git-common-dir points
# at the shared `.git`; its parent is the main working tree root.
COMMON_GIT_DIR="$(cd "$(git rev-parse --git-common-dir)" && pwd)"
MAIN_ROOT="$(dirname "$COMMON_GIT_DIR")"
SRC="$MAIN_ROOT/$DEST"
if [ "$MAIN_ROOT" != "$PWD" ] && [ -f "$SRC/Tonkeeper/GoogleService-Info.plist" ]; then
  echo "Provisioning Firebase config from main working tree: $SRC"
  rm -rf "$DEST"
  cp -R "$SRC" "$DEST"
  exit 0
fi

# FIREBASE_LOCAL_ONLY is for callers that must not touch the network: the
# post-checkout hook provisions in the background, where an SSH clone could prompt or
# hang unseen. `make compile` runs this again in the foreground and clones there.
[ -z "${FIREBASE_LOCAL_ONLY:-}" ] || exit 0

# Fallback: fetch from the private keys repo (requires SSH access).
echo "Firebase config absent in main working tree; cloning ios_keys..."
rm -rf ./ios_keys
trap 'rm -rf ./ios_keys' EXIT
git clone git@github.com:tonkeeper/ios_keys.git ./ios_keys
rm -rf "$DEST"
cp -R ./ios_keys/Firebase "$DEST"
