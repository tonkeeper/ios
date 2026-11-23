@testable import KeeperCore
import TonSwift
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

    func test_aLedger_isNotOfferedTheTonFee() {
        let estimate = TronTransferFeeEstimate(
            energy: 64000,
            bandwidth: 345,
            requiredBatteryCharges: 40,
            requiredTRXSun: 13_000_000,
            destinationActivationSun: 0,
            requiredTONAmountNano: 1_500_000_000,
            tonFeeAddress: "UQBattery"
        )
        let ledger = wallet(kind: .Ledger(
            TonSwift.PublicKey(data: Data(repeating: 1, count: 32)),
            .v4R2,
            Wallet.LedgerDevice(deviceId: UUID().uuidString, deviceModel: "Flex", accountIndex: 0)
        ))
        let regular = wallet(kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2))

        XCTAssertFalse(TronUSDTFeeOptionsResolver.isTONBillingAvailable(estimate: estimate, wallet: ledger))
        XCTAssertTrue(TronUSDTFeeOptionsResolver.isTONBillingAvailable(estimate: estimate, wallet: regular))
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
    func wallet(kind: WalletKind) -> Wallet {
        Wallet(
            id: "wallet-id",
            identity: .init(network: .mainnet, kind: kind),
            metaData: .init(label: "Test wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: .init(isSetupFinished: true),
            batterySettings: .init()
        )
    }

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
