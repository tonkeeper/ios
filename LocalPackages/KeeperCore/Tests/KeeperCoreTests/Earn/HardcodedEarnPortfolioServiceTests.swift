@testable import KeeperCore
import XCTest

final class HardcodedEarnPortfolioServiceTests: XCTestCase {
    func testAnswersEmptyWhileEarnIsOff() async throws {
        let service = HardcodedEarnPortfolioService(isEarnEnabled: false)

        let positions = try await service.loadPositions(address: "0x1111111111111111111111111111111111111111")

        XCTAssertTrue(positions.isEmpty)
    }

    func testServesTheHardcodedPositionsForAnyAddressWhileEarnIsOn() async throws {
        let service = HardcodedEarnPortfolioService(isEarnEnabled: true)

        let positions = try await service.loadPositions(address: "0x1111111111111111111111111111111111111111")

        XCTAssertEqual(positions, EarnHardcodedData.positions)
        XCTAssertFalse(positions.isEmpty)
    }

    func testEveryPositionSitsInACarouselVault() {
        for position in EarnHardcodedData.positions {
            XCTAssertTrue(
                EarnHardcodedData.vaults.contains { $0.network == position.network && $0.vaultId == position.vaultId },
                "position in \(position.vaultId) has no matching vault"
            )
        }
    }
}
