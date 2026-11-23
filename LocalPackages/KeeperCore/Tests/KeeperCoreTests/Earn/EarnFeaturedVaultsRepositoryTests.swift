@testable import KeeperCore
import TKFeatureFlags
import XCTest

final class EarnFeaturedVaultsRepositoryTests: XCTestCase {
    func testAnswersEmptyWhileEarnIsOff() throws {
        let repository = try makeRepository(isEarnEnabled: false, bootConfigurationJSON: configuredJSON)

        let vaults = repository.featuredVaults()

        XCTAssertTrue(vaults.isEmpty)
    }

    func testServesTheConfiguredVaults() throws {
        let repository = try makeRepository(isEarnEnabled: true, bootConfigurationJSON: configuredJSON)

        let vaults = repository.featuredVaults()

        XCTAssertEqual(vaults, configuredVaults)
    }

    func testAnswersEmptyWithoutConfiguredVaults() throws {
        let repository = try makeRepository(isEarnEnabled: true, bootConfigurationJSON: "{}")

        let vaults = repository.featuredVaults()

        XCTAssertTrue(vaults.isEmpty)
    }
}

private extension EarnFeaturedVaultsRepositoryTests {
    var configuredJSON: String {
        """
        {
          "earn_featured_vaults": [
            { "network": "base", "vaultId": "0xc1256Ae5FF1cf2719D4937adb3bbCCab2E00A2Ca" },
            { "network": "mainnet", "vaultId": "0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c" }
          ]
        }
        """
    }

    var configuredVaults: [EarnFeaturedVault] {
        [
            EarnFeaturedVault(network: "base", vaultId: "0xc1256Ae5FF1cf2719D4937adb3bbCCab2E00A2Ca"),
            EarnFeaturedVault(network: "mainnet", vaultId: "0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c"),
        ].compactMap { $0 }
    }

    func makeRepository(
        isEarnEnabled: Bool,
        bootConfigurationJSON: String
    ) throws -> EarnFeaturedVaultsRepositoryImplementation {
        let mainnet = try JSONDecoder().decode(BootConfiguration.self, from: Data(bootConfigurationJSON.utf8))
        let configuration = Configuration(
            bootConfigurationService: BootConfigurationServiceStub(
                bootConfigurations: BootConfigurations(mainnet: mainnet, testnet: .empty)
            ),
            featureFlags: DummyFeatureFlags(),
            tkAppSettings: AppSettingsStub()
        )
        return EarnFeaturedVaultsRepositoryImplementation(
            isEarnEnabled: isEarnEnabled,
            configuration: configuration
        )
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
