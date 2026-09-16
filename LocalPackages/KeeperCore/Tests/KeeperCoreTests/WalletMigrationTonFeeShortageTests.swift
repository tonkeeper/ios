import BigInt
@testable import KeeperCore
import TonSwift
import XCTest

final class WalletMigrationTonFeeShortageTests: XCTestCase {
    func test_serverRequiredTonOverridesLowerEmulatedFees() {
        let result = WalletMigrationPrepareResult(
            from: "from",
            to: "to",
            walletVersion: "v5R1",
            transactions: [makePreparedTransaction(seqno: 1, sponsored: false, fee: 100_000)],
            availableFeeMethods: [.ton(amountNano: 250_000)],
            availableTonNano: 10000,
            requiredTonNano: 250_000
        )

        XCTAssertEqual(result.totalFees, 100_000)
        XCTAssertEqual(result.requiredTonNano, 250_000)
        XCTAssertTrue(result.isSelfPaidTonInsufficient)
    }

    func test_preferredFeeMethod_prefersBatteryEvenWhenTonBalanceCovers() {
        let methods: [WalletMigrationPrepareResult.FeeMethod] = [
            .ton(amountNano: 150_000),
            .battery(charges: 12),
        ]
        let preferred = WalletMigrationTonFeeOptionsResolver.preferred(methods: methods)
        guard case let .battery(charges) = preferred else {
            return XCTFail("Expected battery fee method")
        }
        XCTAssertEqual(charges, 12)
    }

    func test_preferredFeeMethod_fallsBackToTonWhenBatteryUnavailable() {
        let methods: [WalletMigrationPrepareResult.FeeMethod] = [
            .ton(amountNano: 150_000),
        ]
        let preferred = WalletMigrationTonFeeOptionsResolver.preferred(methods: methods)
        guard case let .ton(amount) = preferred else {
            return XCTFail("Expected TON fee method")
        }
        XCTAssertEqual(amount, 150_000)
    }

    func test_transactionsForExecution_usesBatteryTransactionsWhenPayingWithBattery() {
        let selfTx = makePreparedTransaction(seqno: 1, sponsored: false, fee: 150_000)
        let batterySponsored = makePreparedTransaction(seqno: 2, sponsored: true, fee: 80000)
        let batterySweep = makePreparedTransaction(seqno: 3, sponsored: false, fee: 20000)
        let result = WalletMigrationPrepareResult(
            from: "from",
            to: "to",
            walletVersion: "v5R1",
            transactions: [selfTx],
            batteryTransactions: [batterySponsored, batterySweep],
            availableFeeMethods: [
                .ton(amountNano: 150_000),
                .battery(charges: 8),
            ],
            availableTonNano: 0
        )

        let tonPath = result.transactionsForExecution(feeMethod: .ton(amountNano: 150_000))
        XCTAssertEqual(tonPath.map(\.seqno), [1])
        XCTAssertFalse(tonPath[0].sponsored)

        let batteryPath = result.transactionsForExecution(feeMethod: .battery(charges: 8))
        XCTAssertEqual(batteryPath.map(\.seqno), [2, 3])
        XCTAssertTrue(batteryPath[0].sponsored)
        XCTAssertFalse(batteryPath[1].sponsored)
    }

    func test_transactionsForExecution_batteryWithoutPrepareIsEmpty() {
        let selfTx = makePreparedTransaction(seqno: 1, sponsored: false, fee: 150_000)
        let result = WalletMigrationPrepareResult(
            from: "from",
            to: "to",
            walletVersion: "v5R1",
            transactions: [selfTx],
            batteryTransactions: nil,
            availableFeeMethods: [.ton(amountNano: 150_000)],
            availableTonNano: 150_000
        )
        XCTAssertTrue(
            result.transactionsForExecution(feeMethod: .battery(charges: 8)).isEmpty
        )
    }

    func test_batteryPlanRemainsExecutableWhenSelfPaidPlanIsEmpty() {
        let batteryTransaction = makePreparedTransaction(seqno: 1, sponsored: true, fee: 80000)
        let result = WalletMigrationPrepareResult(
            from: "from",
            to: "to",
            walletVersion: "v5R1",
            transactions: [],
            batteryTransactions: [batteryTransaction],
            availableFeeMethods: [.battery(charges: 8)],
            availableTonNano: 0,
            requiredTonNano: 150_000
        )

        XCTAssertTrue(result.hasExecutableTransactions)
        XCTAssertEqual(result.transactionsForDisplay.map(\.seqno), [1])
    }

    func test_blockingTONShortage_blocksWhenBatteryQuoteExistsButChargesCannotPay() {
        let result = makeInsufficientTonResultWithBatteryQuote()

        let shortage = result.blockingTONShortage { method in
            WalletMigrationFeeSelectionResolver.isTonMethodPayable(
                method,
                ton: result,
                availableBatteryCharges: 0
            )
        }

        XCTAssertEqual(shortage?.required, 250_000)
        XCTAssertEqual(shortage?.available, 10000)
    }

    func test_blockingTONShortage_clearsWhenBatteryChargesCoverTheQuote() {
        let result = makeInsufficientTonResultWithBatteryQuote()

        XCTAssertNil(
            result.blockingTONShortage { method in
                WalletMigrationFeeSelectionResolver.isTonMethodPayable(
                    method,
                    ton: result,
                    availableBatteryCharges: 6
                )
            }
        )
    }

    func test_blockingTONShortage_blocksWhenBatteryBalanceIsUnknown() {
        let result = makeInsufficientTonResultWithBatteryQuote()

        let shortage = result.blockingTONShortage { method in
            WalletMigrationFeeSelectionResolver.isTonMethodPayable(
                method,
                ton: result,
                availableBatteryCharges: nil
            )
        }

        XCTAssertEqual(shortage?.required, 250_000)
        XCTAssertEqual(shortage?.available, 10000)
    }

    func test_blockingTONShortage_claimsSelfPaidQuoteAboveBalanceWhenServerIsSilent() {
        let result = WalletMigrationPrepareResult(
            from: "from",
            to: "to",
            walletVersion: "v5R1",
            transactions: [makePreparedTransaction(seqno: 1, sponsored: false, fee: 150_000)],
            availableFeeMethods: [.ton(amountNano: 150_000)],
            availableTonNano: 100_000
        )

        let shortage = result.blockingTONShortage { method in
            WalletMigrationFeeSelectionResolver.isTonMethodPayable(
                method,
                ton: result,
                availableBatteryCharges: nil
            )
        }

        XCTAssertEqual(shortage?.required, 150_000)
        XCTAssertEqual(shortage?.available, 100_000)
    }

    func test_blockingTONShortage_blocksWithoutBatteryAlternative() {
        let result = WalletMigrationPrepareResult(
            from: "from",
            to: "to",
            walletVersion: "v5R1",
            transactions: [],
            availableFeeMethods: [.ton(amountNano: 250_000)],
            availableTonNano: 10000,
            requiredTonNano: 250_000
        )

        let shortage = result.blockingTONShortage { method in
            WalletMigrationFeeSelectionResolver.isTonMethodPayable(
                method,
                ton: result,
                availableBatteryCharges: nil
            )
        }

        XCTAssertEqual(shortage?.required, 250_000)
        XCTAssertEqual(shortage?.available, 10000)
    }

    func test_blockingTONShortage_isNilWithoutReportedShortage() {
        let result = WalletMigrationPrepareResult(
            from: "from",
            to: "to",
            walletVersion: "v5R1",
            transactions: [makePreparedTransaction(seqno: 1, sponsored: false, fee: 100_000)],
            availableFeeMethods: [.ton(amountNano: 100_000)],
            availableTonNano: 1_000_000
        )

        XCTAssertNil(result.blockingTONShortage { _ in false })
    }

    private func makeInsufficientTonResultWithBatteryQuote() -> WalletMigrationPrepareResult {
        WalletMigrationPrepareResult(
            from: "from",
            to: "to",
            walletVersion: "v5R1",
            transactions: [],
            batteryTransactions: [makePreparedTransaction(seqno: 1, sponsored: true, fee: 80000)],
            availableFeeMethods: [
                .ton(amountNano: 250_000),
                .battery(charges: 6),
            ],
            availableTonNano: 10000,
            requiredTonNano: 250_000
        )
    }

    func test_batteryChargeBasisNano_prefersBurnedFeesOverEventExtra() {
        let sponsored = makePreparedTransaction(
            seqno: 1,
            sponsored: true,
            totalFees: 80000,
            eventExtra: .Fee(5_000_000)
        )
        let sweep = makePreparedTransaction(
            seqno: 2,
            sponsored: false,
            totalFees: 40000,
            eventExtra: .Fee(5_000_000)
        )
        XCTAssertEqual(
            WalletMigrationPrepareResult.batteryChargeBasisNano(
                from: [sponsored, sweep]
            ),
            80000
        )
        XCTAssertNil(
            WalletMigrationPrepareResult.batteryChargeBasisNano(
                from: [sweep]
            )
        )
    }

    func test_batteryChargeBasis_usesSponsoredFeesWhenPresent() {
        XCTAssertEqual(
            WalletMigrationTonFeeOptionsResolver.batteryChargeBasis(
                selfTotalFees: 100_000,
                batteryTotalFees: 50000,
                hasSponsoredBatteryPath: false,
                allowBatteryQuoteWithoutSponsoredPath: false
            ),
            50000
        )
    }

    func test_batteryChargeBasis_legacyStubUsesSelfPaidFeesWithoutSponsoredPath() {
        XCTAssertEqual(
            WalletMigrationTonFeeOptionsResolver.batteryChargeBasis(
                selfTotalFees: 100_000,
                batteryTotalFees: nil,
                hasSponsoredBatteryPath: false,
                allowBatteryQuoteWithoutSponsoredPath: true
            ),
            100_000
        )
    }

    func test_batteryChargeBasis_v5WithoutSponsoredPathOffersNoBatteryQuote() {
        XCTAssertNil(
            WalletMigrationTonFeeOptionsResolver.batteryChargeBasis(
                selfTotalFees: 100_000,
                batteryTotalFees: nil,
                hasSponsoredBatteryPath: false,
                allowBatteryQuoteWithoutSponsoredPath: false
            )
        )
    }

    func test_batteryChargeBasis_sponsoredPathWithoutFeesDoesNotFallBackToSelfPaid() {
        XCTAssertNil(
            WalletMigrationTonFeeOptionsResolver.batteryChargeBasis(
                selfTotalFees: 100_000,
                batteryTotalFees: nil,
                hasSponsoredBatteryPath: true,
                allowBatteryQuoteWithoutSponsoredPath: true
            )
        )
    }

    private func makePreparedTransaction(
        seqno: Int,
        sponsored: Bool,
        fee: UInt64 = 1000
    ) -> WalletMigrationPreparedTransaction {
        makePreparedTransaction(
            seqno: seqno,
            sponsored: sponsored,
            totalFees: fee,
            eventExtra: .Fee(fee)
        )
    }

    private func makePreparedTransaction(
        seqno: Int,
        sponsored: Bool,
        totalFees: UInt64,
        eventExtra: AccountEvent.Extra
    ) -> WalletMigrationPreparedTransaction {
        let address = try! Address.parse("EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c")
        return WalletMigrationPreparedTransaction(
            seqno: seqno,
            boc: "te6cckEBAQEAAgAAAA==",
            event: AccountEvent(
                eventId: "\(seqno)",
                date: Date(timeIntervalSince1970: 0),
                account: WalletAccount(address: address, name: nil, isScam: false, isWallet: true),
                isScam: false,
                isInProgress: false,
                extra: eventExtra,
                excess: nil,
                progress: nil,
                actions: []
            ),
            totalFees: totalFees,
            totalEquivalent: nil,
            sponsored: sponsored
        )
    }
}
