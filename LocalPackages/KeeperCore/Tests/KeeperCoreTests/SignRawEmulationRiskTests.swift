import BigInt
@testable import KeeperCore
import XCTest

final class SignRawEmulationRiskTests: XCTestCase {
    private let tonRate = Rates.Rate(currency: .USD, rate: 2, diff24h: nil)

    func test_walletWithoutTon_countsOnlyTokens() throws {
        let total = try XCTUnwrap(risk(ton: 50_000_000, totalEquivalent: 0.12).totalEquivalent(limitingTonTo: 0, tonRate: tonRate))

        XCTAssertEqual(total, 0.02, accuracy: 0.000_001)
    }

    func test_walletWithPartOfAttachedTon_countsOnlyWhatItHolds() throws {
        let total = try XCTUnwrap(
            risk(ton: 50_000_000, totalEquivalent: 0.12).totalEquivalent(limitingTonTo: 20_000_000, tonRate: tonRate)
        )

        XCTAssertEqual(total, 0.06, accuracy: 0.000_001)
    }

    func test_walletCoveringAttachedTon_keepsFullTotal() throws {
        let total = try XCTUnwrap(
            risk(ton: 50_000_000, totalEquivalent: 0.12).totalEquivalent(limitingTonTo: 80_000_000, tonRate: tonRate)
        )

        XCTAssertEqual(total, 0.12, accuracy: 0.000_001)
    }

    func test_missingTotal_staysMissing() {
        XCTAssertNil(risk(ton: 50_000_000, totalEquivalent: nil).totalEquivalent(limitingTonTo: 0, tonRate: tonRate))
    }

    private func risk(ton: UInt64, totalEquivalent: Double?) -> SignRawEmulation.Risk {
        SignRawEmulation.Risk(
            ton: ton,
            jettons: [],
            nftsCount: 0,
            transferAllRemainingBalance: false,
            totalEquivalent: totalEquivalent
        )
    }
}
