SHELL := /bin/sh

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

compile:
	@scripts/require_tool.sh xcbeautify "brew install xcbeautify"
	mkdir -p ./build
	echo 'building Tonkeeper...' && \
		HOME=./build/codex_home \
		SWIFTPM_CACHE_PATH=./build/swiftpm-cache \
		SWIFTPM_CONFIG_DIR=./build/swiftpm-config \
		CLANG_MODULE_CACHE_PATH=./build/clang-module-cache \
		CLONED_SOURCE_PACKAGES_DIR=./build/SourcePackages \
		xcodebuild \
		-project Tonkeeper.xcodeproj \
		-scheme Tonkeeper \
		-configuration TonkeeperDebug \
		-destination 'generic/platform=iOS Simulator' \
		-derivedDataPath ./build/DerivedData \
		-clonedSourcePackagesDirPath ./build/SourcePackages \
		build | xcbeautify
