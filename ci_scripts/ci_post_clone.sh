#!/bin/sh
set -eu

# Xcode Cloud only discovers ci_scripts next to the Xcode project, so this lives in
# ios/ and not at the repository root: the project directory is this script's parent.
cd "$(cd "$(dirname "$0")/.." && pwd)"

./scripts/setup.sh
