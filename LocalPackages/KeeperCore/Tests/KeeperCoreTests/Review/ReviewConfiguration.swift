import Foundation
@testable import KeeperCore
import TKFeatureFlags

/// The feature flags of the flows a gate reviews: the one that has a wallet's own send and a dApp's
/// request signed as chain-kit's operation for them.
final class ReviewFlags: TKFeatureFlags {
    var signsOperations: Bool

    init(signsOperations: Bool = false) {
        self.signsOperations = signsOperations
    }

    subscript(flag: FeatureFlag) -> Bool {
        get {
            switch flag {
            case .genericPayloadEnabled: signsOperations
            default: flag.defaultValue
            }
        }
        set {}
    }

    func devOverride(for _: FeatureFlag) -> Bool? {
        nil
    }

    func resetValue(for _: FeatureFlag) {}

    func loadRemoteConfig() async {}

    var allValues: [FeatureFlag: FeatureFlagValue] {
        [:]
    }
}

extension KeeperCore.Configuration {
    /// A configuration with `flags` whose stored boot configuration validates operations while
    /// `validates`, and the one `loadConfigurations()` then answers while `thenValidates`, the same by default.
    static func review(
        _ flags: ReviewFlags = ReviewFlags(),
        validates: Bool = true,
        thenValidates: Bool? = nil
    ) -> KeeperCore.Configuration {
        KeeperCore.Configuration(
            bootConfigurationService: ReviewBootConfiguration(validates: validates, thenValidates: thenValidates ?? validates),
            featureFlags: flags,
            tkAppSettings: ReviewAppSettings()
        )
    }
}

/// The boot configuration a launch stored and the one a load answers: empty but for
/// `tx_validation_enabled`.
private struct ReviewBootConfiguration: BootConfigurationService {
    let validates: Bool
    let thenValidates: Bool

    func getConfiguration() throws -> BootConfigurations {
        try Self.configurations(validating: validates)
    }

    func loadConfiguration() async throws -> BootConfigurations {
        try Self.configurations(validating: thenValidates)
    }

    static func configurations(validating: Bool) throws -> BootConfigurations {
        let flags = #"{"flags": {"tx_validation_enabled": \#(validating)}}"#
        let configuration = try JSONDecoder().decode(BootConfiguration.self, from: Data(flags.utf8))
        return BootConfigurations(mainnet: configuration, testnet: configuration)
    }
}

private final class ReviewAppSettings: TKAppSettings {
    var isConfirmButtonInsteadSlider = false
    var raffleIsNewUser: Bool?
}
