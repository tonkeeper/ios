@testable import KeeperCore
import TKFeatureFlags
import XCTest

final class FeatureFlagResolutionTests: XCTestCase {
    func testBundleOverrideOutranksLocalOverride() {
        let featureFlags = makeFeatureFlags(
            bundle: ["perpsEnabled": false],
            local: ["perpsEnabled": true],
            remote: ["ios_perps_enabled": true]
        )

        XCTAssertEqual(featureFlags.devOverride(for: .perpsEnabled), false)
        XCTAssertFalse(featureFlags[.perpsEnabled])
    }

    func testLocalOverrideOutranksRemoteValue() {
        let featureFlags = makeFeatureFlags(
            local: ["perpsEnabled": false],
            remote: ["ios_perps_enabled": true]
        )

        XCTAssertEqual(featureFlags.devOverride(for: .perpsEnabled), false)
        XCTAssertFalse(featureFlags[.perpsEnabled])
    }

    func testDevOverrideIsAbsentWhenFlagFallsThroughToRemoteOrDefault() {
        let featureFlags = makeFeatureFlags(remote: ["ios_perps_enabled": true])

        XCTAssertNil(featureFlags.devOverride(for: .perpsEnabled))
        XCTAssertTrue(featureFlags[.perpsEnabled])
    }

    func testAllValuesReportsBundleAndLocalChannelsSeparately() {
        let featureFlags = makeFeatureFlags(
            bundle: ["perpsEnabled": true],
            local: ["perpsEnabled": false],
            remote: ["ios_perps_enabled": false]
        )

        let value = featureFlags.allValues[.perpsEnabled]

        XCTAssertEqual(value?.bundleValue, true)
        XCTAssertEqual(value?.localValue, false)
        XCTAssertEqual(value?.remoteValue, false)
        XCTAssertEqual(value?.resolvedValue, true)
    }

    func testAllValuesLeavesBundleChannelEmptyWithoutBundleOverride() {
        let featureFlags = makeFeatureFlags(local: ["perpsEnabled": true])

        let value = featureFlags.allValues[.perpsEnabled]

        XCTAssertNil(value?.bundleValue)
        XCTAssertEqual(value?.localValue, true)
    }

    func testWritingLocalOverrideCannotDisplaceBundleOverride() {
        let featureFlags = makeFeatureFlags(bundle: ["perpsEnabled": true])

        featureFlags[.perpsEnabled] = false

        XCTAssertEqual(featureFlags.allValues[.perpsEnabled]?.localValue, false)
        XCTAssertTrue(featureFlags[.perpsEnabled])
    }
}

private extension FeatureFlagResolutionTests {
    func makeFeatureFlags(
        bundle: [String: Bool] = [:],
        local: [String: Bool] = [:],
        remote: [String: Bool] = [:]
    ) -> TKFeatureFlagsImplementation {
        TKFeatureFlagsImplementation(
            localProvider: LocalFeatureFlagsProviderStub(values: local),
            remoteConfigProvider: RemoteConfigProviderStub(values: remote),
            overrides: bundle
        )
    }
}

private final class LocalFeatureFlagsProviderStub: TKLocalFeatureFlagsProvider {
    private var values: [String: Bool]

    init(values: [String: Bool]) {
        self.values = values
    }

    subscript(key: String) -> Bool? {
        get { values[key] }
        set { values[key] = newValue }
    }
}

private struct RemoteConfigProviderStub: RemoteConfigProvider {
    let values: [String: Bool]

    func load() async {}

    subscript(_ flag: String) -> Bool? {
        values[flag]
    }
}
