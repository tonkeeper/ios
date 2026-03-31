#!/bin/bash

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

DST_PATH="${REPO_ROOT}/LocalPackages/core-swift/Packages/SwapAPI/Sources/SwapAPI"
SCHEMA_PATH="${SCRIPT_DIR}/openapi.yml"

cd "${SCRIPT_DIR}"

swift run swift-openapi-generator generate \
  --mode types --mode client \
  --output-directory "${DST_PATH}" \
  "${SCHEMA_PATH}"
