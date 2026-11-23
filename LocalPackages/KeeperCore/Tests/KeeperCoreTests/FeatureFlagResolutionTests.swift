@testable import KeeperCore
import PerpsModels
import TKFeatureFlags
import XCTest

final class FeatureFlagResolutionTests: XCTestCase {
    /// Generic Payload defaults off and is turned on by its own key; the transfer, dApp and swap v3 keys it
    /// replaces are read no more.
    func testGenericPayloadDefaultsOffAndCanBeEnabledRemotely() {
        XCTAssertFalse(makeFeatureFlags()[.genericPayloadEnabled])
        XCTAssertTrue(makeFeatureFlags(remote: ["ios_generic_payload_enabled": true])[.genericPayloadEnabled])
        XCTAssertFalse(makeFeatureFlags(
            local: ["genericPayloadEnabled": false],
            remote: ["ios_generic_payload_enabled": true]
        )[.genericPayloadEnabled])
        XCTAssertFalse(makeFeatureFlags(
            remote: ["ios_operation_transfer_enabled": true, "ios_operation_dapp_enabled": true, "ios_is_swap_v3_enabled": true]
        )[.genericPayloadEnabled])
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

    func testBootConfigurationKeepsPerpsAndItsPromoOffOutsideItsRegion() throws {
        let configuration = try makeConfiguration(
            remote: ["ios_perps_enabled": true],
            mainnet: makeBootConfiguration(perpsState: "hidden")
        )

        XCTAssertFalse(configuration.featureEnabled(.perpsEnabled))
        XCTAssertTrue(configuration.isPromoHidden(id: "perps"))
        XCTAssertFalse(configuration.isPromoHidden(id: "earn"))
    }

    func testThePerpsAccessOverrideReplacesTheBootConfigurationState() throws {
        let configuration = try makeConfiguration(
            remote: ["ios_perps_enabled": true],
            mainnet: makeBootConfiguration(perpsState: "hidden"),
            perpsAccessOverride: .restricted
        )

        XCTAssertEqual(configuration.perpsAccess, .restricted)
        XCTAssertTrue(configuration.featureEnabled(.perpsEnabled))
    }

    func testPerpsNeedsBothTheRemoteFlagAndTheBootConfiguration() throws {
        let open = try makeConfiguration(
            remote: ["ios_perps_enabled": true],
            mainnet: makeBootConfiguration(perpsState: "available")
        )
        let restricted = try makeConfiguration(
            remote: ["ios_perps_enabled": true],
            mainnet: makeBootConfiguration(perpsState: "restricted")
        )
        let notRolledOut = try makeConfiguration(mainnet: makeBootConfiguration(perpsState: "available"))
        let silentBootConfiguration = try makeConfiguration(
            remote: ["ios_perps_enabled": true],
            mainnet: makeBootConfiguration(perpsState: nil)
        )
        let bootConfigurationNotLoaded = makeConfiguration(remote: ["ios_perps_enabled": true])

        XCTAssertTrue(open.featureEnabled(.perpsEnabled))
        XCTAssertFalse(open.isPromoHidden(id: "perps"))
        XCTAssertTrue(restricted.featureEnabled(.perpsEnabled))
        XCTAssertFalse(restricted.isPromoHidden(id: "perps"))
        XCTAssertFalse(notRolledOut.featureEnabled(.perpsEnabled))
        XCTAssertTrue(notRolledOut.isPromoHidden(id: "perps"))
        XCTAssertFalse(silentBootConfiguration.featureEnabled(.perpsEnabled))
        XCTAssertFalse(bootConfigurationNotLoaded.featureEnabled(.perpsEnabled))
    }

    func testDevOverrideOpensPerpsOutsideItsRegion() throws {
        let configuration = try makeConfiguration(
            local: ["perpsEnabled": true],
            mainnet: makeBootConfiguration(perpsState: "hidden")
        )

        XCTAssertTrue(configuration.featureEnabled(.perpsEnabled))
    }

    func testPerpsRealtimeFollowsItsOwnFlagOnlyOnTopOfPerps() throws {
        let perpsRegion = "available"
        let on = try makeConfiguration(
            remote: ["ios_perps_enabled": true, "ios_perps_realtime_enabled": true],
            mainnet: makeBootConfiguration(perpsState: perpsRegion)
        )
        let perpsOnly = try makeConfiguration(
            remote: ["ios_perps_enabled": true, "ios_perps_realtime_enabled": false],
            mainnet: makeBootConfiguration(perpsState: perpsRegion)
        )
        let withoutPerps = try makeConfiguration(
            remote: ["ios_perps_realtime_enabled": true],
            mainnet: makeBootConfiguration(perpsState: perpsRegion)
        )
        let byDefault = try makeConfiguration(
            remote: ["ios_perps_enabled": true],
            mainnet: makeBootConfiguration(perpsState: perpsRegion)
        )

        XCTAssertTrue(on.featureEnabled(.perpsRealtimeEnabled))
        XCTAssertFalse(perpsOnly.featureEnabled(.perpsRealtimeEnabled))
        XCTAssertFalse(withoutPerps.featureEnabled(.perpsRealtimeEnabled))
        #if DEBUG
            XCTAssertTrue(byDefault.featureEnabled(.perpsRealtimeEnabled))
        #else
            XCTAssertFalse(byDefault.featureEnabled(.perpsRealtimeEnabled))
        #endif
    }

    func testLedgerMigrationStaysOffWithoutTheMultichainLedger() {
        let featureFlags = makeFeatureFlags(
            local: ["ledgerMigration": true],
            remote: ["ios_ledger_migration_enabled": true]
        )
        let configuration = makeConfiguration(local: ["ledgerMigration": true])

        XCTAssertFalse(featureFlags[.ledgerMigration])
        XCTAssertEqual(featureFlags.allValues[.ledgerMigration]?.resolvedValue, false)
        XCTAssertFalse(configuration.featureEnabled(.ledgerMigration))
    }

    func testLedgerMigrationFollowsItsOwnValueOnTopOfTheMultichainLedger() {
        let featureFlags = makeFeatureFlags(
            local: ["ledgerMigration": true],
            remote: ["ios_is_ledger_multichain_enabled": true]
        )
        let configuration = makeConfiguration(remote: ["ios_is_ledger_multichain_enabled": true])

        XCTAssertTrue(featureFlags[.ledgerMigration])
        XCTAssertFalse(configuration.featureEnabled(.ledgerMigration))
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
    func makeBootConfiguration(perpsState: String?) throws -> BootConfiguration {
        let json = perpsState.map { #"{"feature_access": {"perps": {"state": "\#($0)"}}}"# } ?? "{}"
        return try JSONDecoder().decode(BootConfiguration.self, from: Data(json.utf8))
    }

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
        remote: [String: Bool] = [:],
        mainnet: BootConfiguration = .empty,
        perpsAccessOverride: PerpsAccess? = nil
    ) -> Configuration {
        Configuration(
            bootConfigurationService: BootConfigurationServiceStub(
                bootConfigurations: BootConfigurations(mainnet: mainnet, testnet: .empty)
            ),
            featureFlags: makeFeatureFlags(bundle: bundle, local: local, remote: remote),
            tkAppSettings: AppSettingsStub(),
            perpsAccessOverride: perpsAccessOverride
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
