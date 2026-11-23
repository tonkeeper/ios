import ChainKit
@testable import KeeperCore
import TKFeatureFlags
import XCTest

/// chain-kit's validation runs unless the mainnet boot configuration's `tx_validation_enabled` turns
/// it off, as on Android.
final class OperationGateConfigurationTests: XCTestCase {
    private let client = CryptoKitClient(netModule: ModuleNetModule(netConfig: ModuleNetConfig(
        isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil
    )))

    func test_aGateValidatesUnlessTheBootConfigurationTurnsValidationOff() {
        let validating = OperationGate(configuration: .review(validates: true), validatingWith: client)
        let unvalidated = OperationGate(configuration: .review(validates: false), validatingWith: client)

        XCTAssertTrue(validating.checks().contains { $0 is ChainKitValidationCheck })
        XCTAssertFalse(unvalidated.checks().contains { $0 is ChainKitValidationCheck })
    }

    /// The first launch has no stored configuration yet: validation is on until one turns it off.
    func test_aGateValidatesBeforeAnyBootConfigurationArrives() {
        let configuration = KeeperCore.Configuration(
            bootConfigurationService: NoBootConfiguration(),
            featureFlags: ReviewFlags(),
            tkAppSettings: AppSettingsStub()
        )

        XCTAssertTrue(OperationGate(configuration: configuration, validatingWith: client).checks().contains { $0 is ChainKitValidationCheck })
    }

    /// The configuration that turns validation off loads after the gate was built: the next review
    /// checks nothing.
    func test_aBootConfigurationLoadedLaterTurnsValidationOffAtTheNextReview() async {
        let configuration = KeeperCore.Configuration.review(thenValidates: false)
        let gate = OperationGate(configuration: configuration, validatingWith: client)
        XCTAssertTrue(gate.checks().contains { $0 is ChainKitValidationCheck })

        _ = await configuration.loadConfigurations()

        XCTAssertFalse(gate.checks().contains { $0 is ChainKitValidationCheck })
    }
}

/// A launch with no boot configuration stored and none loaded.
private struct NoBootConfiguration: BootConfigurationService {
    struct Unavailable: Error {}

    func getConfiguration() throws -> BootConfigurations {
        throw Unavailable()
    }

    func loadConfiguration() async throws -> BootConfigurations {
        throw Unavailable()
    }
}

private final class AppSettingsStub: TKAppSettings {
    var isConfirmButtonInsteadSlider = false
    var raffleIsNewUser: Bool?
}
