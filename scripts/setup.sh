#!/bin/sh
set -e

cd "$(git rev-parse --show-toplevel)/ios"

./scripts/tools/install_toolchain.sh
if [ -z "${CI:-}" ]; then
	python3 -m venv build/apigen-python
	build/apigen-python/bin/python3 -m pip install --disable-pip-version-check -r scripts/apigen/requirements.txt
fi
git config core.hooksPath .githooks
# Xcode Cloud never opens the GUI and builds into its own DerivedData ($CI_DERIVED_DATA_PATH).
if [ "${CI_XCODE_CLOUD:-}" != TRUE ]; then
	store="$(sh ./scripts/xcode_derived_data.sh)"
	if [ -n "$store" ]; then
		sh ./scripts/provision_spm_deps.sh "$store"
	fi
fi

sh ./scripts/firebase/provision_firebase.sh
