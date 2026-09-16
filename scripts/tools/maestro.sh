#!/bin/sh
# Run the Maestro CLI, resolving it without relying on the caller's PATH.
#
# The installer puts maestro in ~/.maestro/bin and exports it from ~/.zshrc, which only
# interactive shells read — an MCP server or git hook spawned by a GUI client gets a PATH
# without it. Look on PATH first (Homebrew, a custom install), then fall back to the
# installer's own location; MAESTRO_BIN overrides both.
#
# Usage: scripts/tools/maestro.sh [args...]
set -eu

if [ -n "${MAESTRO_BIN:-}" ]; then
	exec "$MAESTRO_BIN" "$@"
fi

if command -v maestro >/dev/null 2>&1; then
	exec maestro "$@"
fi

if [ -x "$HOME/.maestro/bin/maestro" ]; then
	exec "$HOME/.maestro/bin/maestro" "$@"
fi

echo "error: maestro not found on PATH or in \$HOME/.maestro/bin" >&2
echo "       install it: curl -fsSL https://get.maestro.mobile.dev | bash" >&2
echo "       or point MAESTRO_BIN at the binary" >&2
exit 1
