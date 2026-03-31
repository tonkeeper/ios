#!/bin/sh
set -eu

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"

cd "$REPO_ROOT"

./scripts/setup.sh
