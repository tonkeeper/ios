#!/bin/bash
# Generate the file->target mapping periphery's generic driver needs.
#
# The Xcode driver cannot see targets that live in nested local packages, so the
# scan runs on the generic driver instead and needs every indexed Swift file
# mapped to the target that compiled it. The mapping is derived from the on-disk
# layout rather than from the package manifests, because target paths vary
# (`<Pkg>/Sources/<Target>`, `<Pkg>/<Pkg>/Sources/<Target>`, and the
# manifest-less sub-packages under KeeperCore/Packages): an outermost directory
# named Sources or Tests holds one directory per target. Directories named
# Sources nested *inside* such a container are feature folders of the enclosing
# target, not target roots. The three Xcode targets own one top-level directory
# each.
#
# Test targets are left out by default: `make compile` builds the Keeper
# scheme, which does not build them, and periphery errors on a mapped target
# with no index data. Excluding them is also what surfaces production API that
# only its own tests still reference. Set INCLUDE_TESTS=1 after a
# build-for-testing run into the same derived data to map them as well.
#
# Usage: scripts/periphery/gen_file_targets.sh [output-path]
#        INCLUDE_TESTS=1 scripts/periphery/gen_file_targets.sh [output-path]
#        default output: build/periphery/file_targets.json

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT="${1:-$REPO_ROOT/build/periphery/file_targets.json}"

cd "$REPO_ROOT"
mkdir -p "$(dirname "$OUTPUT")"

INCLUDE_TESTS="${INCLUDE_TESTS:-0}" python3 - "$OUTPUT" <<'PY'
import json
import os
import sys

output = sys.argv[1]
include_tests = os.environ.get("INCLUDE_TESTS", "0") not in ("", "0", "no", "false")

# Top-level Xcode targets: directory -> target name in Keeper.xcodeproj.
XCODE_TARGETS = {
    "Keeper": "Keeper",
    "KeeperWidget": "KeeperWidgetExtension",
    "KeeperIntents": "KeeperIntents",
}

CONTAINER_NAMES = ("Sources", "Tests")
# Built by neither the Keeper scheme nor the unit-test schemes.
EXCLUDED_TARGETS = {"LightweightCharts"}
SKIP_DIR_NAMES = {".build", ".git", "build", "DerivedData", ".swiftpm"}

mapping = {}


def add(path, target):
    targets = mapping.setdefault(path, [])
    if target not in targets:
        targets.append(target)


def swift_files(root):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIR_NAMES]
        for name in filenames:
            if name.endswith(".swift"):
                yield os.path.join(dirpath, name)


for directory, target in XCODE_TARGETS.items():
    for path in swift_files(directory):
        add(path, target)

for dirpath, dirnames, filenames in os.walk("LocalPackages"):
    dirnames[:] = [d for d in dirnames if d not in SKIP_DIR_NAMES]
    if os.path.basename(dirpath) not in CONTAINER_NAMES:
        continue
    parts = dirpath.split(os.sep)[:-1]
    if any(part in CONTAINER_NAMES for part in parts):
        continue  # feature folder inside a target, not a target container
    if os.path.basename(dirpath) == "Tests" and not include_tests:
        continue
    for entry in sorted(dirnames):
        if entry in EXCLUDED_TARGETS:
            continue
        for path in swift_files(os.path.join(dirpath, entry)):
            add(path, entry)
    # A single-target package may keep its sources directly under Sources/.
    package_name = os.path.basename(os.path.dirname(dirpath))
    if package_name in EXCLUDED_TARGETS:
        continue
    for name in sorted(filenames):
        if name.endswith(".swift"):
            add(os.path.join(dirpath, name), package_name)

# Periphery resolves indexed files by absolute path, so the mapping is absolute
# (it lands in gitignored build/ and is regenerated per checkout anyway).
absolute = {os.path.abspath(path): targets for path, targets in mapping.items()}

with open(output, "w") as handle:
    json.dump({"fileTargets": absolute}, handle, indent=2, sort_keys=True)

targets = {target for entries in mapping.values() for target in entries}
print(f"{len(mapping)} files -> {len(targets)} targets: {output}")
PY
