import BigInt
@testable import KeeperCore
import TonSwift
import XCTest

final class WalletMigrationTrxReservationTests: XCTestCase {
    func test_reservedTRX_nativeTransferUsesSelectedFeeMethod() {
        let prepare = makePrepare(
            usdtAmount: 0,
            availableTRXSun: 15000,
            usdtRequiredTRXSun: 0,
            nativeRequiredTRXSun: 345_000
        )

        XCTAssertEqual(prepare.reservedTRX(for: .battery(charges: 1)), 0)
        XCTAssertEqual(prepare.reservedTRX(for: .trx(amountSun: 345_000)), 345_000)
    }

    func test_reservedTRX_addsUsdtFeeOnlyForTrxMethod() {
        let prepare = makePrepare(
            usdtAmount: 1_000_000,
            availableTRXSun: 1_000_000,
            usdtRequiredTRXSun: 100_000,
            nativeRequiredTRXSun: 50000
        )

        XCTAssertEqual(prepare.reservedTRX(for: .battery(charges: 1)), 50000)
        XCTAssertEqual(prepare.reservedTRX(for: .trx(amountSun: 100_000)), 150_000)
    }

    func test_trxTransferAmount_usesBatteryWhenBalanceCannotCoverNativeBurn() {
        let prepare = makePrepare(
            usdtAmount: 0,
            availableTRXSun: 15000,
            usdtRequiredTRXSun: 0,
            nativeRequiredTRXSun: 345_000
        )

        XCTAssertEqual(prepare.trxTransferAmount(for: .battery(charges: 1)), 15000)
        XCTAssertEqual(prepare.trxTransferAmount(for: .trx(amountSun: 345_000)), 0)
    }

    func test_trxTransferAmount_batteryDoesNotReserveNativeBurn() {
        let prepare = makePrepare(
            usdtAmount: 0,
            availableTRXSun: 500_000,
            usdtRequiredTRXSun: 0,
            nativeRequiredTRXSun: 345_000
        )

        XCTAssertEqual(prepare.trxTransferAmount(for: .battery(charges: 1)), 500_000)
    }

    func test_qaDustTrx_cannotMigrateAfterNativeReserve() {
        let availableTRXSun = BigUInt(15000)
        let nativeRequiredTRXSun = BigUInt(345_000)
        let prepare = makePrepare(
            usdtAmount: 0,
            availableTRXSun: availableTRXSun,
            usdtRequiredTRXSun: 0,
            nativeRequiredTRXSun: nativeRequiredTRXSun
        )

        XCTAssertEqual(prepare.trxTransferAmount(for: .trx(amountSun: nativeRequiredTRXSun)), 0)
        XCTAssertTrue(availableTRXSun < nativeRequiredTRXSun)
        XCTAssertEqual(
            WalletMigrationError.insufficientTrxForFees(
                required: UInt64(nativeRequiredTRXSun),
                available: UInt64(availableTRXSun)
            ),
            .insufficientTrxForFees(required: 345_000, available: 15000)
        )
        XCTAssertTrue(prepare.hasTRX)
        XCTAssertFalse(prepare.shouldAttemptTrxSweep(feeMethod: .trx(amountSun: nativeRequiredTRXSun)))
        XCTAssertEqual(prepare.displayedTRXAmount(for: .trx(amountSun: nativeRequiredTRXSun)), 0)
    }

    func test_batteryWithUsdtIgnoresDustTrxReserve() {
        let prepare = makePrepare(
            usdtAmount: 1_000_000,
            availableTRXSun: 100_000,
            usdtRequiredTRXSun: 27_000_000,
            nativeRequiredTRXSun: 345_000
        )

        XCTAssertFalse(prepare.hasInsufficientTRX(for: .battery(charges: 1)))
        XCTAssertEqual(prepare.trxTransferAmount(for: .battery(charges: 1)), 0)
        // Prepare-time amount is 0, but a post-USDT live sweep must still be attempted.
        XCTAssertTrue(prepare.shouldAttemptTrxSweep(feeMethod: .battery(charges: 1)))
        XCTAssertEqual(
            prepare.displayedTRXAmount(for: .battery(charges: 1)),
            100_000
        )
    }

    func test_shouldAttemptTrxSweep_falseWithoutTrxBalance() {
        let prepare = makePrepare(
            usdtAmount: 1_000_000,
            availableTRXSun: 0,
            usdtRequiredTRXSun: 27_000_000,
            nativeRequiredTRXSun: 345_000
        )

        XCTAssertFalse(prepare.shouldAttemptTrxSweep(feeMethod: .battery(charges: 1)))
        XCTAssertEqual(prepare.displayedTRXAmount(for: .battery(charges: 1)), 0)
    }

    func test_trxSweepBufferedFee_zeroWhenNoBurn() {
        XCTAssertEqual(WalletMigrationTrxSweep.bufferedFeeSun(0), 0)
        XCTAssertEqual(
            WalletMigrationTrxSweep.transferAmount(balanceSun: 100_000, feeSun: 0),
            100_000
        )
    }

    func test_trxSweepBufferedFee_padsWhenBurnRequired() {
        XCTAssertEqual(WalletMigrationTrxSweep.bufferedFeeSun(100_000), 200_000)
        XCTAssertEqual(WalletMigrationTrxSweep.bufferedFeeSun(300_000), 450_000)
        XCTAssertEqual(
            WalletMigrationTrxSweep.transferAmount(balanceSun: 100_000, feeSun: 345_000),
            0
        )
    }

    func test_trxSweepReducedAmount() {
        XCTAssertEqual(WalletMigrationTrxSweep.reducedAmountSun(100_000), 80000)
        XCTAssertEqual(WalletMigrationTrxSweep.reducedAmountSun(1), 0)
    }

    func test_blockingTRXShortage_whenTrxIsTheOnlyMethodAndBalanceShort() {
        let prepare = makePrepare(
            usdtAmount: 1,
            availableTRXSun: 0,
            usdtRequiredTRXSun: 50,
            nativeRequiredTRXSun: 0,
            availableFeeMethods: [.trx(amountSun: 50)]
        )

        let shortage = prepare.blockingTRXShortage { _ in true }
        XCTAssertEqual(shortage?.required, 50)
        XCTAssertEqual(shortage?.available, 0)
    }

    func test_blockingTRXShortage_nilWhenBatteryIsOffered() {
        let prepare = makePrepare(
            usdtAmount: 1,
            availableTRXSun: 0,
            usdtRequiredTRXSun: 50,
            nativeRequiredTRXSun: 0,
            availableFeeMethods: [.battery(charges: 1), .trx(amountSun: 50)]
        )

        XCTAssertNil(prepare.blockingTRXShortage { _ in true })
    }

    func test_blockingTRXShortage_nilWhenBalanceCoversFees() {
        let prepare = makePrepare(
            usdtAmount: 1,
            availableTRXSun: 100,
            usdtRequiredTRXSun: 50,
            nativeRequiredTRXSun: 0,
            availableFeeMethods: [.trx(amountSun: 50)]
        )

        XCTAssertNil(prepare.blockingTRXShortage { _ in true })
    }

    func test_exactTrxBalanceIsInsufficientForTrxFeeMethod() {
        let fee = BigUInt(345_000)
        let prepare = makePrepare(
            usdtAmount: 0,
            availableTRXSun: fee,
            usdtRequiredTRXSun: 0,
            nativeRequiredTRXSun: fee
        )

        XCTAssertTrue(prepare.hasInsufficientTRX)
        XCTAssertTrue(prepare.hasInsufficientTRX(for: .trx(amountSun: fee)))
        XCTAssertEqual(prepare.trxTransferAmount(for: .trx(amountSun: fee)), 0)
    }

    func test_displayedTRXAmountUsesTransferableAmountWhenFeesAreCovered() {
        let prepare = makePrepare(
            usdtAmount: 0,
            availableTRXSun: 500_000,
            usdtRequiredTRXSun: 0,
            nativeRequiredTRXSun: 345_000
        )

        XCTAssertEqual(
            prepare.displayedTRXAmount(for: .trx(amountSun: 345_000)),
            155_000
        )
    }

    /// Account creation is payable with staked bandwidth; free bandwidth never covers it.
    func test_activationFee_addsCreateAccountBurnOnlyWithoutStakedBandwidth() {
        let fee = { (staked: Int) in
            TronUSDTAPI.activationFeeSun(
                createNewAccountSun: 1_000_000,
                createAccountSun: 100_000,
                stakedBandwidth: staked,
                transferBandwidth: 345,
                createNewAccountBandwidthRate: 1
            )
        }

        XCTAssertEqual(fee(0), 1_100_000)
        XCTAssertEqual(fee(344), 1_100_000)
        XCTAssertEqual(fee(345), 1_000_000)
        XCTAssertEqual(fee(5000), 1_000_000)
    }

    /// The node weighs the raw size against `getCreateNewAccountBandwidthRate`, so a raised rate
    /// must move the threshold with it instead of silently under-reserving.
    func test_activationFee_scalesBandwidthCostWithChainRate() {
        let fee = { (staked: Int, rate: BigUInt) in
            TronUSDTAPI.activationFeeSun(
                createNewAccountSun: 1_000_000,
                createAccountSun: 100_000,
                stakedBandwidth: staked,
                transferBandwidth: 345,
                createNewAccountBandwidthRate: rate
            )
        }

        XCTAssertEqual(fee(345, 2), 1_100_000)
        XCTAssertEqual(fee(690, 2), 1_000_000)
        XCTAssertEqual(fee(0, 0), 1_000_000)
    }

    /// TK-2909: sweeping to a never-activated destination owes TRON 1.1 TRX on top of the amount,
    /// which Battery cannot sponsor — 0.79 TRX has to surface as a shortage, not a failed broadcast.
    func test_qaFullBalanceSweepToInactiveDestinationIsBlocked() {
        let activation = BigUInt(1_100_000)
        let prepare = makePrepare(
            usdtAmount: 0,
            availableTRXSun: 790_768,
            usdtRequiredTRXSun: 0,
            nativeRequiredTRXSun: activation,
            destinationRequiresActivation: true
        )

        XCTAssertEqual(prepare.reservedTRX(for: .battery(charges: 1)), activation)
        XCTAssertEqual(prepare.reservedTRX(for: .trx(amountSun: activation)), activation)
        XCTAssertEqual(prepare.trxTransferAmount(for: .battery(charges: 1)), 0)
        XCTAssertEqual(prepare.trxTransferAmount(for: .trx(amountSun: activation)), 0)

        let shortage = prepare.blockingTRXShortage { _ in true }
        XCTAssertEqual(shortage?.required, activation)
        XCTAssertEqual(shortage?.available, 790_768)
    }

    func test_sweepToInactiveDestinationKeepsActivationBurnOutOfTheAmount() {
        let activation = BigUInt(1_100_000)
        let prepare = makePrepare(
            usdtAmount: 0,
            availableTRXSun: 5_000_000,
            usdtRequiredTRXSun: 0,
            nativeRequiredTRXSun: activation,
            destinationRequiresActivation: true
        )

        XCTAssertNil(prepare.blockingTRXShortage { _ in true })
        XCTAssertEqual(prepare.trxTransferAmount(for: .trx(amountSun: activation)), 3_900_000)
        XCTAssertEqual(prepare.trxTransferAmount(for: .battery(charges: 1)), 3_900_000)
    }

    /// The USDT leg still goes through: only the TRX remainder is dropped as non-transferable dust.
    func test_inactiveDestinationWithUsdtDoesNotBlockTheTronLeg() {
        let prepare = makePrepare(
            usdtAmount: 1_000_000,
            availableTRXSun: 790_768,
            usdtRequiredTRXSun: 27_000_000,
            nativeRequiredTRXSun: 1_100_000,
            destinationRequiresActivation: true
        )

        XCTAssertNil(prepare.blockingTRXShortage { _ in true })
        XCTAssertEqual(prepare.trxTransferAmount(for: .battery(charges: 1)), 0)
    }

    /// TK-2909: 6.98 TRX cannot pay the 27 TRX energy burn for the USDT leg, and the offered Battery
    /// option is unusable without charges — the shortage has to surface instead of a confirmation
    /// screen whose slider stays locked.
    func test_qaUnaffordableBatteryStillReportsTrxShortage() {
        let prepare = makePrepare(
            usdtAmount: 1_000_000,
            availableTRXSun: 6_984_430,
            usdtRequiredTRXSun: 27_000_000,
            nativeRequiredTRXSun: 1_100_000,
            destinationRequiresActivation: true,
            availableFeeMethods: [.battery(charges: 454), .trx(amountSun: 27_000_000)]
        )

        let shortage = prepare.blockingTRXShortage { !$0.isBattery }
        XCTAssertEqual(shortage?.required, 27_000_000)
        XCTAssertEqual(shortage?.available, 6_984_430)
        XCTAssertNil(prepare.blockingTRXShortage { _ in true })
    }

    /// Battery charges are one budget for both legs: each method fits the balance alone while the
    /// pair does not, so the TRON leg is only a way out once the TON leg's claim is counted in.
    func test_batteryBudgetIsSharedBetweenTonAndTronLegs() {
        let ton = WalletMigrationPrepareResult(
            from: "from",
            to: "to",
            walletVersion: "v5R1",
            transactions: [],
            batteryTransactions: [makePreparedTransaction(sponsored: true)],
            availableFeeMethods: [.ton(amountNano: 100), .battery(charges: 6)],
            availableTonNano: 0
        )
        let tron = makePrepare(
            usdtAmount: 1_000_000,
            availableTRXSun: 6_984_430,
            usdtRequiredTRXSun: 27_000_000,
            nativeRequiredTRXSun: 1_100_000,
            destinationRequiresActivation: true,
            availableFeeMethods: [.battery(charges: 7), .trx(amountSun: 27_000_000)]
        )

        XCTAssertEqual(
            tron.blockingTRXShortage { method in
                WalletMigrationFeeSelectionResolver.isTronMethodPayable(
                    method,
                    ton: ton,
                    tron: tron,
                    availableBatteryCharges: 12
                )
            }?.required,
            27_000_000
        )
        XCTAssertNil(
            tron.blockingTRXShortage { method in
                WalletMigrationFeeSelectionResolver.isTronMethodPayable(
                    method,
                    ton: ton,
                    tron: tron,
                    availableBatteryCharges: 13
                )
            }
        )
    }

    /// A TON leg quoted Battery from the self-paid plan but carrying no sponsored transactions —
    /// what a v3/v4 wallet gets, since its battery prepare yields none — cannot execute the method,
    /// so no method pays that leg and the soft-shortage Continue drops it. The TRON leg then claims
    /// the charges alone: the same 12 that block the shared budget above are enough here.
    func test_tonLegWithoutBatteryExecutionPathLeavesTheTronLegStandalone() {
        let ton = WalletMigrationPrepareResult(
            from: "from",
            to: "to",
            walletVersion: "v4R2",
            transactions: [makePreparedTransaction(sponsored: false)],
            availableFeeMethods: [.ton(amountNano: 100), .battery(charges: 6)],
            availableTonNano: 0
        )
        let tron = makePrepare(
            usdtAmount: 1_000_000,
            availableTRXSun: 6_984_430,
            usdtRequiredTRXSun: 27_000_000,
            nativeRequiredTRXSun: 1_100_000,
            destinationRequiresActivation: true,
            availableFeeMethods: [.battery(charges: 7), .trx(amountSun: 27_000_000)]
        )

        XCTAssertTrue(
            WalletMigrationFeeSelectionResolver.isTonMethodInsufficient(
                .battery(charges: 6),
                ton: ton,
                tronMethod: nil,
                availableBatteryCharges: 12
            )
        )
        XCTAssertFalse(
            WalletMigrationFeeSelectionResolver.isTonMethodPayable(
                .battery(charges: 6),
                ton: ton,
                availableBatteryCharges: 12
            )
        )
        XCTAssertNil(
            tron.blockingTRXShortage { method in
                WalletMigrationFeeSelectionResolver.isTronMethodPayable(
                    method,
                    ton: ton,
                    tron: tron,
                    availableBatteryCharges: 12
                )
            }
        )
    }

    /// Battery cannot be spent on the activation burn either, so partial charges do not turn the
    /// TRX-only leg into a payable one.
    func test_unaffordableBatteryBlocksTrxOnlySweep() {
        let prepare = makePrepare(
            usdtAmount: 0,
            availableTRXSun: 790_768,
            usdtRequiredTRXSun: 0,
            nativeRequiredTRXSun: 1_100_000,
            destinationRequiresActivation: true,
            availableFeeMethods: [.battery(charges: 10), .trx(amountSun: 1_100_000)]
        )

        XCTAssertEqual(prepare.blockingTRXShortage { !$0.isBattery }?.required, 1_100_000)
    }

    /// Each pool has to cover the transaction on its own: a 356-byte transfer against 200 staked plus
    /// 200 free is burned by the node, however inviting the sum looks.
    func test_chargeBandwidth_doesNotMergePools() {
        let charge = TronUSDTAPI.chargeBandwidth(
            transactionBandwidth: 356,
            burnBandwidth: 356,
            allowance: TronBandwidthAllowance(staked: 200, free: 200)
        )

        XCTAssertEqual(charge.burnedBandwidth, 356)
        XCTAssertEqual(charge.remaining, TronBandwidthAllowance(staked: 200, free: 200))
    }

    /// Staked is offered the transaction first, so it is the pool the next leg finds shorter.
    func test_chargeBandwidth_drainsStakedBeforeFree() {
        let charge = TronUSDTAPI.chargeBandwidth(
            transactionBandwidth: 356,
            burnBandwidth: 356,
            allowance: TronBandwidthAllowance(staked: 500, free: 600)
        )

        XCTAssertEqual(charge.burnedBandwidth, 0)
        XCTAssertEqual(charge.remaining, TronBandwidthAllowance(staked: 144, free: 600))
    }

    func test_chargeBandwidth_fallsBackToFreePool() {
        let charge = TronUSDTAPI.chargeBandwidth(
            transactionBandwidth: 356,
            burnBandwidth: 356,
            allowance: TronBandwidthAllowance(staked: 100, free: 600)
        )

        XCTAssertEqual(charge.burnedBandwidth, 0)
        XCTAssertEqual(charge.remaining, TronBandwidthAllowance(staked: 100, free: 244))
    }

    /// The USDT leg is broadcast first, so the sweep that follows reserves against what it left: the
    /// free pool covered one 356-byte transfer out of 600, never two.
    func test_chargeBandwidth_secondLegBurnsWhatTheFirstLegLeftShort() {
        let usdtLeg = TronUSDTAPI.chargeBandwidth(
            transactionBandwidth: 356,
            burnBandwidth: 356,
            allowance: TronBandwidthAllowance(staked: 0, free: 600)
        )
        XCTAssertEqual(usdtLeg.burnedBandwidth, 0)

        let trxLeg = TronUSDTAPI.chargeBandwidth(
            transactionBandwidth: 356,
            burnBandwidth: 356,
            allowance: usdtLeg.remaining
        )
        XCTAssertEqual(trxLeg.burnedBandwidth, 356)
    }

    /// A burned transfer pays out of the balance and leaves both pools intact, so the next leg must
    /// not be charged for an allowance the first one never touched.
    func test_chargeBandwidth_burnLeavesPoolsForTheNextLeg() {
        let firstLeg = TronUSDTAPI.chargeBandwidth(
            transactionBandwidth: 700,
            burnBandwidth: 700,
            allowance: TronBandwidthAllowance(staked: 0, free: 600)
        )
        XCTAssertEqual(firstLeg.burnedBandwidth, 700)

        let secondLeg = TronUSDTAPI.chargeBandwidth(
            transactionBandwidth: 356,
            burnBandwidth: 356,
            allowance: firstLeg.remaining
        )
        XCTAssertEqual(secondLeg.burnedBandwidth, 0)
        XCTAssertEqual(secondLeg.remaining, TronBandwidthAllowance(staked: 0, free: 244))
    }

    /// Activation is weighed against the staked bandwidth the earlier leg left behind: 500 covers the
    /// creation cost, the 144 remaining after a 356-byte USDT transfer does not.
    func test_activationFee_usesStakedBandwidthLeftByEarlierLeg() {
        let remainingStaked = TronUSDTAPI.chargeBandwidth(
            transactionBandwidth: 356,
            burnBandwidth: 356,
            allowance: TronBandwidthAllowance(staked: 500, free: 0)
        ).remaining.staked
        XCTAssertEqual(remainingStaked, 144)

        let fee = { (staked: Int) in
            TronUSDTAPI.activationFeeSun(
                createNewAccountSun: 1_000_000,
                createAccountSun: 100_000,
                stakedBandwidth: staked,
                transferBandwidth: 345,
                createNewAccountBandwidthRate: 1
            )
        }

        XCTAssertEqual(fee(500), 1_000_000)
        XCTAssertEqual(fee(remainingStaked), 1_100_000)
    }

    func test_batterySponsoredResources_keepsNativeBandwidthWhenPoolsCoverTheBurn() {
        let resources = TronUSDTAPI.batterySponsoredResources(
            marginEnergy: 0,
            marginBandwidth: 356,
            destinationRequiresActivation: false
        )

        XCTAssertEqual(resources?.energy, 0)
        XCTAssertEqual(resources?.bandwidth, 356)
    }

    func test_batterySponsoredResources_skipsZeroZeroEstimate() {
        XCTAssertNil(
            TronUSDTAPI.batterySponsoredResources(
                marginEnergy: 0,
                marginBandwidth: 0,
                destinationRequiresActivation: false
            )
        )
        XCTAssertNil(
            TronUSDTAPI.batterySponsoredResources(
                marginEnergy: 0,
                marginBandwidth: 356,
                destinationRequiresActivation: true
            )
        )
    }

    func test_batterySponsoredResources_keepsUsdtEnergyWhenBandwidthIsCovered() {
        let resources = TronUSDTAPI.batterySponsoredResources(
            marginEnergy: 8883,
            marginBandwidth: 0,
            destinationRequiresActivation: false
        )

        XCTAssertEqual(resources?.energy, 8883)
        XCTAssertEqual(resources?.bandwidth, 0)
    }

    func test_chargeBandwidth_usesTransactionSizeToSelectPoolAndMarginForBurn() {
        let covered = TronUSDTAPI.chargeBandwidth(
            transactionBandwidth: 345,
            burnBandwidth: 356,
            allowance: TronBandwidthAllowance(staked: 350, free: 600)
        )
        XCTAssertEqual(covered.burnedBandwidth, 0)
        XCTAssertEqual(covered.remaining, TronBandwidthAllowance(staked: 5, free: 600))

        let burned = TronUSDTAPI.chargeBandwidth(
            transactionBandwidth: 345,
            burnBandwidth: 356,
            allowance: TronBandwidthAllowance(staked: 344, free: 344)
        )
        XCTAssertEqual(burned.burnedBandwidth, 356)
        XCTAssertEqual(burned.remaining, TronBandwidthAllowance(staked: 344, free: 344))
    }

    private func makePreparedTransaction(sponsored: Bool) -> WalletMigrationPreparedTransaction {
        WalletMigrationPreparedTransaction(
            seqno: 1,
            boc: "te6cckEBAQEAAgAAAA==",
            event: AccountEvent(
                eventId: "1",
                date: Date(timeIntervalSince1970: 0),
                account: WalletAccount(
                    address: try! Address.parse("EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"),
                    name: nil,
                    isScam: false,
                    isWallet: true
                ),
                isScam: false,
                isInProgress: false,
                extra: .Fee(1000),
                excess: nil,
                progress: nil,
                actions: []
            ),
            totalFees: 1000,
            totalEquivalent: nil,
            sponsored: sponsored
        )
    }

    private func makePrepare(
        usdtAmount: BigUInt,
        availableTRXSun: BigUInt,
        usdtRequiredTRXSun: BigUInt,
        nativeRequiredTRXSun: BigUInt,
        destinationRequiresActivation: Bool = false,
        availableFeeMethods: [WalletMigrationTronPrepareResult.FeeMethod]? = nil
    ) -> WalletMigrationTronPrepareResult {
        WalletMigrationTronPrepareResult(
            sourceAddress: "TFrom",
            destinationAddress: "TTo",
            usdtAmount: usdtAmount,
            requiredTRXSun: usdtAmount > 0
                ? usdtRequiredTRXSun
                : nativeRequiredTRXSun,
            availableTRXSun: availableTRXSun,
            usdtRequiredTRXSun: usdtRequiredTRXSun,
            nativeRequiredTRXSun: nativeRequiredTRXSun,
            energy: 0,
            bandwidth: 345,
            trxEnergy: 0,
            trxBandwidth: 345,
            destinationRequiresActivation: destinationRequiresActivation,
            availableFeeMethods: availableFeeMethods
                ?? [.battery(charges: 1), .trx(amountSun: nativeRequiredTRXSun)]
        )
    }
}
