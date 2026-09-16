#!/bin/sh
set -e

# Prepares the in-repo build dir so xcodebuild can resolve private SwiftPM
# dependencies over HTTPS using the gh CLI token.
#   - creates <build-root> and <build-root>/SourcePackages
#   - writes a git credential store + config pointed at by GIT_CONFIG_GLOBAL
# No-op for the credentials part when gh is absent or unauthenticated.

build_root="$1"

if [ -z "$build_root" ]; then
  echo "usage: $0 <build-root>" >&2
  exit 2
fi

mkdir -p "$build_root" "$build_root/SourcePackages"
touch "$build_root/git-config"

if command -v gh >/dev/null 2>&1; then
  token="$(gh auth token 2>/dev/null || true)"
  if [ -n "$token" ]; then
    umask 077
    printf 'https://x-access-token:%s@github.com\nhttps://x-access-token:%s@api.github.com\nhttps://x-access-token:%s@codeload.github.com\n' "$token" "$token" "$token" \
      > "$build_root/git-credentials"
    printf '[credential]\n\thelper = store --file %s/git-credentials\n' "$build_root" \
      > "$build_root/git-config"
  fi
fi
