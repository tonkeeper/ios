@testable import KeeperCore
import TKFeatureFlags
import XCTest

final class ConfigurationEarnHostTests: XCTestCase {
    func testConfiguredHostIsUsedAsIs() throws {
        let configuration = try makeConfiguration(bootConfigurationJSON: #"{"earn_url": "https://earn.example.com"}"#)

        XCTAssertEqual(configuration.earnUrl.absoluteString, "https://earn.example.com")
    }

    func testMissingHostFallsBackToTheDemoStand() throws {
        let configuration = try makeConfiguration(bootConfigurationJSON: "{}")

        XCTAssertEqual(configuration.earnUrl, EarnHardcodedData.url)
    }
}

private extension ConfigurationEarnHostTests {
    func makeConfiguration(bootConfigurationJSON: String) throws -> Configuration {
        let mainnet = try JSONDecoder().decode(BootConfiguration.self, from: Data(bootConfigurationJSON.utf8))
        return Configuration(
            bootConfigurationService: BootConfigurationServiceStub(
                bootConfigurations: BootConfigurations(mainnet: mainnet, testnet: .empty)
            ),
            featureFlags: DummyFeatureFlags(),
            tkAppSettings: AppSettingsStub()
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
