#!/bin/sh
# Generate .sourcekit-lsp/config.json so sourcekit-lsp (and the swift-lsp plugin)
# index the LocalPackages SwiftPM modules against the iOS Simulator SDK.
#
# Without this, sourcekit-lsp builds the modules for the macOS host and reports
# phantom errors such as "no such module 'UIKit'". The SDK path is machine- and
# Xcode-version-specific, so the file is generated locally and gitignored rather
# than committed (no hardcoded absolute paths in the repo).
#
# Usage: scripts/gen_sourcekit_lsp_config.sh
#   IOS_MIN   override the iOS deployment target used for the triple (default 15.0)

set -eu

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT"

IOS_MIN="${IOS_MIN:-15.0}"
TRIPLE="arm64-apple-ios${IOS_MIN}-simulator"
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)

mkdir -p "$REPO_ROOT/.sourcekit-lsp"
CONFIG="$REPO_ROOT/.sourcekit-lsp/config.json"
cat >"$CONFIG" <<EOF
{
  "swiftPM": {
    "triple": "$TRIPLE",
    "swiftCompilerFlags": ["-sdk", "$SDK", "-target", "$TRIPLE"],
    "cCompilerFlags": ["-isysroot", "$SDK"]
  }
}
EOF

echo "wrote $CONFIG (triple=$TRIPLE)"
