#!/bin/sh
set -eu

# The PR Gate's Build action builds the KeeperCIGate scheme, one small package. This script then builds and runs the
# KeeperCI test plan on the same VM. A Test action would upload the test products to a second VM, and Xcode Cloud
# would spend about 10 minutes processing the results of the full suite.
[ "${CI_XCODE_SCHEME:-}" = KeeperCIGate ] || exit 0
[ "${CI_XCODEBUILD_EXIT_CODE:-0}" = 0 ] || exit 0

simulator=$(xcrun simctl create PRGate com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro)
XCODE_XCCONFIG_FILE=${XCODE_XCCONFIG_FILE:-$CI_PRIMARY_REPOSITORY_PATH/ios/Configurations/PackageBuildSettings.xcconfig} \
	xcodebuild test \
	-project "$CI_PRIMARY_REPOSITORY_PATH/ios/Keeper.xcodeproj" \
	-scheme KeeperCI \
	-destination "platform=iOS Simulator,id=$simulator" \
	-derivedDataPath "$CI_DERIVED_DATA_PATH" \
	-disableAutomaticPackageResolution \
	CODE_SIGN_IDENTITY=- AD_HOC_CODE_SIGNING_ALLOWED=YES COMPILER_INDEX_STORE_ENABLE=NO
