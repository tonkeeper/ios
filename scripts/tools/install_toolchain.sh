#!/bin/sh
# Install the dev tools pinned in mise.toml. Idempotent; called by `make setup`.
#
# mise is the provisioner, not the resolver: tools are invoked through
# scripts/tools/tool.sh, so make targets and git hooks work without any shell
# activation. Activating mise in your own shell is optional and only affects direct
# `swiftformat` / `swiftlint` calls you type yourself.
set -eu

# Nothing on a CI machine uses these tools — Xcode Cloud reaches this through
# ci_scripts/ci_post_clone.sh -> scripts/setup.sh, and no workflow calls a make target
# that needs them — so skip the install there, as the hooks build phase already does.
[ -z "${CI:-}" ] || exit 0

cd "$(git rev-parse --show-toplevel)/ios"

if ! command -v mise >/dev/null 2>&1; then
	if ! command -v brew >/dev/null 2>&1; then
		echo "error: Homebrew is required to install the pinned dev tools" >&2
		echo "       install it (see https://brew.sh), then rerun make setup:" >&2
		echo '       /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' >&2
		exit 1
	fi
	echo "installing mise..."
	brew install mise
fi

# mise refuses to read a config it has not been told to trust.
mise trust --yes >/dev/null

echo "installing pinned dev tools (mise.toml)..."
mise install --yes

mise list --current
