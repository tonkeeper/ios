@testable import KeeperCore
import XCTest

final class HardcodedEarnVaultsRepositoryTests: XCTestCase {
    func testAnswersEmptyWhileEarnIsOff() async throws {
        let repository = HardcodedEarnVaultsRepository(isEarnEnabled: false)

        let vaults = try await repository.vaults(for: EarnHardcodedData.featuredVaults)

        XCTAssertTrue(vaults.isEmpty)
    }

    func testResolvesEveryHardcodedFeaturedVaultWhileEarnIsOn() async throws {
        let repository = HardcodedEarnVaultsRepository(isEarnEnabled: true)

        let vaults = try await repository.vaults(for: EarnHardcodedData.featuredVaults)

        XCTAssertEqual(vaults, EarnHardcodedData.vaults)
        XCTAssertFalse(vaults.isEmpty)
    }

    func testKeepsTheFeaturedOrderAndSkipsVaultsItDoesNotKnow() async throws {
        let repository = HardcodedEarnVaultsRepository(isEarnEnabled: true)
        let featuredVaults = try [
            XCTUnwrap(EarnFeaturedVault(network: "base", vaultId: "0xc1256ae5ff1cf2719d4937adb3bbccab2e00a2ca")),
            XCTUnwrap(EarnFeaturedVault(network: "mainnet", vaultId: "0x1111111111111111111111111111111111111111")),
            XCTUnwrap(EarnFeaturedVault(network: "arbitrum", vaultId: "0x23878914EFE38d27C4D67Ab83ed1b93A74D4086a")),
            XCTUnwrap(EarnFeaturedVault(network: "mainnet", vaultId: "0x23878914EFE38d27C4D67Ab83ed1b93A74D4086a")),
        ]

        let vaults = try await repository.vaults(for: featuredVaults)

        XCTAssertEqual(vaults.map(\.network), ["base", "mainnet"])
        XCTAssertEqual(vaults.map(\.protocolName), ["Moonwell", "Aave"])
        XCTAssertEqual(vaults.first?.vaultId, "0xc1256Ae5FF1cf2719D4937adb3bbCCab2E00A2Ca")
    }
}
