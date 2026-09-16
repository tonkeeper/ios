@testable import KeeperCore
import TronSwift
import XCTest

final class TronFeeOptionsAvailabilityTests: XCTestCase {
    func test_sponsorableTransfer_offersBatteryTonAndTrx() {
        let types = availableTypes(isTONBillingAvailable: true, requiresSelfPaidTRX: false)

        XCTAssertEqual(types.count, 3)
        XCTAssertTrue(types.contains(.battery))
        XCTAssertTrue(types.contains(.default))
        XCTAssertTrue(isTRXOption(types.last))
    }

    func test_withoutTonBilling_offersBatteryAndTrx() {
        let types = availableTypes(isTONBillingAvailable: false, requiresSelfPaidTRX: false)

        XCTAssertEqual(types.count, 2)
        XCTAssertTrue(types.contains(.battery))
        XCTAssertTrue(isTRXOption(types.last))
    }

    /// A TRX transfer, and any transfer that has to create the destination account, is paid for by
    /// the sender in TRX — quoting a sponsor for it would offer a fee nothing can settle.
    func test_selfPaidTransfer_offersTrxAlone() {
        let types = availableTypes(isTONBillingAvailable: true, requiresSelfPaidTRX: true)

        XCTAssertEqual(types.count, 1)
        XCTAssertTrue(isTRXOption(types.first))
    }

    func test_trxOnlyRegion_offersTrxAlone() {
        let types = TronUSDTFeeOptionsResolver.availableTypes(
            isTRXOnlyRegion: true,
            isTONBillingAvailable: true,
            requiresSelfPaidTRX: false
        )

        XCTAssertEqual(types.count, 1)
        XCTAssertTrue(isTRXOption(types.first))
    }
}

private extension TronFeeOptionsAvailabilityTests {
    func availableTypes(
        isTONBillingAvailable: Bool,
        requiresSelfPaidTRX: Bool
    ) -> [TransactionConfirmationModel.ExtraType] {
        TronUSDTFeeOptionsResolver.availableTypes(
            isTRXOnlyRegion: false,
            isTONBillingAvailable: isTONBillingAvailable,
            requiresSelfPaidTRX: requiresSelfPaidTRX
        )
    }

    func isTRXOption(_ type: TransactionConfirmationModel.ExtraType?) -> Bool {
        guard case let .gasless(token) = type else { return false }
        return token.symbol?.uppercased() == TRX.symbol.uppercased()
    }
}
