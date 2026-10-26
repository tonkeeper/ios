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

    func testFeatureFlagsDescriptionListsEachFlagWithItsValueAndSource() {
        let configuration = makeConfiguration(
            bundle: ["earnEnabled": true],
            local: ["perpsEnabled": true],
            remote: ["ios_swapkit_enabled": true]
        )

        let lines = configuration.featureFlagsDescription.components(separatedBy: "\n")
        let rows = lines.map { $0.split(separator: " ").map(String.init) }
        let valueColumns = Set(lines.map { line in
            line.drop { $0 == " " }.drop { $0 != " " }.drop { $0 == " " }.startIndex.utf16Offset(in: line)
        })
        let sourceColumns = Set(lines.map { line in
            line.drop { $0 == " " }.drop { $0 != " " }.drop { $0 == " " }.drop { $0 != " " }.drop { $0 == " " }
                .startIndex.utf16Offset(in: line)
        })

        XCTAssertEqual(rows.count, FeatureFlag.allCases.count)
        XCTAssertEqual(rows.compactMap(\.first), rows.compactMap(\.first).sorted())
        XCTAssertTrue(rows.contains(["earnEnabled", "true", "bundle"]))
        XCTAssertTrue(rows.contains(["perpsEnabled", "true", "local"]))
        XCTAssertTrue(rows.contains(["swapKitEnabled", "true", "remote"]))
        XCTAssertTrue(rows.contains(["inAppReviewEnabled", "false", "default"]))
        XCTAssertEqual(valueColumns.count, 1)
        XCTAssertEqual(sourceColumns.count, 1)
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

    func makeConfiguration(
        bundle: [String: Bool] = [:],
        local: [String: Bool] = [:],
        remote: [String: Bool] = [:]
    ) -> Configuration {
        Configuration(
            bootConfigurationService: BootConfigurationServiceStub(
                bootConfigurations: BootConfigurations(mainnet: .empty, testnet: .empty)
            ),
            featureFlags: makeFeatureFlags(bundle: bundle, local: local, remote: remote),
            tkAppSettings: AppSettingsStub()
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

private struct BootConfigurationServiceStub: BootConfigurationService {
    let bootConfigurations: BootConfigurations

    func getConfiguration() throws -> BootConfigurations {
        bootConfigurations
    }

    func loadConfiguration() async throws -> BootConfigurations {
        bootConfigurations
    }
}

private final class AppSettingsStub: TKAppSettings {
    var isConfirmButtonInsteadSlider = false
    var raffleIsNewUser: Bool?
}
