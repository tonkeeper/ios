SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

# Dev tools run at the versions pinned in mise.toml, resolved without relying on the
# caller's PATH. Install them with `make setup`.
TOOL := scripts/tools/tool.sh
SWIFTFORMAT := $(TOOL) swiftformat
SWIFTGEN := $(TOOL) swiftgen
SWIFTLINT := $(TOOL) swiftlint
XCBEAUTIFY := $(TOOL) xcbeautify

.PHONY: \
	locale \
	resources \
	analytics \
	analytics_check \
	format \
	hooks \
	setup \
	tonconnect_generate \
	tonkeeper_generate \
	trading_generate \
	perps_generate \
	kandelabr_generate \
	multichain_generate \
	swap_generate \
	api_generate \
	api_check \
	maestro_api_sync \
	maestro_api_check \
	compile \
	firebase_config \
	spm_deps \
	xcode_derived_data \
	spm \
	lsp_config \
	test \
	test_all \
	test_app_package \
	test_app

locale:
	$(SWIFTGEN) config run --config "./LocalPackages/TKLocalize/codegen/swiftgen.yml"
	$(SWIFTFORMAT) --config "./.swiftformat" "./LocalPackages/TKLocalize/Sources/TKLocalize/TKLocales.swift"

resources:
	mkdir -p "./LocalPackages/TKUIKit/TKUIKit/Sources/TKUIKit/Generated"
	$(SWIFTGEN) config run --config "./LocalPackages/TKUIKit/codegen/swiftgen.yml"
	$(SWIFTFORMAT) --config "./.swiftformat" "./LocalPackages/TKUIKit/TKUIKit/Sources/TKUIKit/Generated"

analytics:
	@scripts/analytics/sync_models.sh
	@scripts/analytics/check_key_limits.py

# Hold the generated event models to the ingestion APIs' key limits. Aptabase rejects a whole
# event whose property key is over 40 characters, and swiftlint cannot see these files
# (.swiftlint.yml excludes both generated directories).
analytics_check:
	@scripts/analytics/check_key_limits.py

format:
	$(SWIFTFORMAT) --config "./.swiftformat" "."

hooks:
	@scripts/hooks/setup_hooks.sh

setup:
	@scripts/setup.sh

# OpenAPI clients: one generator package for every API (scripts/apigen), with the
# per-API target names kept as the entry points. Spelled out rather than generated
# from a name list, because shell completion parses the Makefile text and does not
# expand functions, so a computed target list leaves `make <tab>` with nothing to offer.
tonconnect_generate tonkeeper_generate trading_generate perps_generate kandelabr_generate multichain_generate swap_generate:
	@scripts/apigen/generate.sh $(patsubst %_generate,%,$@)

api_generate:
	@scripts/apigen/generate.sh all

# Regenerate into a temp dir and diff against the checked-in sources: catches a
# schema edit that never got regenerated.
api_check:
	@scripts/apigen/generate.sh --check all

# Stamp the shared Maestro API HTTP runtime (scripts/api/_api_runtime.js) into
# every consumer script between the `// >>> api-runtime` markers. Maestro has no
# JS import mechanism, so this keeps a single source of truth without duplication.
maestro_api_sync:
	@python3 maestro_ui_tests/scripts/ci/sync_api_runtime.py

maestro_api_check:
	@python3 maestro_ui_tests/scripts/ci/sync_api_runtime.py --check

# Build

BUILD_DIR := ./build
BUILD_ROOT := $(CURDIR)/$(BUILD_DIR)
SOURCE_PACKAGES_DIR := $(BUILD_ROOT)/SourcePackages
GIT_CONFIG_FILE := $(BUILD_ROOT)/git-config
MODULE_CACHE_PATH := $(HOME)/Library/Developer/Xcode/DerivedData/ModuleCache.noindex
# Shared xcodebuild env: route git auth through the in-repo credential store and
# expose the cloned SourcePackages path to build-phase scripts (see comment below).
XCODEBUILD_ENV := GIT_CONFIG_GLOBAL=$(GIT_CONFIG_FILE) CLONED_SOURCE_PACKAGES_DIR=$(SOURCE_PACKAGES_DIR)
# Optional quiet output. Default (empty) keeps full progress output for humans.
XCBEAUTIFY_FLAGS := $(if $(filter 1,$(QUIET)),-qq,)

# Provision the gitignored Firebase config into the current working tree. Idempotent;
# fresh worktrees lack it (gitignored) and would fail the "Firebase plist" build phase.
firebase_config:
	@scripts/firebase/provision_firebase.sh

# Clone the main working tree's resolved SwiftPM store into a fresh worktree
# (clonefile, no network, ~no extra disk). Idempotent; no-op in the main tree.
spm_deps:
	@scripts/provision_spm_deps.sh $(BUILD_DIR)/SourcePackages

# Keep Xcode GUI builds of this working tree in-tree instead of a global
# DerivedData dir, and seed the store they resolve into. Idempotent; per user, so
# every working tree needs it once (also run on `make setup` and by the Claude Code
# worktree hook). No effect on `make` builds, which pass -derivedDataPath.
xcode_derived_data:
#   `A && [ -z ] || B` would run B when A itself failed, reporting a failed location
#   update as success and handing B an empty store path.
	@store=$$(scripts/xcode_derived_data.sh) && \
		if [ -n "$$store" ]; then scripts/provision_spm_deps.sh "$$store"; fi

compile: firebase_config spm_deps
	@$(XCBEAUTIFY) --version >/dev/null
	@scripts/setup_build_credentials.sh $(BUILD_ROOT)
# Cache placement follows one rule: content-addressed caches go global (max reuse,
# safe to share); version-pinned build state stays in-repo (per-worktree, clean
# teardown).
#   - CLANG_MODULE_CACHE_PATH -> global Xcode ModuleCache: clang keys each .pcm by
#     the full compile context, so one dir is reused across every worktree, scheme,
#     and the Xcode GUI (rebuilds on mismatch, never corrupts). This is Xcode's own
#     default location; we name it explicitly because -derivedDataPath would
#     otherwise fragment the module cache into each DerivedData root, re-precompiling
#     the SDK modules per scheme.
#   - -clonedSourcePackagesDirPath -> in-repo build/SourcePackages: one checkout
#     reused by compile + every test_* scheme in this worktree. Cross-worktree reuse
#     comes from the global SwiftPM mirror (~/Library/Caches/org.swift.swiftpm), so
#     the per-worktree checkout costs no re-download. Kept local because checkouts
#     are pinned to this worktree's Package.resolved.
#     CLONED_SOURCE_PACKAGES_DIR mirrors this path into the environment because the
#     Keeper target's "Crashlytics+dSYM" build-phase script reads it to locate
#     firebase-ios-sdk/Crashlytics/run. Xcode does not export it to script phases,
#     and the script's fallback (${BUILD_DIR%/Build/*}/SourcePackages) resolves to
#     DerivedData/SourcePackages — wrong once -clonedSourcePackagesDirPath moves the
#     checkout elsewhere — so the build fails without this env var.
#   - -derivedDataPath -> in-repo build/DerivedData: per-worktree so removing the
#     worktree reclaims it instead of orphaning a path-hashed dir in $HOME.
	@set -o pipefail; echo 'building Keeper...' && \
		$(XCODEBUILD_ENV) \
		xcodebuild \
		-project Keeper.xcodeproj \
		-scheme Keeper \
		-configuration KeeperDebug \
		-destination 'generic/platform=iOS Simulator' \
		ARCHS=arm64 \
		CLANG_MODULE_CACHE_PATH=$(MODULE_CACHE_PATH) \
		-derivedDataPath $(BUILD_ROOT)/DerivedData \
		-clonedSourcePackagesDirPath $(SOURCE_PACKAGES_DIR) \
		build | $(XCBEAUTIFY) --disable-logging $(XCBEAUTIFY_FLAGS)

# Per-package SwiftPM build
# Build one or a set of LocalPackages modules for the iOS Simulator:
#   make spm PKG=TKUIKit
#   make spm PKG="TKUIKit TKCore KeeperCore"
#   make spm PKG=TKUIKit QUIET=1
# Use make compile for the whole app (full Xcode build).

spm:
	@test -n "$(PKG)" || (echo 'PKG is required, e.g. make spm PKG=TKUIKit or PKG="TKUIKit TKCore"'; exit 1)
	@QUIET="$(QUIET)" scripts/spm_build.sh $(PKG)

# Generate .sourcekit-lsp/config.json so sourcekit-lsp / the swift-lsp plugin
# index the iOS-only packages against the iOS Simulator SDK.
lsp_config:
	@scripts/gen_sourcekit_lsp_config.sh

# Test

# Prefer a booted iPhone, else the newest installed one (simctl lists runtimes in
# ascending order): a hardcoded device name aborts every test run on a machine that does
# not happen to have that exact simulator. Picked in one awk pass, because in
# `grep Booted || tail -n 1` the grep consumes the pipe and leaves tail nothing to read.
# Deferred on purpose — `?=` keeps the assignment recursive, so simctl runs only when a
# test recipe expands it.
TEST_DESTINATION ?= platform=iOS Simulator,id=$(shell xcrun simctl list devices available | awk '/iPhone/ { last = $$0; if (/Booted/) { print; found = 1; exit } } END { if (!found && last) print last }' | grep -oE '[0-9A-Fa-f-]{36}')
TEST_ONLY ?=

test: test_all

# Single complete unit-test run via the unified KeeperUnitTests scheme
# (9 bundles across KeeperCore/TronSwift/TKCore/TKLocalize/App/TKUIKit).
# Reuses the test_project_scheme template for SCM/lockfile flags.
test_all: SCHEME=KeeperUnitTests
test_all: test_project_scheme

test_project_scheme: spm_deps
	@$(XCBEAUTIFY) --version >/dev/null
	@scripts/setup_build_credentials.sh $(BUILD_ROOT)
	@test -n "$(SCHEME)" || (echo "SCHEME is required"; exit 1)
	@case '$(TEST_DESTINATION)' in *id=) echo 'error: no available iPhone simulator; install one in Xcode or pass TEST_DESTINATION' >&2; exit 1;; esac
# Same cache rule as compile: CLANG_MODULE_CACHE_PATH points at the global Xcode
# module cache (shared across all schemes, worktrees, and the GUI — content-addressed,
# max reuse); cloned SourcePackages below is the single in-repo checkout shared across
# compile + all test_* schemes in this worktree (cross-worktree reuse via the global
# SwiftPM mirror); DerivedData is per-scheme + in-repo for clean per-worktree teardown.
	@set -o pipefail; echo 'running $(SCHEME) tests...' && \
		$(XCODEBUILD_ENV) \
		xcodebuild \
		-project Keeper.xcodeproj \
		-scheme $(SCHEME) \
		-destination '$(TEST_DESTINATION)' \
		-disableAutomaticPackageResolution \
		-onlyUsePackageVersionsFromResolvedFile \
		-skipPackageUpdates \
		-derivedDataPath $(BUILD_ROOT)/DerivedData-tests/$(SCHEME) \
		-clonedSourcePackagesDirPath $(SOURCE_PACKAGES_DIR) \
		SWIFT_SUPPRESS_WARNINGS=NO \
		CLANG_MODULE_CACHE_PATH=$(MODULE_CACHE_PATH) \
		test $(if $(TEST_ONLY),-only-testing:$(TEST_ONLY),) | $(XCBEAUTIFY)

test_core_swift: SCHEME=WalletCore
test_core_swift: test_project_scheme

test_tron_swift_package: SCHEME=TronSwift
test_tron_swift_package: test_project_scheme

test_tkcore_package: SCHEME=TKCore
test_tkcore_package: test_project_scheme

test_tklocalize_package: SCHEME=TKLocalize
test_tklocalize_package: test_project_scheme

test_app_package: SCHEME=App
test_app_package: test_project_scheme

test_core_components: SCHEME=WalletCore
test_core_components: TEST_ONLY=KeeperCoreComponentsTests
test_core_components: test_project_scheme

test_keeper_core: SCHEME=WalletCore
test_keeper_core: TEST_ONLY=KeeperCoreTests
test_keeper_core: test_project_scheme

test_wallet_core: SCHEME=WalletCore
test_wallet_core: TEST_ONLY=WalletCoreTests
test_wallet_core: test_project_scheme

test_tron_swift: SCHEME=TronSwift
test_tron_swift: TEST_ONLY=TronSwift-Tests
test_tron_swift: test_project_scheme

test_tkcryptokit: SCHEME=TronSwift
test_tkcryptokit: TEST_ONLY=TKCryptoKit-Tests
test_tkcryptokit: test_project_scheme

test_tkcore: SCHEME=TKCore
test_tkcore: TEST_ONLY=TKCoreTests
test_tkcore: test_project_scheme

test_tklocalize: SCHEME=TKLocalize
test_tklocalize: TEST_ONLY=TKLocalizeTests
test_tklocalize: test_project_scheme

test_tkuikit: SCHEME=TKUIKit
test_tkuikit: TEST_ONLY=TKUIKitTests
test_tkuikit: test_project_scheme

test_app: SCHEME=App
test_app: TEST_ONLY=AppTests
test_app: test_project_scheme
