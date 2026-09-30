#!/bin/sh
set -e

cd "$(git rev-parse --show-toplevel)/ios"

./scripts/tools/install_toolchain.sh
sh ./scripts/hooks/setup_hooks.sh
store="$(sh ./scripts/xcode_derived_data.sh)"
if [ -n "$store" ]; then
	sh ./scripts/provision_spm_deps.sh "$store"
fi

sh ./scripts/firebase/provision_firebase.sh
