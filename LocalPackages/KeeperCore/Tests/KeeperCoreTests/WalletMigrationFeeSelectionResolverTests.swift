import BigInt
@testable import KeeperCore
import TonSwift
import XCTest

final class WalletMigrationFeeSelectionResolverTests: XCTestCase {
    func test_preferred_usesBatteryForBothRowsWhenSharedBalanceCoversSum() {
        let ton = makeTonResult(availableTon: 0)
        let tron = makeTronResult(availableTRX: 100)

        let selection = WalletMigrationFeeSelectionResolver.preferred(
            ton: ton,
            tron: tron,
            availableBatteryCharges: 13
        )

        XCTAssertEqual(selection.ton, .battery(charges: 6))
        XCTAssertEqual(selection.tron, .battery(charges: 7))
    }

    func test_preferred_prefersBatteryOverAffordableTonWhenChargesCoverBothRows() {
        let ton = makeTonResult(availableTon: 1000)
        let tron = makeTronResult(availableTRX: 100)

        let selection = WalletMigrationFeeSelectionResolver.preferred(
            ton: ton,
            tron: tron,
            availableBatteryCharges: 13
        )

        XCTAssertEqual(selection.ton, .battery(charges: 6))
        XCTAssertEqual(selection.tron, .battery(charges: 7))
    }

    func test_preferred_keepsSelfPaidTokensWhenBatteryBalanceIsUnknown() {
        let ton = makeTonResult(availableTon: 1000)
        let tron = makeTronResult(availableTRX: 100)

        let selection = WalletMigrationFeeSelectionResolver.preferred(
            ton: ton,
            tron: tron,
            availableBatteryCharges: nil
        )

        XCTAssertEqual(selection.ton, .ton(amountNano: 100))
        XCTAssertEqual(selection.tron, .trx(amountSun: 50))
    }

    func test_preferred_fallsBackToNativeTokensWhenBatteryIsEmpty() {
        let ton = makeTonResult(availableTon: 1000)
        let tron = makeTronResult(availableTRX: 100)

        let selection = WalletMigrationFeeSelectionResolver.preferred(
            ton: ton,
            tron: tron,
            availableBatteryCharges: 0
        )

        XCTAssertEqual(selection.ton, .ton(amountNano: 100))
        XCTAssertEqual(selection.tron, .trx(amountSun: 50))
    }

    func test_preferred_usesTrxWhenSharedBatteryBalanceDoesNotCoverBothRows() {
        let ton = makeTonResult(availableTon: 0)
        let tron = makeTronResult(availableTRX: 100)

        let selection = WalletMigrationFeeSelectionResolver.preferred(
            ton: ton,
            tron: tron,
            availableBatteryCharges: 12
        )

        XCTAssertEqual(selection.ton, .battery(charges: 6))
        XCTAssertEqual(selection.tron, .trx(amountSun: 50))
    }

    func test_preferred_fallbackKeepsPayableTrxWhenTonLegCannotPay() {
        let ton = makeTonResult(availableTon: 0)
        let tron = makeTronResult(availableTRX: 100)

        let selection = WalletMigrationFeeSelectionResolver.preferred(
            ton: ton,
            tron: tron,
            availableBatteryCharges: 3
        )

        XCTAssertEqual(selection.ton, .ton(amountNano: 100))
        XCTAssertEqual(selection.tron, .trx(amountSun: 50))
    }

    func test_preferred_fallbackPrefersPayableTrxOverUnknownBattery() {
        let ton = makeTonResult(availableTon: 0)
        let tron = makeTronResult(availableTRX: 100)

        let selection = WalletMigrationFeeSelectionResolver.preferred(
            ton: ton,
            tron: tron,
            availableBatteryCharges: nil
        )

        XCTAssertEqual(selection.ton, .ton(amountNano: 100))
        XCTAssertEqual(selection.tron, .trx(amountSun: 50))
    }

    func test_preferred_fallsBackToTonAndBatteryWhenNoPayableAlternativeExists() {
        let ton = makeTonResult(availableTon: 0)
        let tron = makeTronResult(availableTRX: 49)

        let selection = WalletMigrationFeeSelectionResolver.preferred(
            ton: ton,
            tron: tron,
            availableBatteryCharges: 12
        )

        XCTAssertEqual(selection.ton, .ton(amountNano: 100))
        XCTAssertEqual(selection.tron, .battery(charges: 7))
        XCTAssertTrue(
            WalletMigrationFeeSelectionResolver.isInsufficient(
                selection: selection,
                ton: ton,
                tron: tron,
                availableBatteryCharges: 12
            )
        )
    }

    func test_tronBatteryIsNotPayableWhenNoCompleteFeeSelectionCanAffordIt() {
        let ton = makeTonResult(availableTon: 0)
        let tron = makeTronResult(availableTRX: 49)

        XCTAssertFalse(
            WalletMigrationFeeSelectionResolver.isTronMethodPayable(
                .battery(charges: 7),
                ton: ton,
                tron: tron,
                availableBatteryCharges: 12
            )
        )
        XCTAssertTrue(
            WalletMigrationFeeSelectionResolver.isTronMethodPayable(
                .battery(charges: 7),
                ton: ton,
                tron: tron,
                availableBatteryCharges: 13
            )
        )
    }

    func test_tonBatteryIsNotPayableWhenChargesCannotCoverEvenStandalone() {
        let ton = makeTonResult(availableTon: 0)

        XCTAssertFalse(
            WalletMigrationFeeSelectionResolver.isTonMethodPayable(
                .battery(charges: 6),
                ton: ton,
                availableBatteryCharges: 5
            )
        )
        XCTAssertTrue(
            WalletMigrationFeeSelectionResolver.isTonMethodPayable(
                .battery(charges: 6),
                ton: ton,
                availableBatteryCharges: 6
            )
        )
    }

    func test_tonBatteryStaysPayableStandaloneWhenTronLegCannotJoin() {
        let ton = makeTonResult(availableTon: 0)
        let tron = makeTronResult(availableTRX: 49)

        XCTAssertTrue(
            WalletMigrationFeeSelectionResolver.isTonMethodPayable(
                .battery(charges: 6),
                ton: ton,
                availableBatteryCharges: 12
            )
        )
        XCTAssertFalse(
            WalletMigrationFeeSelectionResolver.isTronMethodPayable(
                .battery(charges: 7),
                ton: ton,
                tron: tron,
                availableBatteryCharges: 12
            )
        )
    }

    func test_blockedTonLegDoesNotFabricateTronShortage() {
        let ton = WalletMigrationPrepareResult(
            from: "from",
            to: "to",
            walletVersion: "v5R1",
            transactions: [],
            availableFeeMethods: [
                .ton(amountNano: 100),
                .battery(charges: 9),
            ],
            availableTonNano: 0
        )
        let tron = makeTronResult(availableTRX: 49)

        XCTAssertTrue(
            WalletMigrationFeeSelectionResolver.isTronMethodPayable(
                .battery(charges: 7),
                ton: ton,
                tron: tron,
                availableBatteryCharges: 7
            )
        )
        XCTAssertFalse(
            WalletMigrationFeeSelectionResolver.isTronMethodPayable(
                .battery(charges: 7),
                ton: ton,
                tron: tron,
                availableBatteryCharges: 6
            )
        )
    }

    func test_batteryCandidateIncludesChargesFromOtherSelectedRow() {
        let ton = makeTonResult(availableTon: 0)

        XCTAssertTrue(
            WalletMigrationFeeSelectionResolver.isTonMethodInsufficient(
                .battery(charges: 6),
                ton: ton,
                tronMethod: .battery(charges: 7),
                availableBatteryCharges: 12
            )
        )
        XCTAssertFalse(
            WalletMigrationFeeSelectionResolver.isTonMethodInsufficient(
                .battery(charges: 6),
                ton: ton,
                tronMethod: .trx(amountSun: 50),
                availableBatteryCharges: 12
            )
        )
    }

    func test_unknownBatteryBalanceMarksBatteryMethodsInsufficient() {
        let ton = makeTonResult(availableTon: 0)
        let tron = makeTronResult(availableTRX: 49)

        XCTAssertTrue(
            WalletMigrationFeeSelectionResolver.isTonMethodInsufficient(
                .battery(charges: 6),
                ton: ton,
                tronMethod: .battery(charges: 7),
                availableBatteryCharges: nil
            )
        )
        XCTAssertTrue(
            WalletMigrationFeeSelectionResolver.isTronMethodInsufficient(
                .battery(charges: 7),
                tron: tron,
                tonMethod: .battery(charges: 6),
                availableBatteryCharges: nil
            )
        )
    }

    func test_serverTonShortageKeepsSelfPaidMethodInsufficientWhenBalanceIsUnavailable() {
        let ton = WalletMigrationPrepareResult(
            from: "from",
            to: "to",
            walletVersion: "v5R1",
            transactions: [],
            availableFeeMethods: [.ton(amountNano: 100)],
            availableTonNano: nil,
            requiredTonNano: 100
        )

        XCTAssertTrue(
            WalletMigrationFeeSelectionResolver.isTonMethodInsufficient(
                .ton(amountNano: 100),
                ton: ton,
                tronMethod: nil,
                availableBatteryCharges: nil
            )
        )
        XCTAssertTrue(
            WalletMigrationFeeSelectionResolver.isTonMethodInsufficient(
                nil,
                ton: ton,
                tronMethod: nil,
                availableBatteryCharges: nil
            )
        )
    }

    func test_preferred_keepsTonAndBatteryWhenNativeTonAndBatteryBalancesCover() {
        let ton = makeTonResult(availableTon: 100)
        let tron = makeTronResult(availableTRX: 0)

        let selection = WalletMigrationFeeSelectionResolver.preferred(
            ton: ton,
            tron: tron,
            availableBatteryCharges: 7
        )

        XCTAssertEqual(selection.ton, .ton(amountNano: 100))
        XCTAssertEqual(selection.tron, .battery(charges: 7))
    }

    func test_inactiveTronSelectionKeepsInsufficientTrxMethod() {
        let tron = WalletMigrationTronPrepareResult(
            sourceAddress: "source",
            destinationAddress: "destination",
            usdtAmount: 1,
            requiredTRXSun: 50,
            availableTRXSun: 0,
            energy: 1,
            bandwidth: 1,
            availableFeeMethods: [.trx(amountSun: 50)]
        )

        let selection = WalletMigrationFeeSelectionResolver.preferred(
            ton: nil,
            tron: tron,
            availableBatteryCharges: 100
        )

        XCTAssertEqual(selection.tron, .trx(amountSun: 50))
        XCTAssertTrue(
            WalletMigrationFeeSelectionResolver.isInsufficient(
                selection: selection,
                ton: nil,
                tron: tron,
                availableBatteryCharges: 100
            )
        )
    }

    func test_batteryWithUsdtAndDustTrxHasNoShortage() {
        let tron = WalletMigrationTronPrepareResult(
            sourceAddress: "source",
            destinationAddress: "destination",
            usdtAmount: 1_000_000,
            requiredTRXSun: 27_345_000,
            availableTRXSun: 100_000,
            usdtRequiredTRXSun: 27_000_000,
            nativeRequiredTRXSun: 345_000,
            energy: 65000,
            bandwidth: 345,
            availableFeeMethods: [.battery(charges: 7), .trx(amountSun: 27_345_000)]
        )

        XCTAssertNil(
            WalletMigrationFeeSelectionResolver.tronShortage(
                .battery(charges: 7),
                tron: tron,
                tonMethod: nil,
                availableBatteryCharges: 7
            )
        )
        XCTAssertEqual(
            WalletMigrationFeeSelectionResolver.preferred(
                ton: nil,
                tron: tron,
                availableBatteryCharges: 7
            ).tron,
            .battery(charges: 7)
        )
    }

    func test_tonBatteryIsNotPayableWithoutExecutionPath() {
        let ton = makeShortageTonResult(
            methods: [.ton(amountNano: 100), .battery(charges: 6)],
            requiredTon: 2_968_600_000,
            availableTon: 1_000_000_000,
            includesBatteryExecutionPath: false
        )

        XCTAssertFalse(
            WalletMigrationFeeSelectionResolver.isTonMethodPayable(
                .battery(charges: 6),
                ton: ton,
                availableBatteryCharges: 10
            )
        )
        XCTAssertTrue(
            WalletMigrationFeeSelectionResolver.isTonMethodInsufficient(
                .battery(charges: 6),
                ton: ton,
                tronMethod: nil,
                availableBatteryCharges: 10
            )
        )
    }

    func test_hasPayableTonMethod_falseWhenServerShortageOffersOnlySelfPaidTon() {
        let ton = makeShortageTonResult(
            methods: [.ton(amountNano: 100)],
            requiredTon: 2_968_600_000,
            availableTon: 1_000_000_000
        )

        XCTAssertFalse(
            WalletMigrationFeeSelectionResolver.hasPayableTonMethod(
                ton: ton,
                availableBatteryCharges: nil
            )
        )
    }

    func test_hasPayableTonMethod_trueWhenBatteryCoversDespiteServerShortage() {
        let ton = makeShortageTonResult(
            methods: [.ton(amountNano: 100), .battery(charges: 6)],
            requiredTon: 2_968_600_000,
            availableTon: 1_000_000_000
        )

        XCTAssertTrue(
            WalletMigrationFeeSelectionResolver.hasPayableTonMethod(
                ton: ton,
                availableBatteryCharges: 6
            )
        )
        XCTAssertFalse(
            WalletMigrationFeeSelectionResolver.hasPayableTonMethod(
                ton: ton,
                availableBatteryCharges: 5
            )
        )
    }

    func test_hasPayableTonMethod_unknownBatteryBalanceDoesNotCountAsPayable() {
        let ton = makeShortageTonResult(
            methods: [.ton(amountNano: 100), .battery(charges: 6)],
            requiredTon: 2_968_600_000,
            availableTon: 1_000_000_000
        )

        XCTAssertFalse(
            WalletMigrationFeeSelectionResolver.hasPayableTonMethod(
                ton: ton,
                availableBatteryCharges: nil
            )
        )
    }

    func test_hasPayableTonMethod_countsBatteryForTonLegAlone() {
        let ton = makeShortageTonResult(
            methods: [.battery(charges: 6)],
            requiredTon: 2_968_600_000,
            availableTon: 1_000_000_000
        )

        // 6 charges cover the TON leg by itself even when an unpayable TRON leg
        // would have demanded more from the shared balance: TON-only stays offered.
        XCTAssertTrue(
            WalletMigrationFeeSelectionResolver.hasPayableTonMethod(
                ton: ton,
                availableBatteryCharges: 6
            )
        )
        XCTAssertFalse(
            WalletMigrationFeeSelectionResolver.hasPayableTonMethod(
                ton: ton,
                availableBatteryCharges: 5
            )
        )
    }

    func test_hasPayableTonMethod_withoutMethodsFollowsServerShortage() {
        let blocked = makeShortageTonResult(
            methods: [],
            requiredTon: 2_968_600_000,
            availableTon: 1_000_000_000
        )
        let payable = makeShortageTonResult(
            methods: [],
            requiredTon: nil,
            availableTon: 1_000_000_000
        )

        XCTAssertFalse(
            WalletMigrationFeeSelectionResolver.hasPayableTonMethod(
                ton: blocked,
                availableBatteryCharges: nil
            )
        )
        XCTAssertTrue(
            WalletMigrationFeeSelectionResolver.hasPayableTonMethod(
                ton: payable,
                availableBatteryCharges: nil
            )
        )
        XCTAssertFalse(
            WalletMigrationFeeSelectionResolver.hasPayableTonMethod(
                ton: nil,
                availableBatteryCharges: nil
            )
        )
    }

    func test_trxOnlyBatteryMethodDoesNotRequireNativeTrxReserve() {
        let tron = WalletMigrationTronPrepareResult(
            sourceAddress: "source",
            destinationAddress: "destination",
            usdtAmount: 0,
            requiredTRXSun: 50,
            availableTRXSun: 1,
            nativeRequiredTRXSun: 50,
            energy: 0,
            bandwidth: 1,
            availableFeeMethods: [.battery(charges: 1)]
        )

        XCTAssertFalse(
            WalletMigrationFeeSelectionResolver.isTronMethodInsufficient(
                .battery(charges: 1),
                tron: tron,
                tonMethod: nil,
                availableBatteryCharges: 1
            )
        )
        XCTAssertNil(
            WalletMigrationFeeSelectionResolver.tronShortage(
                .battery(charges: 1),
                tron: tron,
                tonMethod: nil,
                availableBatteryCharges: 1
            )
        )
    }

    func test_batteryMethodIsPayableWhenChargesCoverSponsoredLegDespiteUnsponsoredSweep() {
        let sponsored = makeBatteryTransaction()
        let sweep = makePreparedSweepTransaction()
        let ton = WalletMigrationPrepareResult(
            from: "from",
            to: "to",
            walletVersion: "v5R1",
            transactions: [sponsored, sweep],
            batteryTransactions: [sponsored, sweep],
            availableFeeMethods: [.battery(charges: 5)],
            availableTonNano: 50000
        )

        XCTAssertFalse(
            WalletMigrationFeeSelectionResolver.isTonMethodInsufficient(
                .battery(charges: 5),
                ton: ton,
                tronMethod: nil,
                availableBatteryCharges: 5
            )
        )
    }

    func test_batteryMethodStaysPayableWhenNativeGasLooksShortButChargesCover() {
        let sponsored = makeBatteryTransaction()
        let sweep = makePreparedSweepTransaction(fee: 40000)
        let ton = WalletMigrationPrepareResult(
            from: "from",
            to: "to",
            walletVersion: "v5R1",
            transactions: [sponsored, sweep],
            batteryTransactions: [sponsored, sweep],
            availableFeeMethods: [.battery(charges: 5)],
            availableTonNano: 10000
        )

        // Battery is gated on charges only; native gas for the unsponsored sweep
        // must not block selecting Battery when a sponsored path exists.
        XCTAssertFalse(
            WalletMigrationFeeSelectionResolver.isTonMethodInsufficient(
                .battery(charges: 5),
                ton: ton,
                tronMethod: nil,
                availableBatteryCharges: 5
            )
        )
    }

    func test_batteryNotBlockedByNativeGasWhenSweepEventExtraInflatesBeyondBalance() {
        let sponsored = makeBatteryTransaction()
        // Burned sweep fee fits the balance; inflated event.extra must not block Battery.
        let sweep = makePreparedSweepTransaction(fee: 1000, eventExtra: 500_000_000)
        let ton = WalletMigrationPrepareResult(
            from: "from",
            to: "to",
            walletVersion: "v5R1",
            transactions: [sponsored, sweep],
            batteryTransactions: [sponsored, sweep],
            availableFeeMethods: [.battery(charges: 5)],
            availableTonNano: 50000
        )

        XCTAssertFalse(
            WalletMigrationFeeSelectionResolver.isTonMethodInsufficient(
                .battery(charges: 5),
                ton: ton,
                tronMethod: nil,
                availableBatteryCharges: 5
            )
        )
    }
}

private extension WalletMigrationFeeSelectionResolverTests {
    func makeTonResult(availableTon: UInt64) -> WalletMigrationPrepareResult {
        WalletMigrationPrepareResult(
            from: "from",
            to: "to",
            walletVersion: "v5R1",
            transactions: [],
            batteryTransactions: [makeBatteryTransaction()],
            availableFeeMethods: [
                .ton(amountNano: 100),
                .battery(charges: 6),
            ],
            availableTonNano: availableTon
        )
    }

    func makeShortageTonResult(
        methods: [WalletMigrationPrepareResult.FeeMethod],
        requiredTon: UInt64?,
        availableTon: UInt64,
        includesBatteryExecutionPath: Bool = true
    ) -> WalletMigrationPrepareResult {
        let batteryTransactions: [WalletMigrationPreparedTransaction]? = if methods.contains(where: \.isBattery),
                                                                            includesBatteryExecutionPath
        {
            [makeBatteryTransaction()]
        } else {
            nil
        }

        return WalletMigrationPrepareResult(
            from: "from",
            to: "to",
            walletVersion: "v5R1",
            transactions: [],
            batteryTransactions: batteryTransactions,
            availableFeeMethods: methods,
            availableTonNano: availableTon,
            requiredTonNano: requiredTon
        )
    }

    func makeBatteryTransaction() -> WalletMigrationPreparedTransaction {
        let address = try! Address.parse("EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c")
        return WalletMigrationPreparedTransaction(
            seqno: 1,
            boc: "te6cckEBAQEAAgAAAA==",
            event: AccountEvent(
                eventId: "1",
                date: Date(timeIntervalSince1970: 0),
                account: WalletAccount(address: address, name: nil, isScam: false, isWallet: true),
                isScam: false,
                isInProgress: false,
                extra: .Fee(1000),
                excess: nil,
                progress: nil,
                actions: []
            ),
            totalFees: 1000,
            totalEquivalent: nil,
            sponsored: true
        )
    }

    func makePreparedSweepTransaction(fee: UInt64 = 1000) -> WalletMigrationPreparedTransaction {
        makePreparedSweepTransaction(fee: fee, eventExtra: fee)
    }

    func makePreparedSweepTransaction(
        fee: UInt64,
        eventExtra: UInt64
    ) -> WalletMigrationPreparedTransaction {
        let address = try! Address.parse("EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c")
        return WalletMigrationPreparedTransaction(
            seqno: 2,
            boc: "te6cckEBAQEAAgAAAA==",
            event: AccountEvent(
                eventId: "2",
                date: Date(timeIntervalSince1970: 0),
                account: WalletAccount(address: address, name: nil, isScam: false, isWallet: true),
                isScam: false,
                isInProgress: false,
                extra: .Fee(eventExtra),
                excess: nil,
                progress: nil,
                actions: []
            ),
            totalFees: fee,
            totalEquivalent: nil,
            sponsored: false
        )
    }

    func makeTronResult(availableTRX: BigUInt) -> WalletMigrationTronPrepareResult {
        WalletMigrationTronPrepareResult(
            sourceAddress: "source",
            destinationAddress: "destination",
            usdtAmount: 1,
            requiredTRXSun: 50,
            availableTRXSun: availableTRX,
            energy: 0,
            bandwidth: 0,
            availableFeeMethods: [
                .battery(charges: 7),
                .trx(amountSun: 50),
            ]
        )
    }
}
