#!/bin/sh
set -e

tool="$1"
shift

if [ -z "$tool" ]; then
  echo "usage: $0 <tool> [install_hint...]" >&2
  exit 2
fi

if command -v "$tool" >/dev/null 2>&1; then
  exit 0
fi

echo "Missing required dependency: $tool" >&2
if [ "$#" -gt 0 ]; then
  echo "" >&2
  echo "Install it with one of the following commands:" >&2
  for hint in "$@"; do
    echo "  $hint" >&2
  done
fi
exit 1
