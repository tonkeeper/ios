#!/bin/sh
set -e

cd "$(git rev-parse --show-toplevel)"
sh ./scripts/hooks/setup_hooks.sh

git clone git@github.com:tonkeeper/ios_keys.git ./ios_keys
rm -rf ./Tonkeeper/Resources/Firebase
cp -R ./ios_keys/Firebase ./Tonkeeper/Resources/Firebase
rm -rf ios_keys
