#!/bin/sh
# Run a dev tool at the version mise.toml pins for this repo.
#
# Invokes the mise shim by absolute path rather than putting the shims on PATH: a shim is
# a self-contained binary, so this also works where PATH holds neither mise nor its shims
# (a git hook started from a GUI client), and a machine that never ran `make setup` fails
# here instead of silently formatting or generating with whatever version it has.
# Resolving the pinned version, and installing it when missing, are mise's job. The shim
# reads mise.toml from the current directory, and the git hooks and agent hooks start at
# the repository root, one level above the project, so hop into the project dir first;
# callers that pass file arguments pass absolute paths or already run from there.
#
# Usage: scripts/tools/tool.sh <tool> [args...]
set -eu

tool="${1:-}"
if [ -z "$tool" ]; then
	echo "usage: $0 <tool> [args...]" >&2
	exit 2
fi
shift

shim="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims/$tool"
if [ ! -x "$shim" ]; then
	echo "error: no mise shim for $tool" >&2
	echo "       install the pinned toolchain: make setup" >&2
	exit 1
fi

cd "$(dirname "$0")/../.."
exec "$shim" "$@"
