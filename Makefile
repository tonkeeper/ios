SHELL := /bin/sh

.PHONY: \
	locale \
	analytics \
	format \
	hooks \
	setup \
	tonconnect_generate \
	compile \
	test \
	test_all

locale:
	@scripts/require_tool.sh swiftgen "brew install swiftgen"
	swiftgen config run --config "./LocalPackages/TKLocalize/codegen/swiftgen.yml"

analytics:
	@scripts/analytics/sync_models.sh

format:
	@scripts/require_tool.sh swiftformat "brew install swiftformat"
	swiftformat --config "./.swiftformat" "."

hooks:
	@scripts/hooks/setup_hooks.sh

setup:
	@scripts/setup.sh

tonconnect_generate:
	@scripts/tonconnect_apigen/generate_api.sh

# Build

BUILD_DIR := ./build

compile:
	@scripts/require_tool.sh xcbeautify "brew install xcbeautify"
	mkdir -p $(BUILD_DIR)
	echo 'building Tonkeeper...' && \
		HOME=$(BUILD_DIR)/codex_home \
		SWIFTPM_CACHE_PATH=$(BUILD_DIR)/swiftpm-cache \
		SWIFTPM_CONFIG_DIR=$(BUILD_DIR)/swiftpm-config \
		CLANG_MODULE_CACHE_PATH=$(BUILD_DIR)/clang-module-cache \
		CLONED_SOURCE_PACKAGES_DIR=$(BUILD_DIR)/SourcePackages \
		xcodebuild \
		-project Tonkeeper.xcodeproj \
		-scheme Tonkeeper \
		-configuration TonkeeperDebug \
		-destination 'generic/platform=iOS Simulator' \
		-derivedDataPath $(BUILD_DIR)/DerivedData \
		-clonedSourcePackagesDirPath $(BUILD_DIR)/SourcePackages \
		build | xcbeautify

# Test

TEST_DESTINATION ?= platform=iOS Simulator,name=iPhone 17
TEST_ONLY ?=

test: test_all

test_all: test_core_swift test_tron_swift_package test_tkcore_package test_tklocalize_package test_tkchart_package

test_project_scheme:
	@scripts/require_tool.sh xcbeautify "brew install xcbeautify"
	@mkdir -p $(BUILD_DIR) \
		$(BUILD_DIR)/codex_home \
		$(BUILD_DIR)/swiftpm-cache \
		$(BUILD_DIR)/swiftpm-config \
		$(BUILD_DIR)/clang-module-cache \
		$(BUILD_DIR)/SourcePackages
	@test -n "$(SCHEME)" || (echo "SCHEME is required"; exit 1)
	@echo 'running $(SCHEME) tests...' && \
		HOME=$(CURDIR)/$(BUILD_DIR)/codex_home \
		SWIFTPM_CONFIG_DIR=$(CURDIR)/$(BUILD_DIR)/swiftpm-config \
		CLANG_MODULE_CACHE_PATH=$(CURDIR)/$(BUILD_DIR)/clang-module-cache \
		xcodebuild \
		-project Tonkeeper.xcodeproj \
		-scheme $(SCHEME) \
		-destination '$(TEST_DESTINATION)' \
		-disableAutomaticPackageResolution \
		-onlyUsePackageVersionsFromResolvedFile \
		-skipPackageUpdates \
		-derivedDataPath $(CURDIR)/$(BUILD_DIR)/DerivedData-tests/$(SCHEME) \
		-clonedSourcePackagesDirPath $(CURDIR)/$(BUILD_DIR)/SourcePackages \
		-packageCachePath $(CURDIR)/$(BUILD_DIR)/swiftpm-cache \
		SWIFT_SUPPRESS_WARNINGS=NO \
		test $(if $(TEST_ONLY),-only-testing:$(TEST_ONLY),) | xcbeautify

test_core_swift: SCHEME=WalletCore
test_core_swift: test_project_scheme

test_tron_swift_package: SCHEME=TronSwift
test_tron_swift_package: test_project_scheme

test_tkcore_package: SCHEME=TKCore
test_tkcore_package: test_project_scheme

test_tklocalize_package: SCHEME=TKLocalize
test_tklocalize_package: test_project_scheme

test_tkchart_package: SCHEME=TKChart
test_tkchart_package: test_project_scheme

test_core_components: SCHEME=WalletCore
test_core_components: TEST_ONLY=CoreComponentsTests
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

test_tkchart: SCHEME=TKChart
test_tkchart: TEST_ONLY=TKChartTests
test_tkchart: test_project_scheme
