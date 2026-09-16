@testable import KeeperCore
import TKFeatureFlags
import XCTest

final class FeatureFlagResolutionTests: XCTestCase {
    func testBootConfigurationVetoDisablesFlagWithoutDevOverride() throws {
        let configuration = try makeConfiguration(multichainEnabledByBootConfiguration: false)

        XCTAssertTrue(configuration.isFeatureFlagDisabledByBootConfiguration(.multichainEnabled))
        XCTAssertFalse(configuration.featureEnabled(.multichainEnabled))
    }

    func testBootConfigurationVetoOutranksRemoteValue() throws {
        let configuration = try makeConfiguration(
            multichainEnabledByBootConfiguration: false,
            remote: ["ios_multichain_enabled": true]
        )

        XCTAssertFalse(configuration.featureEnabled(.multichainEnabled))
    }

    func testLocalOverrideForcesFlagOnDespiteBootConfigurationVeto() throws {
        let configuration = try makeConfiguration(
            multichainEnabledByBootConfiguration: false,
            local: ["multichainEnabled": true]
        )

        XCTAssertTrue(configuration.isFeatureFlagDisabledByBootConfiguration(.multichainEnabled))
        XCTAssertTrue(configuration.featureEnabled(.multichainEnabled))
    }

    func testBundleOverrideForcesFlagOnDespiteBootConfigurationVeto() throws {
        let configuration = try makeConfiguration(
            multichainEnabledByBootConfiguration: false,
            bundle: ["multichainEnabled": true]
        )

        XCTAssertTrue(configuration.featureEnabled(.multichainEnabled))
    }

    func testLocalOverrideForcesFlagOffWhenBootConfigurationAllowsIt() throws {
        let configuration = try makeConfiguration(
            multichainEnabledByBootConfiguration: true,
            local: ["multichainEnabled": false],
            remote: ["ios_multichain_enabled": true]
        )

        XCTAssertFalse(configuration.isFeatureFlagDisabledByBootConfiguration(.multichainEnabled))
        XCTAssertFalse(configuration.featureEnabled(.multichainEnabled))
    }

    func testUngatedFlagResolvesRemoteValue() throws {
        let configuration = try makeConfiguration(
            multichainEnabledByBootConfiguration: false,
            remote: ["ios_perps_enabled": true]
        )

        XCTAssertFalse(configuration.isFeatureFlagDisabledByBootConfiguration(.perpsEnabled))
        XCTAssertTrue(configuration.featureEnabled(.perpsEnabled))
    }

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
        XCTAssertNil(featureFlags.devOverride(for: .walletKitEnabled))
        XCTAssertFalse(featureFlags[.walletKitEnabled])
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

    func testResetValueDropsLocalOverride() {
        let featureFlags = makeFeatureFlags(
            local: ["multichainEnabled": true],
            remote: ["ios_multichain_enabled": false]
        )

        featureFlags.resetValue(for: .multichainEnabled)

        XCTAssertNil(featureFlags.devOverride(for: .multichainEnabled))
        XCTAssertFalse(featureFlags[.multichainEnabled])
    }

    func testImportMultichainStaysEnabledWhenMultichainRolloutIsOff() throws {
        let configuration = try makeConfiguration(
            multichainEnabledByBootConfiguration: true,
            remote: [
                "ios_multichain_enabled": false,
                "ios_import_multichain_enabled": true,
            ]
        )

        XCTAssertTrue(configuration.featureEnabled(.importMultichainEnabled))
        XCTAssertFalse(configuration.featureEnabled(.multichainEnabled))
    }

    func testImportMultichainFollowsMultichainFlagWithoutItsOwnFlag() throws {
        let configuration = try makeConfiguration(
            multichainEnabledByBootConfiguration: true,
            remote: ["ios_multichain_enabled": true]
        )

        XCTAssertTrue(configuration.featureEnabled(.importMultichainEnabled))
    }

    func testBootConfigurationVetoDisablesImportMultichainFlagToo() throws {
        let configuration = try makeConfiguration(
            multichainEnabledByBootConfiguration: false,
            remote: [
                "ios_multichain_enabled": true,
                "ios_import_multichain_enabled": true,
            ]
        )

        XCTAssertTrue(configuration.isFeatureFlagDisabledByBootConfiguration(.importMultichainEnabled))
        XCTAssertFalse(configuration.featureEnabled(.importMultichainEnabled))
        XCTAssertFalse(configuration.featureEnabled(.multichainEnabled))
    }

    func testResolvedFeatureFlagsCoverEveryFlagAndApplyBootConfigurationVeto() throws {
        let configuration = try makeConfiguration(
            multichainEnabledByBootConfiguration: false,
            remote: [
                "ios_multichain_enabled": true,
                "ios_perps_enabled": true,
            ]
        )

        let resolved = configuration.resolvedFeatureFlags

        XCTAssertEqual(Set(resolved.keys), Set(FeatureFlag.allCases))
        XCTAssertEqual(resolved[.multichainEnabled], false)
        XCTAssertEqual(resolved[.importMultichainEnabled], false)
        XCTAssertEqual(resolved[.perpsEnabled], true)
        XCTAssertEqual(resolved[.walletKitEnabled], false)
    }

    func testResolvedFeatureFlagsFollowDevOverride() throws {
        let configuration = try makeConfiguration(
            multichainEnabledByBootConfiguration: false,
            local: ["multichainEnabled": true]
        )

        XCTAssertEqual(configuration.resolvedFeatureFlags[.multichainEnabled], true)
    }

    func testImportMultichainIsOffWhenBothFlagsAreOff() throws {
        let configuration = try makeConfiguration(
            multichainEnabledByBootConfiguration: true,
            remote: [
                "ios_multichain_enabled": false,
                "ios_import_multichain_enabled": false,
            ]
        )

        XCTAssertFalse(configuration.featureEnabled(.importMultichainEnabled))
    }

    func testMultichainFlagsDefaultOnWithoutRemoteOrOverride() throws {
        let configuration = try makeConfiguration(multichainEnabledByBootConfiguration: true)

        XCTAssertTrue(configuration.featureEnabled(.multichainEnabled))
        XCTAssertTrue(configuration.featureEnabled(.importMultichainEnabled))
    }

    func testBootConfigurationMultichainFlagDefaultsOnWhenKeyIsAbsent() throws {
        let bootConfiguration = try JSONDecoder().decode(
            BootConfiguration.self,
            from: Data(#"{ "flags": {} }"#.utf8)
        )
        let configuration = makeConfiguration(mainnet: bootConfiguration)

        XCTAssertTrue(bootConfiguration.flags.multichainEnabled)
        XCTAssertTrue(BootConfiguration.empty.flags.multichainEnabled)
        XCTAssertFalse(configuration.isFeatureFlagDisabledByBootConfiguration(.multichainEnabled))
        XCTAssertTrue(configuration.featureEnabled(.multichainEnabled))
    }

    func testRemoteFalseStillDisablesMultichain() throws {
        let configuration = try makeConfiguration(
            multichainEnabledByBootConfiguration: true,
            remote: [
                "ios_multichain_enabled": false,
                "ios_import_multichain_enabled": false,
            ]
        )

        XCTAssertFalse(configuration.featureEnabled(.multichainEnabled))
        XCTAssertFalse(configuration.featureEnabled(.importMultichainEnabled))
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
        multichainEnabledByBootConfiguration: Bool,
        bundle: [String: Bool] = [:],
        local: [String: Bool] = [:],
        remote: [String: Bool] = [:]
    ) throws -> Configuration {
        let bootConfiguration = try JSONDecoder().decode(
            BootConfiguration.self,
            from: Data(
                """
                { "flags": { "multichain_enabled": \(multichainEnabledByBootConfiguration) } }
                """.utf8
            )
        )
        return makeConfiguration(mainnet: bootConfiguration, bundle: bundle, local: local, remote: remote)
    }

    func makeConfiguration(
        mainnet: BootConfiguration,
        bundle: [String: Bool] = [:],
        local: [String: Bool] = [:],
        remote: [String: Bool] = [:]
    ) -> Configuration {
        Configuration(
            bootConfigurationService: BootConfigurationServiceStub(
                bootConfigurations: BootConfigurations(
                    mainnet: mainnet,
                    testnet: .empty,
                    tetra: .empty
                )
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
    var isTetraWalletEnabled = false
    var isConfirmButtonInsteadSlider = false
    var lighterAPIEnvironment: LighterAPIEnvironment = .production
    var raffleIsNewUser: Bool?
    var pendingRaffleIsNewUser: Bool?
    var raffleDebugNow: Date?

    func beginRaffleUserResolution(isNewUser: Bool) {
        pendingRaffleIsNewUser = isNewUser
    }

    func cancelPendingRaffleUserResolution() {
        pendingRaffleIsNewUser = nil
    }

    func resolveRaffleIsNewUser(_ isNewUser: Bool) {
        raffleIsNewUser = raffleIsNewUser ?? isNewUser
        pendingRaffleIsNewUser = nil
    }
}
