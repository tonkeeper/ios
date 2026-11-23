@preconcurrency import BigInt
import ChainKit
import Foundation
@testable import KeeperCore
import KeeperCoreComponents
import OperationReviewModels
import TKBatteryAPI
import TKTestSupport
import TonAPI
import TonSwift
import TronSwift
import TronSwiftAPI
import XCTest

/// The send the multichain send controller picks, and what it hands it: the consent of the swipe, so
/// the gate before the signature passes what the swipe accepted, while its send without one refuses
/// what needs it; and the App's TON signer, behind the gate for a TON engine only.
final class MultichainSendConsentTests: XCTestCase {
    func testFailedPostMigrationJettonPriceKeepsBatteryVisibleAndUnavailableThroughPickerRefresh() async throws {
        let session = BatteryPaymentTestSession()
        let failsPricing = FeeFunding(false)
        let controller = try makeController(
            asset: Self.tonJetton,
            recipient: Self.tonRecipient,
            signer: .mnemonic(passcodeProvider: { await session.passcode() }),
            heldJetton: Self.heldJetton,
            offersBatteryMigration: { _ in !(await session.migrated) },
            batteryPaymentPreparation: BatteryPaymentPreparation(
                needsMigration: { _ in !(await session.migrated) },
                migrate: { _, code in
                    try await session.migrate(code)
                    await failsPricing.set(true)
                }
            ),
            beforeTonEmulate: {
                if await failsPricing.value { throw BatteryPaymentTestError.offline }
            }
        )
        controller.signHandler = { _, _ throws(TransactionConfirmationError) in
            XCTFail("An unpriced transfer must not be signed")
            throw .cancelledByUser
        }
        controller.setPrefferedExtraType(extraType: .battery)
        _ = await controller.emulate()
        guard case let .extra(initial) = controller.getModel().extraState, initial.value.extraType.isBattery else { return XCTFail("Expected initial Battery quote") }

        let failed = await controller.sendTransaction()
        guard case .failure = failed else { return XCTFail("Expected failed post-migration price") }
        for _ in 0 ..< 2 {
            await controller.prepareFeeOptions()
            let model = controller.getModel()
            guard case let .extra(extra) = model.extraState else { return XCTFail("Unavailable Battery must remain selected") }
            XCTAssertTrue(extra.value.extraType.isBattery)
            XCTAssertTrue(model.isSelectedFeeUnavailable)
            let row = try XCTUnwrap(model.extraOptions.first { $0.type.isBattery })
            XCTAssertFalse(row.isAvailable)
        }
        let retry = await controller.sendTransaction()
        guard case .failure(.multichainTransactionFailure(.feeMethodUnavailable)) = retry else { return XCTFail("Expected stale jetton quote refusal") }
        let events = await session.events
        XCTAssertEqual(events, ["pin", "migration-start", "migration-complete"])

        await failsPricing.set(false)
        _ = await controller.emulate()
        XCTAssertFalse(controller.getModel().isSelectedFeeUnavailable)
    }

    func testTrxSwipeWaitsForTheFeeRefreshAndCanBeCancelledBeforeAnyWork() async throws {
        let queued = TestSignal()
        let gate = MultichainFeeCalculationGate(onWait: { queued.send() })
        let controller = try await makeController(
            asset: Self.tronUSDT,
            recipient: Self.tronRecipient,
            tronUsdtApi: pricedTronUsdtApi(),
            feeCalculationGate: gate
        )
        try await pickTRX(on: controller)
        let acquired = await gate.acquire()
        XCTAssertTrue(acquired)
        let before = calls.recorded
        let send = Task { await controller.sendTransaction() }
        await waitUntil(queued) { await gate.waitingCount == 1 }
        XCTAssertEqual(calls.recorded, before)
        send.cancel()
        let result = await send.value
        await gate.release()

        guard case .failure(.cancelledByUser) = result else { return XCTFail("Expected cancellation while waiting for fee refresh: \(result)") }
        XCTAssertEqual(calls.recorded, before)
        XCTAssertTrue(calls.relayed.isEmpty)
    }

    func testPartiallyFundedNewFeeTokenKeepsTheSelectedRowInsufficient() async throws {
        let listed = FeeFunding(false)
        let session = BatteryPaymentTestSession()
        let feeAsset = MultichainAssetDetails(assetId: GaslessFixtures.usdcId, name: "USD Coin", symbol: "USDC", decimals: 6, image: "")
        let relayer = RelayerStub()
        relayer.estimationsOverride = [.init(
            asset: .init(id: feeAsset.assetId, name: feeAsset.name, symbol: feeAsset.symbol, decimals: feeAsset.decimals, image: nil),
            fee: 18,
            isAvailable: true
        )]
        relayer.onEmulate = { await session.record("emulate") }
        var chainKit = ChainKitServiceStub(review: nil)
        chainKit.failsOperationPricing = true
        let controller = try makeController(
            asset: Self.usdt,
            recipient: Self.ethRecipient,
            amount: 1_000_000,
            signer: .mnemonic(passcodeProvider: { await session.passcode() }),
            chainKitService: chainKit,
            relayedEVMChains: [.eth],
            evmGaslessFeeEngine: EVMGaslessFeeEngine(
                relayer: relayer,
                signer: RelayedOperationSignerStub(requestsPasscode: true),
                isEnabled: { _ in true },
                batteryCharges: { _ in .available(0) },
                walletTokens: { _, _ in
                    await listed.value
                        ? [feeAsset.assetId: Self.asset(feeAsset.assetId, name: "Wallet USD Coin", symbol: "USDC", decimals: 6, balance: 10)]
                        : [:]
                },
                gate: OperationGate { [] }
            ),
            flags: .operationTransfers
        )
        controller.setPrefferedExtraType(extraType: .multichain(token: feeAsset))
        _ = await controller.emulate()
        await listed.set(true)

        await controller.prepareFeeOptions()

        let model = controller.getModel()
        guard case let .extra(extra) = model.extraState else { return XCTFail("Expected selected fee") }
        let selected = try XCTUnwrap(model.extraOptions.first { $0.type == extra.value.extraType })
        XCTAssertTrue(selected.isInsufficient)
        XCTAssertTrue(model.isSelectedFeeInsufficient)
        let result = await controller.sendTransaction()
        guard case .failure(.multichainTransactionFailure(.insufficientSelectedFee)) = result else { return XCTFail("Expected refusal before review: \(result)") }
        XCTAssertEqual(relayer.sent, 0)
        let events = await session.events
        XCTAssertTrue(events.isEmpty)
    }

    func testFailedPostMigrationTronPriceCannotBeRetriedWithoutAFreshFee() async throws {
        let session = BatteryPaymentTestSession()
        let controller = try await makeController(
            asset: Self.tronUSDT,
            recipient: Self.tronRecipient,
            signer: .mnemonic(passcodeProvider: { await session.passcode() }),
            tronUsdtApi: pricedTronUsdtApi(),
            offersBatteryMigration: { _ in !(await session.migrated) },
            batteryPaymentPreparation: BatteryPaymentPreparation(
                needsMigration: { _ in !(await session.migrated) },
                migrate: { _, code in
                    try await session.migrate(code)
                    TronNodeStub.refusesFeeEstimate = true
                }
            ),
            trxOnlyRegion: false
        )
        defer { TronNodeStub.refusesFeeEstimate = false }
        controller.tronSignHandler = { _, _ throws(TronTransferSignError) in
            XCTFail("An unpriced transfer must not be signed")
            throw .cancelled
        }
        _ = await controller.emulate()
        controller.setPrefferedExtraType(extraType: .battery)
        _ = await controller.emulate()

        let failed = await controller.sendTransaction()
        guard case .failure = failed else { return XCTFail("Expected failed fee refresh") }
        XCTAssertTrue(controller.getModel().isSelectedFeeUnavailable)
        await controller.prepareFeeOptions()
        XCTAssertTrue(controller.getModel().isSelectedFeeUnavailable)
        let before = calls.recorded
        let retry = await controller.sendTransaction()

        guard case .failure(.multichainTransactionFailure(.feeMethodUnavailable)) = retry else { return XCTFail("Expected refusal before retrying an unpriced send: \(retry)") }
        XCTAssertEqual(calls.recorded, before)
        let events = await session.events
        XCTAssertEqual(events, ["pin", "migration-start", "migration-complete"])
        XCTAssertTrue(calls.relayed.isEmpty)

        TronNodeStub.refusesFeeEstimate = false
        _ = await controller.emulate()
        XCTAssertFalse(controller.getModel().isSelectedFeeUnavailable)
        guard case let .extra(extra) = controller.getModel().extraState else { return XCTFail("Expected a fresh Battery fee") }
        XCTAssertEqual(extra.value.extraType, .battery)
    }

    func testCoreRefusesASendWhileFeesAreLoading() async throws {
        let chainKit = ChainKitServiceStub(review: nil)
        let controller = try makeController(asset: Self.eth, recipient: Self.ethRecipient, chainKitService: chainKit)
        let result = await controller.sendTransaction()
        guard case .failure(.multichainTransactionFailure(.feeQuoteLoading)) = result else { return XCTFail("Expected waiting for the fee without reporting a user cancellation") }
        let requests = await chainKit.calls.all
        XCTAssertTrue(requests.isEmpty)
    }

    func testCancelledTronCalculationFinishesBeforeTheNewAutomaticPreferenceReset() async throws {
        let queued = TestSignal()
        let calculationGate = MultichainFeeCalculationGate(onWait: { queued.send() })
        let delay = EmulationDelay()
        let funded = FeeFunding(false)
        var battery = batteryService(estimatedCharges: 18)
        battery.balanceProvider = {
            let snapshot = await funded.value
            await delay.waitIfNeeded()
            return snapshot ? BatteryBalance(balance: "1", reserved: "0") : .empty
        }
        let controller = try await makeController(
            asset: Self.tronUSDT,
            recipient: Self.tronRecipient,
            tronUsdtApi: pricedTronUsdtApi(batteryService: battery),
            trxOnlyRegion: false,
            batteryService: battery,
            feeCalculationGate: calculationGate
        )
        _ = await controller.emulate()
        await delay.holdNext()
        let stale = Task { await controller.emulate() }
        try await delay.entered.wait()
        stale.cancel()
        await funded.set(true)
        controller.setLoading()
        let fresh = Task { await controller.emulate() }
        await waitUntil(queued) { await calculationGate.waitingCount == 1 }

        await delay.release.open()
        let staleResult = await stale.value
        let freshResult = await fresh.value

        guard case .failure(.cancelledByUser) = staleResult else { return XCTFail("Expected cancelled old calculation") }
        guard case .success = freshResult else { return XCTFail("Expected refreshed calculation") }
        guard case let .extra(extra) = controller.getModel().extraState else { return XCTFail("Expected a priced fee") }
        XCTAssertTrue(extra.value.extraType.isBattery)
    }

    func testCancelledQueuedCalculationDoesNotWaitForANonCooperativeOwner() async {
        let queued = TestSignal()
        let gate = MultichainFeeCalculationGate(onWait: { queued.send() })
        let acquired = await gate.acquire()
        XCTAssertTrue(acquired)
        let cancelled = Task { await gate.acquire() }
        await waitUntil(queued) { await gate.waitingCount == 1 }
        cancelled.cancel()
        let cancelledAcquired = await cancelled.value
        XCTAssertFalse(cancelledAcquired)
        let next = Task { await gate.acquire() }
        await waitUntil(queued) { await gate.waitingCount == 1 }

        await gate.release()
        let nextAcquired = await next.value
        XCTAssertTrue(nextAcquired)
        await gate.release()
        let reacquired = await gate.acquire()
        XCTAssertTrue(reacquired)
        await gate.release()
    }

    func testRelayedSendUsesTheBalanceRefreshedInTheFeePicker() async throws {
        for battery in [false, true] {
            for initiallyFunded in [false, true] {
                let funded = FeeFunding(initiallyFunded)
                let session = BatteryPaymentTestSession()
                let relayer = RelayerStub()
                let feeAsset = MultichainAssetDetails(assetId: GaslessFixtures.usdcId, name: "USD Coin", symbol: "USDC", decimals: 6, image: "")
                if !battery {
                    relayer.estimationsOverride = [.init(
                        asset: .init(id: feeAsset.assetId, name: feeAsset.name, symbol: feeAsset.symbol, decimals: feeAsset.decimals, image: nil),
                        fee: 18,
                        isAvailable: true
                    )]
                }
                relayer.onEmulate = { await session.record("emulate") }
                var chainKit = ChainKitServiceStub(review: nil)
                chainKit.failsOperationPricing = true
                let controller = try makeController(
                    asset: Self.usdt,
                    recipient: Self.ethRecipient,
                    amount: 1_000_000,
                    signer: .mnemonic(passcodeProvider: { await session.passcode() }),
                    chainKitService: chainKit,
                    relayedEVMChains: [.eth],
                    evmGaslessFeeEngine: EVMGaslessFeeEngine(
                        relayer: relayer,
                        signer: RelayedOperationSignerStub(requestsPasscode: true),
                        isEnabled: { _ in true },
                        batteryCharges: { _ in await funded.value ? .available(100) : .available(0) },
                        walletTokens: { _, _ in
                            [feeAsset.assetId: Self.asset(feeAsset.assetId, name: feeAsset.name, symbol: feeAsset.symbol, decimals: feeAsset.decimals, balance: await funded.value ? 100 : 0)]
                        },
                        gate: OperationGate { [] }
                    ),
                    flags: .operationTransfers
                )
                controller.setPrefferedExtraType(extraType: battery ? .battery : .multichain(token: feeAsset))
                _ = await controller.emulate()
                XCTAssertEqual(controller.getModel().isSelectedFeeInsufficient, !initiallyFunded)

                await funded.set(!initiallyFunded)
                await controller.prepareFeeOptions()
                XCTAssertEqual(controller.getModel().isSelectedFeeInsufficient, initiallyFunded)
                let before = await session.events
                let result = await controller.sendTransaction()

                if initiallyFunded {
                    guard case .failure(.multichainTransactionFailure(.insufficientSelectedFee)) = result else { return XCTFail("Expected the refreshed shortage to stop before review: \(result)") }
                    let after = await session.events
                    XCTAssertEqual(after, before)
                    XCTAssertEqual(relayer.sent, 0)
                } else {
                    guard case .success = result else { return XCTFail("Expected the refreshed funding to allow sending: \(result)") }
                    XCTAssertEqual(relayer.sent, 1)
                    let events = await session.events
                    XCTAssertEqual(events.filter { $0 == "pin" }.count, 1)
                }
            }
        }
    }

    func testAutomaticTronFeeIsReconsideredAfterBatteryFundingButAUserPickIsKept() async throws {
        for userPickedTRX in [false, true] {
            let session = BatteryPaymentTestSession()
            var battery = batteryService(estimatedCharges: 18)
            battery.balanceProvider = { await session.migrated ? BatteryBalance(balance: "1", reserved: "0") : .empty }
            let controller = try await makeController(
                asset: Self.tronUSDT,
                recipient: Self.tronRecipient,
                tronUsdtApi: pricedTronUsdtApi(batteryService: battery),
                trxOnlyRegion: false,
                batteryService: battery
            )
            _ = await controller.emulate()
            guard case let .extra(initial) = controller.getModel().extraState, initial.value.extraType.isTRXGasless else {
                return XCTFail("Expected automatic TRX while Battery is empty")
            }
            if userPickedTRX { controller.setPrefferedExtraType(extraType: initial.value.extraType) }

            try await session.migrate("1234")
            controller.setLoading()
            _ = await controller.emulate()

            guard case let .extra(updated) = controller.getModel().extraState else { return XCTFail("Expected a priced fee") }
            XCTAssertEqual(updated.value.extraType.isTRXGasless, userPickedTRX)
            XCTAssertEqual(updated.value.extraType.isBattery, !userPickedTRX)
        }
    }

    func testUnavailableRelayedTokenIsRejectedByCoreBeforeEmulationOrSigning() async throws {
        let session = BatteryPaymentTestSession()
        let relayer = RelayerStub()
        relayer.estimationsOverride = [.init(
            asset: Components.Schemas.GaslessV2Asset(id: GaslessFixtures.usdtId, name: "Tether", symbol: "USDT", decimals: 6, image: nil),
            fee: 115_304,
            isAvailable: false
        )]
        relayer.onEmulate = { await session.record("emulate") }
        var chainKit = ChainKitServiceStub(review: nil)
        chainKit.failsOperationPricing = true
        let controller = try makeController(
            asset: Self.usdt,
            recipient: Self.ethRecipient,
            signer: .mnemonic(passcodeProvider: { await session.passcode() }),
            chainKitService: chainKit,
            relayedEVMChains: [.eth],
            evmGaslessFeeEngine: EVMGaslessFeeEngine(
                relayer: relayer,
                signer: RelayedOperationSignerStub(requestsPasscode: true),
                isEnabled: { _ in true },
                batteryCharges: { _ in .available(100) },
                walletTokens: { _, _ in [:] },
                gate: OperationGate { [] }
            ),
            flags: .operationTransfers
        )
        _ = await controller.emulate()
        XCTAssertTrue(controller.getModel().isSelectedFeeUnavailable)

        let result = await controller.sendTransaction()

        guard case .failure(.multichainTransactionFailure(.feeMethodUnavailable)) = result else { return XCTFail("Expected unavailable token refusal: \(result)") }
        XCTAssertEqual(relayer.sent, 0)
        let events = await session.events
        XCTAssertTrue(events.isEmpty)
    }

    func testEmulatedBatteryFeeAboveBalanceRemainsAPricedRefillableShortage() async throws {
        let session = BatteryPaymentTestSession()
        let relayer = RelayerStub()
        relayer.emulationFee = 19
        let controller = try makeBatteryMigrationController(session: session, relayer: relayer, chargesAfterMigration: 18)
        _ = await controller.emulate()

        let result = await controller.sendTransaction()

        guard case .failure(.multichainTransactionFailure(.insufficientSelectedFee)) = result else { return XCTFail("Expected a charge shortage: \(result)") }
        let battery = try XCTUnwrap(controller.getModel().extraOptions.first { $0.type == .battery })
        XCTAssertTrue(battery.isAvailable)
        XCTAssertTrue(battery.isInsufficient)
        XCTAssertFalse(controller.getModel().isSelectedFeeUnavailable)
        guard case .battery(charges: 19, excess: _) = battery.value else { return XCTFail("Expected the fresh charge price") }
        XCTAssertEqual(relayer.sent, 0)
    }

    func testCancelledTonEngineDoesNotChangeTheControllerToChainKitFallback() async throws {
        let delay = EmulationDelay()
        let chainKit = ChainKitServiceStub(review: nil)
        let controller = try makeController(
            asset: Self.tonJetton,
            recipient: Self.tonRecipient,
            chainKitService: chainKit,
            heldJetton: Self.heldJetton,
            beforeTonEmulate: { await delay.waitIfNeeded() }
        )
        try await pickTON(on: controller)
        await delay.holdNext()
        let stale = Task { await controller.emulate() }
        try await delay.entered.wait()
        stale.cancel()

        let fresh = Task { await controller.emulate() }
        await delay.release.open()
        _ = await fresh.value
        let result = await stale.value

        guard case .failure(.cancelledByUser) = result else { return XCTFail("Expected cancellation: \(result)") }
        let calls = await chainKit.calls.all
        XCTAssertTrue(calls.isEmpty, "A cancelled engine must not start the SDK fallback")
    }

    func testCancelledOldRefreshCannotReplaceANewerBatteryQuote() async throws {
        let delay = EmulationDelay()
        let session = BatteryPaymentTestSession()
        let relayer = RelayerStub()
        var chainKit = ChainKitServiceStub(review: nil)
        chainKit.beforeEmulate = { await delay.waitIfNeeded() }
        let controller = try makeBatteryMigrationController(session: session, relayer: relayer, chainKitService: chainKit)
        _ = await controller.emulate()
        controller.setPrefferedExtraType(extraType: .battery)
        controller.setLoading()
        await delay.holdNext()
        relayer.rejectsEstimate = true
        let stale = Task { await controller.emulate() }
        try await delay.entered.wait()
        stale.cancel()

        relayer.rejectsEstimate = false
        let fresh = Task { await controller.emulate() }
        await delay.release.open()
        _ = await fresh.value
        _ = await stale.value

        guard case let .extra(extra) = controller.getModel().extraState else { return XCTFail("Expected the newer quote") }
        XCTAssertEqual(extra.value.extraType, .battery)
        XCTAssertFalse(controller.getModel().isSelectedFeeUnavailable)
        XCTAssertFalse(controller.getModel().isSelectedFeeInsufficient)
    }

    func testMissingBatteryAfterMigrationNeverPaysWithTheNativeCoin() async throws {
        for mode in 0 ... 2 {
            let session = BatteryPaymentTestSession()
            let relayer = RelayerStub()
            let chainKit = ChainKitServiceStub(review: nil)
            let controller = try makeBatteryMigrationController(session: session, relayer: relayer, chainKitService: chainKit)
            _ = await controller.emulate()
            controller.setPrefferedExtraType(extraType: .battery)
            relayer.omitsBattery = mode == 0
            relayer.estimateFee = mode == 1 ? 0 : 18
            relayer.rejectsEstimate = mode == 2

            let result = await controller.sendTransaction()

            guard case .failure = result else { return XCTFail("An unavailable Battery must stop the send") }
            XCTAssertEqual(relayer.sent, 0)
            let calls = await chainKit.calls.all
            XCTAssertFalse(calls.contains(.sendMultichainTransfer))
            XCTAssertFalse(calls.contains(.sendOperationTransfer))
            XCTAssertTrue(controller.getModel().isSelectedFeeUnavailable)
            XCTAssertFalse(controller.getModel().isSelectedFeeInsufficient)
            guard case let .extra(extra) = controller.getModel().extraState else { return XCTFail("Expected unavailable Battery") }
            XCTAssertEqual(extra.value.extraType, .battery)
        }
    }

    func testUnavailableBatteryRefreshFinishesLoadingAndAllowsAnExplicitNativeChoice() async throws {
        for mode in 0 ... 2 {
            let session = BatteryPaymentTestSession()
            let relayer = RelayerStub()
            let controller = try makeBatteryMigrationController(session: session, relayer: relayer)
            _ = await controller.emulate()
            controller.setPrefferedExtraType(extraType: .battery)
            controller.setLoading()
            relayer.omitsBattery = mode == 0
            relayer.estimateFee = mode == 1 ? 0 : 18
            relayer.rejectsEstimate = mode == 2

            _ = await controller.emulate()

            guard case let .extra(extra) = controller.getModel().extraState else { return XCTFail("A failed estimate must not leave a skeleton") }
            XCTAssertEqual(extra.value.extraType, .battery)
            XCTAssertTrue(controller.getModel().isSelectedFeeUnavailable)
            XCTAssertFalse(controller.getModel().isSelectedFeeInsufficient)

            controller.setPrefferedExtraType(extraType: .multichain(token: Self.eth.asset))
            _ = await controller.emulate()
            guard case let .extra(native) = controller.getModel().extraState else { return XCTFail("Expected a native choice") }
            XCTAssertFalse(native.value.extraType.isBattery)
        }
    }

    func test_batterySendWaitsForMigrationAndSignsWithTheSameUnlock() async throws {
        let hold = TestGate()
        let session = BatteryPaymentTestSession(hold: hold)
        let relayer = RelayerStub(txHash: "relayed")
        relayer.available = { await session.migrated }
        relayer.onEmulate = { await session.record("emulate") }
        relayer.onSend = { await session.record("send") }
        let signing = RelayedOperationSignerStub(requestsPasscode: true, onSign: { await session.record("sign") })
        let controller = try makeBatteryMigrationController(session: session, relayer: relayer, signing: signing)
        _ = await controller.emulate()
        controller.setPrefferedExtraType(extraType: .battery)
        _ = await controller.emulate()
        XCTAssertFalse(controller.getModel().isSelectedFeeInsufficient)
        let task = Task { await controller.sendTransaction() }
        try await session.started.wait()

        XCTAssertEqual(relayer.sent, 0)
        let before = await session.events
        XCTAssertEqual(before, ["pin", "migration-start"])
        await hold.open()
        let result = await task.value

        guard case .success = result else { return XCTFail("Expected the first battery payment to succeed: \(result)") }
        let events = await session.events
        XCTAssertEqual(events, ["pin", "migration-start", "migration-complete", "emulate", "sign", "send"])
        XCTAssertEqual(relayer.sent, 1)
    }

    func test_failedBatteryMigrationDoesNotSignOrSend() async throws {
        let session = BatteryPaymentTestSession(fails: true)
        let relayer = RelayerStub()
        let controller = try makeBatteryMigrationController(session: session, relayer: relayer)
        _ = await controller.emulate()
        controller.setPrefferedExtraType(extraType: .battery)
        _ = await controller.emulate()

        let result = await controller.sendTransaction()

        guard case .failure(.multichainTransactionFailure(.batteryMigrationFailed)) = result else { return XCTFail("Expected migration failure") }
        XCTAssertEqual(relayer.sent, 0)
        let events = await session.events
        XCTAssertEqual(events, ["pin", "migration-start"])
    }

    func test_repricedBatteryFeeAboveConfirmationDoesNotSendAfterMigration() async throws {
        let session = BatteryPaymentTestSession()
        let relayer = RelayerStub()
        relayer.emulationFee = 19
        let controller = try makeBatteryMigrationController(session: session, relayer: relayer)
        _ = await controller.emulate()
        controller.setPrefferedExtraType(extraType: .battery)
        _ = await controller.emulate()

        let result = await controller.sendTransaction()

        guard case .failure = result else { return XCTFail("A higher fee requires another confirmation") }
        XCTAssertEqual(relayer.sent, 0)
        let events = await session.events
        XCTAssertEqual(events, ["pin", "migration-start", "migration-complete"])
    }

    func test_nativeSendDoesNotWaitForBatteryMigration() async throws {
        let controller = try makeController(
            asset: Self.eth,
            recipient: Self.ethRecipient,
            batteryPaymentPreparation: BatteryPaymentPreparation(needsMigration: { _ in
                XCTFail("A native fee must not request battery migration")
                return true
            })
        )
        _ = await controller.emulate()

        let result = await controller.sendTransaction()

        guard case .success = result else { return XCTFail("Expected the native transfer: \(result)") }
    }

    func testPostMigrationReviewAsksForConsentBeforeSigningWithoutAnotherPin() async throws {
        let session = BatteryPaymentTestSession()
        let relayer = RelayerStub()
        let signing = RelayedOperationSignerStub(requestsPasscode: true, onSign: { await session.record("sign") })
        let controller = try makeBatteryMigrationController(session: session, relayer: relayer, signing: signing, gate: OperationGate { [WarningCheck()] })
        _ = await controller.emulate()
        XCTAssertNil(controller.getModel().review)
        let user = ConsentingUser(answering: true, onAsk: { await session.record("review") })

        let result = await controller.sendTransaction(consent: user.attempt())

        guard case .success = result else { return XCTFail("Expected reviewed send: \(result)") }
        let asked = await user.asked
        XCTAssertEqual(asked.count, 1)
        let events = await session.events
        XCTAssertEqual(events, ["pin", "migration-start", "migration-complete", "review", "sign"])
    }

    func testInsufficientBatteryAfterMigrationKeepsTheConfirmedEVMMethod() async throws {
        let session = BatteryPaymentTestSession()
        let relayer = RelayerStub()
        let controller = try makeBatteryMigrationController(session: session, relayer: relayer, chargesAfterMigration: 0)
        _ = await controller.emulate()

        let result = await controller.sendTransaction()

        guard case .failure(.multichainTransactionFailure(.insufficientSelectedFee)) = result else { return XCTFail("Expected insufficient Battery: \(result)") }
        guard case let .extra(extra) = controller.getModel().extraState else { return XCTFail("Expected Battery") }
        XCTAssertEqual(extra.value.extraType, .battery)
        XCTAssertTrue(controller.getModel().isSelectedFeeInsufficient)
        XCTAssertEqual(relayer.sent, 0)

        controller.setLoading()
        _ = await controller.emulate()
        guard case let .extra(refreshed) = controller.getModel().extraState else { return XCTFail("Expected Battery after refresh") }
        XCTAssertEqual(refreshed.value.extraType, .battery)
        XCTAssertTrue(controller.getModel().isSelectedFeeInsufficient)
    }

    func testFundedMultichainBatterySendUsesOneOrdinaryPinWithoutLegacyServices() async throws {
        let session = BatteryPaymentTestSession(fails: true)
        let relayer = RelayerStub()
        let signing = RelayedOperationSignerStub(requestsPasscode: true, onSign: { await session.record("sign") })
        let controller = try makeBatteryMigrationController(session: session, relayer: relayer, signing: signing, currentChargesBeforeMigration: 18)
        _ = await controller.emulate()

        let result = await controller.sendTransaction()

        guard case .success = result else { return XCTFail("Expected funded send without migration: \(result)") }
        let events = await session.events
        XCTAssertEqual(events, ["pin", "sign"])
        XCTAssertEqual(relayer.sent, 1)
    }

    func testTronRechecksActualBatteryBalanceAfterMigrationAndKeepsSelection() async throws {
        let session = BatteryPaymentTestSession()
        let battery = batteryService(estimatedCharges: 18, balance: .empty)
        let controller = try await makeController(
            asset: Self.tronUSDT,
            recipient: Self.tronRecipient,
            tronUsdtApi: pricedTronUsdtApi(batteryService: battery),
            offersBatteryMigration: { _ in !(await session.migrated) },
            batteryPaymentPreparation: BatteryPaymentPreparation(needsMigration: { _ in true }, migrate: { _, code in try await session.migrate(code) }),
            trxOnlyRegion: false,
            batteryService: battery
        )
        controller.tronSignHandler = { _, _ async throws(TronTransferSignError) -> TronSwift.SignedTxID in
            XCTFail("Insufficient Battery must stop before signing")
            throw .cancelled
        }
        _ = await controller.emulate()
        XCTAssertFalse(controller.getModel().isSelectedFeeInsufficient)

        let result = await controller.sendTransaction()

        guard case .failure(.multichainTransactionFailure(.insufficientSelectedFee)) = result else { return XCTFail("Expected insufficient Battery: \(result)") }
        XCTAssertTrue(controller.getModel().isSelectedFeeInsufficient)
        guard case let .extra(extra) = controller.getModel().extraState else { return XCTFail("Expected Battery") }
        XCTAssertEqual(extra.value.extraType, .battery)
    }

    @MainActor
    func test_tronBatterySendHandsTheUnlockedPasscodeToNativeSigningAndClearsIt() async throws {
        let session = BatteryPaymentTestSession()
        let controller = try await makeController(
            asset: Self.tronUSDT,
            recipient: Self.tronRecipient,
            signer: .mnemonic(passcodeProvider: { await session.passcode() }),
            tronUsdtApi: pricedTronUsdtApi(),
            offersBatteryMigration: { _ in !(await session.migrated) },
            batteryPaymentPreparation: BatteryPaymentPreparation(needsMigration: { _ in true }, migrate: { _, code in try await session.migrate(code) }),
            trxOnlyRegion: false
        )
        var handed: String?
        var handoffs = [String?]()
        controller.batteryPasscodeHandoff = { code in
            handed = code
            handoffs.append(code)
        }
        controller.tronSignHandler = { _, _ in
            let code = await MainActor.run { handed }
            XCTAssertEqual(code, "1234")
            await session.record("sign")
            return Data(repeating: 1, count: 65)
        }
        _ = await controller.emulate()
        controller.setPrefferedExtraType(extraType: .battery)
        _ = await controller.emulate()
        guard case let .extra(extra) = controller.getModel().extraState, extra.value.extraType == .battery else {
            return XCTFail("Expected Battery selected before the migration: \(controller.getModel().extraState)")
        }

        let result = await controller.sendTransaction()

        guard case .success = result else { return XCTFail("Expected the Battery transfer: \(result)") }
        XCTAssertEqual(handoffs, ["1234", nil])
        XCTAssertNil(handed)
        let events = await session.events
        XCTAssertEqual(events, ["pin", "migration-start", "migration-complete", "sign"])
    }

    private func makeBatteryMigrationController(
        session: BatteryPaymentTestSession,
        relayer: RelayerStub,
        signing: MultichainRelayedOperationSigner = RelayedOperationSignerStub(),
        gate: OperationGate = OperationGate { [] },
        chargesAfterMigration: Int = 100,
        currentChargesBeforeMigration: Int = 0,
        chainKitService: ChainKitService = ChainKitServiceStub(review: nil)
    ) throws -> MultichainTransactionConfirmationController {
        let offers: (Wallet) async -> Bool = { _ in !(await session.migrated) }
        return try makeController(
            asset: Self.usdt,
            recipient: Self.ethRecipient,
            amount: 1_000_000,
            signer: .mnemonic(passcodeProvider: { await session.passcode() }),
            chainKitService: chainKitService,
            relayedEVMChains: [.eth],
            evmGaslessFeeEngine: EVMGaslessFeeEngine(
                relayer: relayer,
                signer: signing,
                isEnabled: { _ in true },
                batteryCharges: { _ in await session.migrated ? .available(chargesAfterMigration) : .unknown },
                walletTokens: { _, _ in [:] },
                gate: gate,
                currentBatteryCharges: { _ in await session.migrated ? .available(chargesAfterMigration) : .available(currentChargesBeforeMigration) },
                offersBatteryMigration: offers
            ),
            offersBatteryMigration: offers,
            batteryPaymentPreparation: BatteryPaymentPreparation(
                needsMigration: offers,
                migrate: { _, code in try await session.migrate(code) },
                currentCharges: { _ in .available(currentChargesBeforeMigration) }
            )
        )
    }

    private static let ethRecipient = "0x8ba1f109551bd432803012645ac136ddd64dba72"
    private static let tronSender = "TVdW9qX4kyXb9jFoUwXJswtEqKHdn85AVd"
    private static let tronRecipient = "TU1r33n75FL5dShBt13xcJfgBLuahLgTZo"
    private static let tonRecipient = "0:0000000000000000000000000000000000000000000000000000000000000001"
    private static let tonAddress = "UQBcmqkZxhc81WNeFFzq9ZX6qBlP28B-MuYeSxpS_-YMIDNl"
    /// The 10 USDT or 10 TRX the TRON node stub builds a transfer of.
    private static let amount: BigUInt = 10_000_000
    private static let review = OperationReview(
        id: "transfer",
        findings: [OperationFinding(id: "finding", kind: "StubWarning", severity: .warning, title: "Finding")]
    )

    private let calls = TronSwapCalls()

    override func setUpWithError() throws {
        try super.setUpWithError()
        TronNodeStub.calls = calls
        TronNodeStub.owner = try TronSwift.Address(address: Self.tronSender).raw
        TronNodeStub.deposit = try TronSwift.Address(address: Self.tronRecipient).raw
    }

    override func tearDown() {
        TronNodeStub.calls = nil
        super.tearDown()
    }

    /// The transfer ChainKit priced is what the swipe asks about, and the send ChainKit signs is
    /// cleared with that swipe's consent: what it accepted is not asked again.
    func test_aChainKitSendIsClearedWithTheConsentOfTheSwipe() async throws {
        let controller = try makeController(asset: Self.eth, recipient: Self.ethRecipient, chainKitService: ChainKitServiceStub(review: Self.review))
        _ = await controller.emulate()
        let user = ConsentingUser(answering: true)
        let consent = user.attempt()
        _ = try await consent(XCTUnwrap(controller.getModel().review))

        let result = await controller.sendTransaction(consent: consent)

        guard case .success = result else {
            return XCTFail("expected the transfer to go out, got \(result)")
        }
        let asked = await user.asked
        XCTAssertEqual(asked, [Self.review])
    }

    func test_aChainKitSendWithoutTheConsentOfASwipeRefusesWhatNeedsIt() async throws {
        let controller = try makeController(asset: Self.eth, recipient: Self.ethRecipient, chainKitService: ChainKitServiceStub(review: Self.review))
        _ = await controller.emulate()

        let result = await controller.sendTransaction()

        guard case .failure(.cancelledByUser) = result else {
            return XCTFail("expected a cancellation, got \(result)")
        }
    }

    /// The relayer's operation the quote priced is what the swipe asks about, and the one the relayed
    /// send signs is cleared with that swipe's consent.
    func test_aRelayedEVMSendIsClearedWithTheConsentOfTheSwipe() async throws {
        let relayer = RelayerStub()
        let gate = OperationGate { [WarningCheck()] }
        let controller = try makeController(
            asset: Self.usdt,
            recipient: Self.ethRecipient,
            amount: 1_000_000,
            relayedEVMChains: [.eth],
            evmGaslessFeeEngine: EVMGaslessFeeEngine(
                relayer: relayer,
                signer: RelayedOperationSignerStub(),
                isEnabled: { _ in true },
                batteryCharges: { _ in .available(100) },
                walletTokens: { _, _ in [:] },
                gate: gate
            ),
            gate: gate
        )
        _ = await controller.emulate()
        let user = ConsentingUser(answering: true)
        let consent = user.attempt()
        let review = try XCTUnwrap(controller.getModel().review)
        _ = await consent(review)

        let result = await controller.sendTransaction(consent: consent)

        guard case .success = result else {
            return XCTFail("expected the transfer to go out, got \(result)")
        }
        let asked = await user.asked
        XCTAssertEqual(asked, [review])
        XCTAssertEqual(relayer.sent, 1)
    }

    /// A relayed transfer is recorded by the relayer's transaction, as a broadcast is: it shows as pending
    /// and gets its Live Activity.
    func test_aRelayedEVMSendRecordsTheRelayersTransaction() async throws {
        for txHash in ["0xrelayed", nil] {
            let relayer = RelayerStub(txHash: txHash)
            let gate = OperationGate { [WarningCheck()] }
            let controller = try makeController(
                asset: Self.usdt,
                recipient: Self.ethRecipient,
                amount: 1_000_000,
                relayedEVMChains: [.eth],
                evmGaslessFeeEngine: EVMGaslessFeeEngine(
                    relayer: relayer,
                    signer: RelayedOperationSignerStub(),
                    isEnabled: { _ in true },
                    batteryCharges: { _ in .available(100) },
                    walletTokens: { _, _ in [:] },
                    gate: gate
                ),
                gate: gate
            )
            _ = await controller.emulate()

            let result = await controller.sendTransaction(consent: ConsentingUser(answering: true).attempt())

            guard case let .success(sent) = result else {
                return XCTFail("expected the transfer to go out, got \(result)")
            }
            let expected: TransactionConfirmationSendResult = try txHash.map {
                try .chain(XCTUnwrap(Self.usdt.asset.chain), wallet: multichainWallet(), txHashes: [$0], activityType: .send)
            } ?? .nothingToRecord
            XCTAssertEqual(sent, expected)
        }
    }

    /// TRON USDT has no preview: the controller's send is asked at the gate, once the node built the
    /// transaction, with the consent it is handed.
    func test_aTronSendIsClearedWithTheConsentItIsHanded() async throws {
        let controller = try await makeController(asset: Self.tronUSDT, recipient: Self.tronRecipient, gate: OperationGate { [WarningCheck()] }, tronUsdtApi: pricedTronUsdtApi(), trxOnlyRegion: false)
        controller.tronSignHandler = { _, _ in Data(repeating: 1, count: 65) }
        _ = await controller.emulate()
        let user = ConsentingUser(answering: true)

        let result = await controller.sendTransaction(consent: user.attempt())

        guard case .success = result else {
            return XCTFail("expected the transfer to go out, got \(result)")
        }
        let asked = await user.asked
        XCTAssertEqual(asked.count, 1)
        XCTAssertEqual(calls.relayed.count, 1)
    }

    func test_aTronSendWithoutTheConsentOfASwipeRefusesWhatNeedsIt() async throws {
        let controller = try await makeController(asset: Self.tronUSDT, recipient: Self.tronRecipient, gate: OperationGate { [WarningCheck()] }, tronUsdtApi: pricedTronUsdtApi(), trxOnlyRegion: false)
        controller.tronSignHandler = { _, _ in Data(repeating: 1, count: 65) }
        _ = await controller.emulate()

        let result = await controller.sendTransaction()

        guard case .failure(.cancelledByUser) = result else {
            return XCTFail("expected a cancellation, got \(result)")
        }
        XCTAssertTrue(calls.relayed.isEmpty)
    }

    /// A TON engine signs what it is handed through the gate, which reads it from the wallet's TON
    /// account beside the signature; the TRON engine gets the App's signer as it is, its instant fee
    /// having a gate of its own.
    func test_aTonEngineSignsThroughTheGateAndTheTronEngineDoesNot() async throws {
        let check = WarningCheck()
        let log = RecordedLog()
        defer { log.stop() }
        let wallet = multichainWallet()
        let controller = try makeController(asset: Self.ton, recipient: Self.tonRecipient, gate: OperationGate { [check] })
        let signed = SignedRequests()
        controller.signHandler = { _, _ in
            await signed.count()
            return ["signed"]
        }
        let request = try tonTransfer(from: wallet)
        // Bound by `guard`: a generic like XCTUnwrap needs the iOS 18 runtime for a typed-throws function.
        guard let signTron = try controller.gatedSignHandler(for: tronEngine(wallet: wallet)),
              let signTon = controller.gatedSignHandler(for: TonEngineStub(wallet: wallet))
        else {
            return XCTFail("expected both engines to be handed a signer")
        }

        _ = try await signTron(request, wallet)
        let readForTron = await check.reads.all
        _ = try await signTon(request, wallet)
        let logged = try await log.record("Operation review found what would ask in a flow it only logs")

        XCTAssertTrue(readForTron.isEmpty)
        XCTAssertNotNil(logged)
        let ton = try ChainKitOperationSender.account(wallet: wallet, chain: .ton, holding: Self.ton.asset)
        let reads = await check.reads.all
        XCTAssertEqual(reads, [WarningCheck.Read(
            address: ton.addressDisplay.lowercased(),
            assetId: ton.asset.id,
            intent: .send(Self.amount, of: Self.ton.asset, to: Self.tonRecipient)
        )])
        let signatures = await signed.all
        XCTAssertEqual(signatures, 2)
    }

    /// While the flag is on, a mnemonic's own send of what ChainKit signs, bitcoin aside, is priced as
    /// chain-kit's operation for it, and that operation is what the send signs: its hash is the send's.
    func test_whileOperationTransfersAreOnAMnemonicsSendSignsTheOperationItWasPricedAs() async throws {
        let sends = [
            (Self.eth, Self.ethRecipient),
            (Self.usdt, Self.ethRecipient),
            (Self.trx, Self.tronRecipient),
            (Self.sol, Self.solRecipient),
            (Self.ton, Self.tonRecipient),
        ]
        for (asset, recipient) in sends {
            let chainKit = try await ChainKitServiceStub(review: nil, operation: pricedOperation())
            let controller = try makeController(asset: asset, recipient: recipient, chainKitService: chainKit, flags: .operationTransfers)
            _ = await controller.emulate()

            let result = await controller.sendTransaction(consent: ConsentingUser(answering: true).attempt())

            guard case let .success(sent) = result else {
                return XCTFail("expected \(asset.asset.assetId) to go out, got \(result)")
            }
            XCTAssertEqual(sent, try .chain(XCTUnwrap(asset.asset.chain), wallet: multichainWallet(), txHashes: ["0xoperation"], activityType: .send))
            let calls = await chainKit.calls.all
            XCTAssertEqual(calls, [.emulateOperationTransfer, .sendOperationTransfer], asset.asset.assetId)
        }
    }

    /// The operation the transfer was priced as is what the swipe asks about, and the send clears it
    /// with that swipe's consent.
    func test_anOperationTransferIsClearedWithTheConsentOfTheSwipe() async throws {
        let chainKit = try await ChainKitServiceStub(review: Self.review, operation: pricedOperation())
        let controller = try makeController(asset: Self.eth, recipient: Self.ethRecipient, chainKitService: chainKit, flags: .operationTransfers)
        _ = await controller.emulate()
        let user = ConsentingUser(answering: true)
        let consent = user.attempt()
        _ = try await consent(XCTUnwrap(controller.getModel().review))

        let result = await controller.sendTransaction(consent: consent)

        guard case .success = result else {
            return XCTFail("expected the transfer to go out, got \(result)")
        }
        let asked = await user.asked
        XCTAssertEqual(asked, [Self.review])
        let calls = await chainKit.calls.all
        XCTAssertEqual(calls, [.emulateOperationTransfer, .sendOperationTransfer])
    }

    /// A Ledger signs on its device, bitcoin's memo is signed only by the SDK, and a TON jetton reaches
    /// ChainKit only when its TON engine fails it: while the flag is on, the SDK still prices and signs
    /// each of them.
    func test_whileOperationTransfersAreOnALedgerBitcoinAndATonJettonKeepTheSDK() async throws {
        let mnemonic = MultichainTransferSigner.mnemonic(passcodeProvider: { "1234" })
        let sends = [
            (Self.eth, Self.ethRecipient, ledgerWallet(), MultichainTransferSigner.device(refusingDevice())),
            (Self.btc, Self.btcRecipient, multichainWallet(), mnemonic),
            (Self.tonJetton, Self.tonRecipient, multichainWallet(), mnemonic),
        ]
        for (asset, recipient, wallet, signer) in sends {
            let chainKit = try await ChainKitServiceStub(review: nil, operation: pricedOperation())
            let controller = try makeController(
                asset: asset,
                recipient: recipient,
                wallet: wallet,
                signer: signer,
                chainKitService: chainKit,
                flags: .operationTransfers
            )
            _ = await controller.emulate()

            let result = await controller.sendTransaction(consent: ConsentingUser(answering: true).attempt())

            guard case let .success(sent) = result else {
                return XCTFail("expected \(asset.asset.assetId) to go out, got \(result)")
            }
            XCTAssertEqual(sent.pendingTransactions.map(\.txHash), ["0xsent"], asset.asset.assetId)
            let calls = await chainKit.calls.all
            XCTAssertEqual(calls, [.emulateTransaction, .sendMultichainTransfer], asset.asset.assetId)
        }
    }

    /// TRX pays TRON USDT as chain-kit's operation while the flag is on: priced beside the engine's
    /// methods, shown at chain-kit's fee and signed as that operation, which the node never builds.
    func test_whileOperationTransfersAreOnTRXPaysTronUSDTAsChainKitsOperation() async throws {
        let chainKit = try await ChainKitServiceStub(review: nil, operation: pricedOperation())
        let controller = try await makeController(
            asset: Self.tronUSDT,
            recipient: Self.tronRecipient,
            chainKitService: chainKit,
            flags: .operationTransfers,
            tronUsdtApi: pricedTronUsdtApi()
        )
        controller.tronSignHandler = { _, _ in Data(repeating: 1, count: 65) }
        try await pickTRX(on: controller)

        let model = controller.getModel()
        let built = calls.recorded.filter { $0 == "/wallet/triggersmartcontract" }.count
        let result = await controller.sendTransaction(consent: ConsentingUser(answering: true).attempt())

        guard case .success = result else {
            return XCTFail("expected the transfer to go out, got \(result)")
        }
        let trx = try XCTUnwrap(model.extraOptions.first { $0.type.isTRXGasless })
        guard case let .gasless(_, listed) = trx.value, case let .extra(extra) = model.extraState, case let .gasless(_, shown) = extra.value else {
            return XCTFail("expected TRX listed and selected, got \(model.extraOptions) \(model.extraState)")
        }
        XCTAssertEqual(listed, 21000, "listed at chain-kit's fee")
        XCTAssertEqual(shown, 21000, "selected at chain-kit's fee")
        let chainKitCalls = await chainKit.calls.all
        XCTAssertEqual(chainKitCalls.last, .sendOperationTransfer)
        XCTAssertEqual(Set(chainKitCalls.dropLast()), [.emulateOperationTransfer])
        XCTAssertTrue(calls.relayed.isEmpty)
        XCTAssertEqual(calls.recorded.filter { $0 == "/wallet/triggersmartcontract" }.count, built, "the node built nothing to send")
    }

    /// With the flag off TRX pays TRON USDT through its engine, as before: the node builds the transfer.
    func test_whileOperationTransfersAreOffTRXKeepsTronUSDTsEngine() async throws {
        let chainKit = try await ChainKitServiceStub(review: nil, operation: pricedOperation())
        let controller = try await makeController(asset: Self.tronUSDT, recipient: Self.tronRecipient, chainKitService: chainKit, tronUsdtApi: pricedTronUsdtApi())
        controller.tronSignHandler = { _, _ in Data(repeating: 1, count: 65) }
        try await pickTRX(on: controller)
        // The node refuses to build it: the engine's own send stops there, before anything is broadcast.
        TronNodeStub.refusesTransaction = true
        defer { TronNodeStub.refusesTransaction = false }

        _ = await controller.sendTransaction(consent: ConsentingUser(answering: true).attempt())

        let chainKitCalls = await chainKit.calls.all
        XCTAssertEqual(chainKitCalls, [])
        XCTAssertTrue(calls.recorded.contains("/wallet/triggersmartcontract"), "the engine asked the node to build the transfer")
    }

    /// TRX that chain-kit prices no operation for leaves the list: where TRX is the one method, nothing is
    /// left to pay with, and the transfer is not priced.
    func test_aTRXOptionChainKitCannotPriceIsLeftOut() async throws {
        var chainKit = ChainKitServiceStub(review: nil)
        chainKit.failsOperationPricing = true
        let controller = try await makeController(
            asset: Self.tronUSDT,
            recipient: Self.tronRecipient,
            chainKitService: chainKit,
            flags: .operationTransfers,
            tronUsdtApi: pricedTronUsdtApi()
        )

        let result = await controller.emulate()

        guard case .failure(.multichainTransactionFailure(.emulationFailure)) = result else {
            return XCTFail("expected no method left to price the transfer with, got \(result)")
        }
        XCTAssertFalse(controller.getModel().extraOptions.contains { $0.type.isTRXGasless })
        let chainKitCalls = await chainKit.calls.all
        XCTAssertEqual(chainKitCalls, [.emulateOperationTransfer])
    }

    /// TON pays a TON jetton as chain-kit's operation while the flag is on: priced beside the engine's
    /// methods with the comment on screen, shown at chain-kit's fee and signed as that very operation, so
    /// the comment the user typed is the one that goes out.
    func test_whileOperationTransfersAreOnTONPaysATonJettonAsChainKitsOperation() async throws {
        let chainKit = try await ChainKitServiceStub(review: nil, operation: pricedOperation())
        let controller = try makeController(
            asset: Self.tonJetton,
            recipient: Self.tonRecipient,
            comment: "invoice 7",
            chainKitService: chainKit,
            flags: .operationTransfers,
            heldJetton: Self.heldJetton
        )
        try await pickTON(on: controller)

        let model = controller.getModel()
        let result = await controller.sendTransaction(consent: ConsentingUser(answering: true).attempt())

        guard case let .success(sent) = result else {
            return XCTFail("expected the jetton to go out, got \(result)")
        }
        XCTAssertEqual(sent, .chain(.ton, wallet: multichainWallet(), txHashes: ["0xoperation"], activityType: .send))
        guard case let .extra(extra) = model.extraState, case let .default(shown) = extra.value else {
            return XCTFail("expected TON selected, got \(model.extraState)")
        }
        XCTAssertEqual(shown, 21000, "selected at chain-kit's fee")
        XCTAssertTrue(model.availableExtraTypes.contains(.default))
        let chainKitCalls = await chainKit.calls.all
        XCTAssertEqual(chainKitCalls.last, .sendOperationTransfer)
        XCTAssertEqual(Set(chainKitCalls.dropLast()), [.emulateOperationTransfer])
        let comments = await chainKit.calls.comments
        XCTAssertEqual(Set(comments), ["invoice 7"], "the operation is priced and signed with the comment on screen")
    }

    /// With the flag off TON pays a TON jetton through its engine, as before: ChainKit prices nothing and
    /// TON is shown at the engine's emulated fee.
    func test_whileOperationTransfersAreOffTONKeepsATonJettonsEngine() async throws {
        let chainKit = try await ChainKitServiceStub(review: nil, operation: pricedOperation())
        let controller = try makeController(
            asset: Self.tonJetton,
            recipient: Self.tonRecipient,
            comment: "invoice 7",
            chainKitService: chainKit,
            heldJetton: Self.heldJetton
        )
        try await pickTON(on: controller)

        guard case let .extra(extra) = controller.getModel().extraState, case let .default(shown) = extra.value else {
            return XCTFail("expected TON selected, got \(controller.getModel().extraState)")
        }
        XCTAssertEqual(shown, TonEmulatingSend.fee, "selected at the engine's fee")
        let chainKitCalls = await chainKit.calls.all
        XCTAssertEqual(chainKitCalls, [])
    }

    /// TON that chain-kit prices no operation for is not offered for a TON jetton: the picker lists only
    /// the methods left to pay with.
    func test_aTONOptionChainKitCannotPriceIsNotOffered() async throws {
        var chainKit = ChainKitServiceStub(review: nil)
        chainKit.failsOperationPricing = true
        let controller = try makeController(
            asset: Self.tonJetton,
            recipient: Self.tonRecipient,
            chainKitService: chainKit,
            flags: .operationTransfers,
            heldJetton: Self.heldJetton
        )

        _ = await controller.emulate()

        let model = controller.getModel()
        XCTAssertFalse(model.availableExtraTypes.contains(.default), "offered: \(model.availableExtraTypes)")
        XCTAssertFalse(model.extraOptions.contains { $0.type == .default })
    }

    /// Charges pay TRON USDT through its own engine while the flag is on, without an SDK send.
    func test_whileOperationTransfersAreOnTronUSDTKeepsItsEngine() async throws {
        let chainKit = ChainKitServiceStub(review: nil)
        let controller = try await makeController(asset: Self.tronUSDT, recipient: Self.tronRecipient, chainKitService: chainKit, flags: .operationTransfers, tronUsdtApi: pricedTronUsdtApi(), trxOnlyRegion: false)
        controller.tronSignHandler = { _, _ in Data(repeating: 1, count: 65) }
        _ = await controller.emulate()
        let pricingCalls = await chainKit.calls.all

        let result = await controller.sendTransaction(consent: ConsentingUser(answering: true).attempt())

        guard case .success = result else {
            return XCTFail("expected the transfer to go out, got \(result)")
        }
        XCTAssertEqual(calls.relayed.count, 1)
        let chainKitCalls = await chainKit.calls.all
        XCTAssertEqual(chainKitCalls, pricingCalls)
    }

    /// TRON USDT that its engine leaves to ChainKit is priced and signed by the SDK, as before the flag:
    /// only a send on the ChainKit engine itself is signed as chain-kit's operation.
    func test_whileOperationTransfersAreOnTronUSDTItsEngineLeftToChainKitKeepsTheSDK() async throws {
        let chainKit = try await ChainKitServiceStub(review: nil, operation: pricedOperation())
        // No TRON engine is built for a recipient TronSwift cannot read, so the send falls back to ChainKit.
        let controller = try makeController(asset: Self.tronUSDT, recipient: "not-a-tron-address", chainKitService: chainKit, flags: .operationTransfers)
        _ = await controller.emulate()

        let result = await controller.sendTransaction(consent: ConsentingUser(answering: true).attempt())

        guard case .success = result else {
            return XCTFail("expected the transfer to go out, got \(result)")
        }
        XCTAssertTrue(calls.relayed.isEmpty)
        let chainKitCalls = await chainKit.calls.all
        XCTAssertEqual(chainKitCalls, [.emulateTransaction, .sendMultichainTransfer])
    }

    /// chain-kit's reserve keeps nothing back for Base's L1 fee, which moves with every L1 block: a whole
    /// Base balance is still priced and signed by the SDK after the passcode, any other Base send as the
    /// operation.
    func test_whileOperationTransfersAreOnAWholeBaseBalanceKeepsTheSDK() async throws {
        for isMaxAmount in [true, false] {
            let chainKit = try await ChainKitServiceStub(review: nil, operation: pricedOperation())
            let controller = try makeController(
                asset: Self.baseETH,
                recipient: Self.ethRecipient,
                isMaxAmount: isMaxAmount,
                chainKitService: chainKit,
                flags: .operationTransfers
            )
            _ = await controller.emulate()

            let result = await controller.sendTransaction(consent: ConsentingUser(answering: true).attempt())

            guard case .success = result else {
                return XCTFail("expected the transfer to go out, got \(result)")
            }
            let calls = await chainKit.calls.all
            let expected: [ChainKitServiceStub.Call] = isMaxAmount
                ? [.emulateTransaction, .sendMultichainTransfer]
                : [.emulateOperationTransfer, .sendOperationTransfer]
            XCTAssertEqual(calls, expected, "max: \(isMaxAmount)")
        }
    }

    /// An operation the gas reserve found short of its fee stops at the shortage: ChainKit is never asked
    /// to sign it.
    func test_anOperationTransferShortOfItsFeeIsNotSent() async throws {
        let chainKit = try await ChainKitServiceStub(review: nil, operation: pricedOperation(), isInsufficientBalance: true)
        let controller = try makeController(asset: Self.eth, recipient: Self.ethRecipient, chainKitService: chainKit, flags: .operationTransfers)
        _ = await controller.emulate()

        let result = await controller.sendTransaction(consent: ConsentingUser(answering: true).attempt())

        guard case .failure(.multichainTransactionFailure(.insufficientSelectedFee)) = result else {
            return XCTFail("expected the shortage, got \(result)")
        }
        let calls = await chainKit.calls.all
        XCTAssertEqual(calls, [.emulateOperationTransfer])
    }

    /// The comment typed is the one the operation is priced and signed with.
    func test_anOperationTransferIsPricedWithTheCommentTyped() async throws {
        let chainKit = try await ChainKitServiceStub(review: nil, operation: pricedOperation())
        let controller = try makeController(
            asset: Self.ton,
            recipient: Self.tonRecipient,
            comment: "deposit 42",
            chainKitService: chainKit,
            flags: .operationTransfers
        )

        _ = await controller.emulate()

        let calls = await chainKit.calls.all
        XCTAssertEqual(calls, [.emulateOperationTransfer])
        let comments = await chainKit.calls.comments
        XCTAssertEqual(comments, ["deposit 42"])
    }

    /// The key the recipient reads an encrypted comment with reaches chain-kit with the comment, on the
    /// operation's path and on the SDK's: the operation is priced with the comment encrypted to it and
    /// carries it to the send, the SDK is handed it again to send.
    func test_aCommentsEncryptionKeyReachesChainKit() async throws {
        let paths: [(flags: ReviewFlags, keys: [String?])] = [
            (.operationTransfers, ["ab"]),
            (ReviewFlags(), ["ab", "ab"]),
        ]
        for (flags, expected) in paths {
            let chainKit = try await ChainKitServiceStub(review: nil, operation: pricedOperation())
            let controller = try makeController(
                asset: Self.ton,
                recipient: Self.tonRecipient,
                comment: "deposit 42",
                commentEncryptionKey: "ab",
                chainKitService: chainKit,
                flags: flags
            )
            _ = await controller.emulate()

            let result = await controller.sendTransaction(consent: ConsentingUser(answering: true).attempt())

            guard case .success = result else {
                return XCTFail("expected the transfer to go out, got \(result)")
            }
            let keys = await chainKit.calls.keys
            XCTAssertEqual(keys, expected)
        }
    }

    /// The confirmation says the comment goes encrypted only when chain-kit encrypts it: a blank comment
    /// or an empty key would go as it is.
    func test_theConfirmationSaysACommentGoesEncryptedOnlyWhenItDoes() throws {
        let cases: [(comment: String?, key: String?, isEncrypted: Bool)] = [
            ("deposit 42", "ab", true),
            ("deposit 42", "", false),
            ("deposit 42", nil, false),
            (" \n ", "ab", false),
            (nil, "ab", false),
        ]
        for (comment, key, isEncrypted) in cases {
            let controller = try makeController(asset: Self.ton, recipient: Self.tonRecipient, comment: comment, commentEncryptionKey: key)

            XCTAssertEqual(controller.getModel().isCommentEncrypted, isEncrypted, "\(String(describing: comment)) to \(String(describing: key))")
        }
    }

    /// A send the relayer pays for is relayed while the flag is on: only the chain's own fee, the
    /// method beside the relayer's, is priced as chain-kit's operation.
    func test_whileOperationTransfersAreOnARelayedSendKeepsTheRelayer() async throws {
        let relayer = RelayerStub()
        let chainKit = try await ChainKitServiceStub(review: nil, operation: pricedOperation())
        let controller = try makeController(
            asset: Self.usdt,
            recipient: Self.ethRecipient,
            amount: 1_000_000,
            chainKitService: chainKit,
            relayedEVMChains: [.eth],
            evmGaslessFeeEngine: EVMGaslessFeeEngine(
                relayer: relayer,
                signer: RelayedOperationSignerStub(),
                isEnabled: { _ in true },
                batteryCharges: { _ in .available(100) },
                walletTokens: { _, _ in [:] },
                gate: OperationGate { [] }
            ),
            flags: .operationTransfers
        )
        _ = await controller.emulate()

        let result = await controller.sendTransaction(consent: ConsentingUser(answering: true).attempt())

        guard case .success = result else {
            return XCTFail("expected the transfer to go out, got \(result)")
        }
        XCTAssertEqual(relayer.sent, 1)
        let calls = await chainKit.calls.all
        XCTAssertEqual(calls, [.emulateOperationTransfer])
    }

    /// With the flag off a mnemonic's send is the SDK's, priced and signed as before.
    func test_whileOperationTransfersAreOffAMnemonicsSendIsTheSDKs() async throws {
        let chainKit = try await ChainKitServiceStub(review: nil, operation: pricedOperation())
        let controller = try makeController(asset: Self.eth, recipient: Self.ethRecipient, chainKitService: chainKit)
        _ = await controller.emulate()

        let result = await controller.sendTransaction(consent: ConsentingUser(answering: true).attempt())

        guard case let .success(sent) = result else {
            return XCTFail("expected the transfer to go out, got \(result)")
        }
        XCTAssertEqual(sent.pendingTransactions.map(\.txHash), ["0xsent"])
        let calls = await chainKit.calls.all
        XCTAssertEqual(calls, [.emulateTransaction, .sendMultichainTransfer])
    }
}

private actor EmulationDelay {
    let entered = TestGate()
    let release = TestGate()
    private var holdsNext = false

    func holdNext() {
        holdsNext = true
    }

    func waitIfNeeded() async {
        guard holdsNext else { return }
        holdsNext = false
        await entered.open()
        await Task { try? await release.wait() }.value
    }
}

private extension MultichainSendConsentTests {
    static let eth = asset("eth/mainnet/coin", name: "Ethereum", symbol: "ETH", decimals: 18, balance: 1_000_000_000_000_000_000)
    static let baseETH = asset("base/mainnet/coin", name: "Ether", symbol: "ETH", decimals: 18, balance: 1_000_000_000_000_000_000)
    static let usdt = asset(GaslessFixtures.usdtId, name: "Tether", symbol: "USDT", decimals: 6, balance: 2_006_121)
    static let tronUSDT = asset("tron/mainnet/trc20/\(USDT.address.base58)", name: USDT.name, symbol: USDT.symbol, decimals: 6, balance: 100_000_000)
    static let ton = asset("ton/mainnet/coin", name: "Toncoin", symbol: "TON", decimals: 9, balance: 5_000_000_000)
    static let tonJetton = asset(
        "ton/mainnet/jetton/0:0000000000000000000000000000000000000000000000000000000000000002",
        name: "Jetton",
        symbol: "JET",
        decimals: 9,
        balance: 5_000_000_000
    )
    static let trx = asset("tron/mainnet/coin", name: "Tron", symbol: "TRX", decimals: 6, balance: 100_000_000)
    static let sol = asset("sol/mainnet/coin", name: "Solana", symbol: "SOL", decimals: 9, balance: 5_000_000_000)
    static let btc = asset("btc/mainnet/coin", name: "Bitcoin", symbol: "BTC", decimals: 8, balance: 100_000_000)
    static let solRecipient = "EN2sCsJ1WDV8UFqsiTXHcUPUxQ4juE71eCknHYYMifkd"
    /// `tonJetton` as the wallet holds it, with no payload of its own, in a jetton wallet of its own.
    static let heldJetton = JettonItem(
        jettonInfo: JettonInfo(
            isTransferable: true,
            hasCustomPayload: false,
            address: try! TonSwift.Address.parse("0:0000000000000000000000000000000000000000000000000000000000000002"),
            fractionDigits: 9,
            name: "Jetton",
            symbol: "JET",
            verification: .whitelist,
            imageURL: nil
        ),
        walletAddress: try! TonSwift.Address.parse("0:0000000000000000000000000000000000000000000000000000000000000006")
    )
    static let btcRecipient = "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4"

    static func asset(_ assetId: String, name: String, symbol: String, decimals: Int, balance: BigUInt) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(assetId: assetId, name: name, symbol: symbol, decimals: decimals, image: ""),
            price: .init(prices: [:], diff24h: [:], diff7d: [:]),
            balance: balance
        )
    }

    /// A mnemonic wallet with its EVM, TRON and TON addresses.
    func multichainWallet() -> Wallet {
        Wallet(
            id: "wallet-id",
            identity: .init(network: .mainnet, kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)),
            metaData: .init(label: "Test wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: .init(isSetupFinished: true),
            batterySettings: .init(),
            multichain: .multichain(MultichainWalletState(
                walletId: "multichain-wallet-id",
                addresses: [
                    .init(chain: .eth, address: GaslessFixtures.sender),
                    .init(chain: .tron, address: Self.tronSender),
                    .init(chain: .ton, address: Self.tonAddress, type: .tonV4R2),
                ]
            ))
        )
    }

    /// The same addresses on a Ledger.
    func ledgerWallet() -> Wallet {
        let wallet = multichainWallet()
        return Wallet(
            id: wallet.id,
            identity: .init(
                network: .mainnet,
                kind: .Ledger(
                    TonSwift.PublicKey(data: Data(repeating: 1, count: 32)),
                    .v4R2,
                    Wallet.LedgerDevice(deviceId: "device", deviceModel: "Ledger Flex", accountIndex: 0)
                )
            ),
            metaData: wallet.metaData,
            setupSettings: wallet.setupSettings,
            batterySettings: wallet.batterySettings,
            multichain: wallet.multichain
        )
    }

    /// A device the user refuses every signature on.
    func refusingDevice() -> DeviceTransferSigner {
        DeviceTransferSigner(
            evm: { _ in throw CancellationError() },
            tron: { _ in throw CancellationError() },
            solana: { _ in throw CancellationError() },
            bitcoin: { _ in throw CancellationError() },
            ton: { _ in throw CancellationError() },
            evmMessage: { _ in throw CancellationError() },
            evmTypedData: { _, _ in throw CancellationError() },
            tronMessage: { _ in throw CancellationError() }
        )
    }

    /// An operation as ChainKit prices one, for the controller to carry from the emulation to the send.
    func pricedOperation() async throws -> PricedOperation {
        let account = try ChainKitOperationSender.account(of: MultichainWalletAddress(chain: .eth, address: GaslessFixtures.sender), holding: Self.eth.asset)
        let signable = try await SignableOperation.transfer(
            from: account,
            to: Self.ethRecipient,
            amount: BignumBigInteger(long: 1_000_000),
            memo: nil,
            isMax: false,
            intent: .send(1_000_000, of: Self.eth.asset, to: Self.ethRecipient),
            fidelity: .exact,
            client: CryptoKitClient(
                netModule: ModuleNetModule(
                    netConfig: ModuleNetConfig(isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil)
                )
            )
        )
        return PricedOperation(signable: signable, fee: FeeNone(asset: account.chain.toAsset()))
    }

    /// Picks TON for the TON jetton send `controller` holds, as the fee picker does: priced, chosen, priced again.
    func pickTON(on controller: MultichainTransactionConfirmationController) async throws {
        _ = await controller.emulate()
        controller.setPrefferedExtraType(extraType: .default)
        _ = await controller.emulate()
    }

    /// Picks TRX for the TRON USDT send `controller` holds, as the fee picker does: priced, chosen, priced again.
    func pickTRX(on controller: MultichainTransactionConfirmationController) async throws {
        _ = await controller.emulate()
        controller.setPrefferedExtraType(extraType: .gasless(token: TronUSDTFeeOptionsResolver.trxFeeToken))
        _ = await controller.emulate()
    }

    func makeController(
        asset: MultichainAsset,
        recipient: String,
        amount: BigUInt = MultichainSendConsentTests.amount,
        comment: String? = nil,
        commentEncryptionKey: String? = nil,
        isMaxAmount: Bool = false,
        wallet: Wallet? = nil,
        signer: MultichainTransferSigner = .mnemonic(passcodeProvider: { "1234" }),
        chainKitService: ChainKitService = ChainKitServiceStub(review: nil),
        relayedEVMChains: Set<MultichainChain> = [],
        evmGaslessFeeEngine: EVMGaslessFeeEngine? = nil,
        gate: OperationGate = OperationGate { [] },
        flags: ReviewFlags = ReviewFlags(),
        tronUsdtApi: TronUSDTAPI? = nil,
        heldJetton: JettonItem? = nil,
        offersBatteryMigration: @escaping (Wallet) async -> Bool = { _ in false },
        batteryPaymentPreparation: BatteryPaymentPreparation = BatteryPaymentPreparation(),
        trxOnlyRegion: Bool = true,
        batteryService suppliedBatteryService: BatteryService? = nil,
        beforeTonEmulate: (() async throws -> Void)? = nil,
        feeCalculationGate: MultichainFeeCalculationGate = MultichainFeeCalculationGate()
    ) throws -> MultichainTransactionConfirmationController {
        let fixture = try TonBatteryRelayFixture(featureFlags: flags, trxOnlyRegion: trxOnlyRegion)
        let configuration = fixture.configuration
        let session = TronNodeStub.session()
        let batteryService = suppliedBatteryService ?? batteryService()
        let currencyStore = CurrencyStore(keeperInfoStore: KeeperInfoStore(keeperInfoRepository: EmptyKeeperInfoRepositoryStub()))
        return try MultichainTransactionConfirmationController(
            wallet: wallet ?? multichainWallet(),
            recipient: MultichainRecipient(chain: XCTUnwrap(asset.asset.chain), address: recipient),
            asset: asset,
            amount: amount,
            comment: comment,
            commentEncryptionKey: commentEncryptionKey,
            isMaxAmount: isMaxAmount,
            chainKitService: chainKitService,
            signer: signer,
            engineResolver: MultichainFeeEngineResolver(relayedEVMChains: { relayedEVMChains }),
            tonJettonEngineFactory: MultichainTonJettonEngineFactory(
                api: API(hostProvider: BatteryHostStub(), urlSession: session, configuration: configuration),
                sendService: SendServiceStub(),
                blockchainService: BlockchainServiceStub(),
                ratesStore: TonRatesStore(repository: RatesRepositoryStub()),
                currencyStore: currencyStore,
                transferService: heldJetton.map { jetton in
                    TransferService(
                        batteryService: fixture.batteryService,
                        balanceService: JettonHoldingBalance(jetton: jetton),
                        sendService: TonEmulatingSend(beforeEmulate: beforeTonEmulate),
                        accountService: NoAccounts(),
                        configuration: configuration,
                        settingsRepository: SettingsRepository(settingsVault: SettingsVault(userDefaults: UserDefaults())),
                        currencyStore: currencyStore
                    )
                } ?? fixture.transferService(),
                balanceService: heldJetton.map { JettonHoldingBalance(jetton: $0) } ?? BalanceServiceStub(),
                settingsRepository: SettingsRepository(settingsVault: SettingsVault(userDefaults: UserDefaults())),
                batteryCalculation: BatteryCalculation(configuration: configuration)
            ),
            tronUsdtApi: tronUsdtApi ?? self.tronUsdtApi(batteryService: batteryService),
            sendService: SendServiceStub(),
            balanceService: BalanceServiceStub(),
            configuration: configuration,
            batteryService: batteryService,
            batteryCalculation: BatteryCalculation(configuration: configuration),
            multichainAssetBalanceProvider: MultichainAssetBalanceProvider(balanceService: MultichainServiceFake(), currencyStore: currencyStore),
            evmGaslessFeeEngine: evmGaslessFeeEngine ?? EVMGaslessFeeEngine(
                relayer: RelayerStub(),
                signer: RelayedOperationSignerStub(),
                isEnabled: { _ in false },
                batteryCharges: { _ in .unknown },
                walletTokens: { _, _ in [:] },
                gate: gate
            ),
            gate: gate,
            offersBatteryMigration: offersBatteryMigration,
            batteryPaymentPreparation: batteryPaymentPreparation,
            feeCalculationGate: feeCalculationGate
        )
    }

    func batteryService(estimatedCharges: Int = 0, balance: BatteryBalance? = nil) -> BatteryServiceStub {
        BatteryServiceStub(
            calls: calls,
            estimate: .init(
                energy_charges: 0,
                bandwidth_charges: 0,
                activation_charges: 0,
                total_charges: estimatedCharges,
                instant_fee: .init(fee_address: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c", accepted_assets: [])
            ),
            balance: balance
        )
    }

    /// The TRON API with the chain's fees known, so the engine prices a transfer.
    func pricedTronUsdtApi(batteryService suppliedBatteryService: BatteryService? = nil) async throws -> TronUSDTAPI {
        let chainParameters = TronChainParametersRepositoryImplementation()
        await chainParameters.setChainFees(
            TronChainFees(energySun: 100, bandwidthSun: 1000, createAccountSun: 100_000, createNewAccountSun: 1_000_000, createNewAccountBandwidthRate: 1)
        )
        let session = TronNodeStub.session()
        return try TronUSDTAPI(
            tronApi: TronApi(urlSession: session, baseApiUrl: XCTUnwrap(URL(string: "https://tron.test")), pause: { _ in }),
            batteryAPI: BatteryAPI(hostProvider: BatteryHostStub(), urlSession: session),
            batteryService: suppliedBatteryService ?? batteryService(),
            chainParametersRepository: chainParameters
        )
    }

    func tronUsdtApi(batteryService: BatteryService) throws -> TronUSDTAPI {
        let session = TronNodeStub.session()
        return try TronUSDTAPI(
            tronApi: TronApi(urlSession: session, baseApiUrl: XCTUnwrap(URL(string: "https://tron.test")), pause: { _ in }),
            batteryAPI: BatteryAPI(hostProvider: BatteryHostStub(), urlSession: session),
            batteryService: batteryService,
            chainParametersRepository: TronChainParametersRepositoryImplementation()
        )
    }

    func tronEngine(wallet: Wallet) throws -> TronUSDTTransactionConfirmationController {
        let batteryService = batteryService()
        return try TronUSDTTransactionConfirmationController(
            wallet: wallet,
            token: .usdt,
            recipient: TronSwift.Address(address: Self.tronRecipient),
            amount: Self.amount,
            balance: Self.tronUSDT.balance,
            senderAddress: TronSwift.Address(address: Self.tronSender),
            tronUsdtApi: tronUsdtApi(batteryService: batteryService),
            sendService: SendServiceStub(),
            balanceService: BalanceServiceStub(),
            configuration: TonBatteryRelayFixture().configuration,
            gate: OperationGate { [] }
        )
    }

    func tonTransfer(from wallet: Wallet) throws -> TransferData {
        try TransferData(
            transfer: .ton(TransferData.Ton(
                amount: Self.amount,
                isMax: false,
                recipient: TonSwift.Address.parse(Self.tonRecipient),
                comment: nil
            )),
            wallet: wallet,
            messageType: .ext,
            seqno: 7,
            timeout: 1_790_000_600
        )
    }
}

private extension ReviewFlags {
    /// Own sends signed as chain-kit's operation for them.
    static var operationTransfers: ReviewFlags {
        ReviewFlags(signsOperations: true)
    }
}

/// ChainKit as the controller reaches it: the transfer is priced with `review`, by the SDK or as
/// `operation`, and a send asks the consent it is handed about that review, as the gate before the
/// signature does. It keeps which of its paths the controller took.
private struct ChainKitServiceStub: ChainKitService {
    enum Call: Equatable {
        case emulateTransaction
        case emulateOperationTransfer
        case sendMultichainTransfer
        case sendOperationTransfer
    }

    actor Calls {
        private(set) var all = [Call]()
        /// The comment each emulation and SDK send was handed.
        private(set) var comments = [String?]()
        /// The recipient's key each emulation and SDK send was handed to encrypt the comment to.
        private(set) var keys = [String?]()

        func record(_ call: Call) {
            all.append(call)
        }

        func record(_ call: Call, comment: String?, key: String?) {
            all.append(call)
            comments.append(comment)
            keys.append(key)
        }
    }

    let review: OperationReview?
    var operation: PricedOperation?
    var isInsufficientBalance = false
    /// chain-kit prices no operation for the transfer.
    var failsOperationPricing = false
    var beforeEmulate: (() async -> Void)?
    let calls = Calls()

    func isTransferSupported(asset _: MultichainAsset) -> Bool {
        true
    }

    func tronPrivateKey(mnemonic _: String) throws -> Data {
        throw UnusedStub()
    }

    func makeBatterySendProof(mnemonic _: String, walletId _: String, boc _: String) throws -> String {
        throw UnusedStub()
    }

    func walletAppPrivateKey(mnemonic _: String) throws -> Data {
        throw UnusedStub()
    }

    func walletAuthToken(appPrivateKey _: Data, walletId _: String, accessToken _: String) -> String? {
        nil
    }

    func emulateTransaction(
        wallet _: Wallet,
        recipient _: String,
        asset _: MultichainAsset,
        amount _: BigUInt,
        comment: String?,
        commentEncryptionKey: String?,
        isMaxAmount _: Bool
    ) async throws(MultichainTransactionEmulationFailure) -> MultichainTransactionEmulationResult {
        await beforeEmulate?()
        await calls.record(.emulateTransaction, comment: comment, key: commentEncryptionKey)
        return MultichainTransactionEmulationResult(fee: 21000, asset: MultichainSendConsentTests.eth.asset, review: review)
    }

    func sendMultichainTransfer(
        signer _: MultichainTransferSigner,
        wallet _: Wallet,
        recipient _: String,
        asset _: MultichainAsset,
        amount _: BigUInt,
        comment: String?,
        commentEncryptionKey: String?,
        isMaxAmount _: Bool,
        consent: OperationConsent
    ) async throws(MultichainTransactionFailure) -> [String] {
        await calls.record(.sendMultichainTransfer, comment: comment, key: commentEncryptionKey)
        if let review, await !consent(review) {
            throw .canceled
        }
        return ["0xsent"]
    }

    func emulateOperationTransfer(
        wallet _: Wallet,
        recipient _: String,
        asset _: MultichainAsset,
        amount _: BigUInt,
        comment: String?,
        commentEncryptionKey: String?,
        isMaxAmount _: Bool
    ) async throws(MultichainTransactionEmulationFailure) -> MultichainTransactionEmulationResult {
        await calls.record(.emulateOperationTransfer, comment: comment, key: commentEncryptionKey)
        if failsOperationPricing {
            throw .internal(reason: "chain-kit priced no operation")
        }
        return MultichainTransactionEmulationResult(
            fee: 21000,
            asset: MultichainSendConsentTests.eth.asset,
            adjustedAmount: nil,
            isMaxAmount: false,
            isInsufficientBalance: isInsufficientBalance,
            review: review,
            operation: operation
        )
    }

    func sendOperationTransfer(
        _ emulation: MultichainTransactionEmulationResult,
        wallet _: Wallet,
        passcodeProvider _: @escaping () async -> String?,
        consent: OperationConsent
    ) async throws(MultichainTransactionFailure) -> [String] {
        await calls.record(.sendOperationTransfer)
        guard let operation, emulation.operation == operation else {
            throw .internal(reason: "handed another operation than the one priced")
        }
        if let review, await !consent(review) {
            throw .canceled
        }
        return ["0xoperation"]
    }

    func makeWalletState(mnemonic _: String) throws -> MultichainWalletState {
        throw UnusedStub()
    }

    func makeWalletRegisterItem(
        appPrivateKey _: Data,
        deviceId _: String,
        challenge _: String,
        state _: MultichainWalletState
    ) throws -> MultichainWalletRegisterItem {
        throw UnusedStub()
    }

    func makeMnemonic() throws(MultichainMakeMnemonicFailure) -> [String] {
        throw .unknown(message: "unused")
    }
}

/// Offers battery charges, emulates the transfer under them with a deadline ten minutes on, and
/// counts what it is handed to relay.
private final class RelayerStub: EVMGaslessRelaying {
    private(set) var sent = 0
    private let txHash: String?
    var available: (() async -> Bool)?
    var onEmulate: (() async -> Void)?
    var onSend: (() async -> Void)?
    var emulationFee: BigUInt = 18
    var estimateFee: BigUInt = 18
    var omitsBattery = false
    var rejectsEstimate = false
    var estimationsOverride: [EVMGaslessEstimation]?

    init(txHash: String? = nil) {
        self.txHash = txHash
    }

    func estimate(wallet _: Wallet, call _: EVMGaslessCall) async throws -> [EVMGaslessEstimation] {
        if rejectsEstimate { throw UnusedStub() }
        if let estimationsOverride { return estimationsOverride }
        if omitsBattery { return [] }
        let available = await available?() ?? true
        return [EVMGaslessEstimation(
            asset: Components.Schemas.GaslessV2Asset(id: "battery/mainnet", name: "Battery", symbol: "BATTERY", decimals: 0, image: nil),
            fee: estimateFee,
            isAvailable: available
        )]
    }

    func emulate(wallet _: Wallet, calls: [EVMGaslessCall], assetId: String) async throws -> EVMGaslessEmulation {
        await onEmulate?()
        var relayed = calls.map { (target: $0.to, data: $0.data, value: $0.value.description) }
        var mode = "0x0100000000007821000100000000000000000000000000000000000000000000"
        if case let .asset(_, _, _, contract) = AssetIdComponents(assetId: assetId),
           let transfer = EVMGaslessCall.erc20TransferData(recipient: "0x45a9034c5dc4e1731b7ff8f977e50012822d5b9d", amount: emulationFee)
        {
            relayed.insert((contract, transfer, "0"), at: 0)
            mode = "0x0101000000007821000100000000000000000000000000000000000000000029"
        }
        return try EVMGaslessEmulation(
            assetId: assetId,
            fee: emulationFee,
            operation: MultichainRelayedOperation(
                id: "bcef74e1-b940-4142-b7a7-76161850971e",
                json: GaslessFixtures.operation(
                    feeAssetId: assetId,
                    fee: emulationFee.description,
                    sender: calls.first?.sender ?? GaslessFixtures.sender,
                    calls: relayed.map { ($0.target, $0.data) },
                    callValues: relayed.map(\.value),
                    mode: mode,
                    deadline: String(Int(Date().timeIntervalSince1970) + 10 * 60)
                )
            ),
            expiresAt: Date().addingTimeInterval(10 * 60)
        )
    }

    func emulate(wallet _: Wallet, batch _: EVMBatchRelay, assetId: String) async throws -> EVMGaslessEmulation {
        throw EVMGaslessRelayerError.rejected(reason: "no batch emulation for \(assetId)")
    }

    func send(wallet _: Wallet, signedOperation _: Data) async throws -> String? {
        await onSend?()
        sent += 1
        return txHash
    }
}

private struct RelayedOperationSignerStub: MultichainRelayedOperationSigner {
    var requestsPasscode = false
    var onSign: (() async -> Void)?

    func signRelayedOperation(
        passcodeProvider: @escaping () async -> String?,
        wallet _: Wallet,
        chain _: MultichainChain,
        operation _: MultichainRelayedOperation
    ) async throws(MultichainTransactionFailure) -> Data {
        if requestsPasscode, await passcodeProvider() == nil { throw .canceled }
        await onSign?()
        return Data("signed".utf8)
    }
}

/// An engine of the TON ones' kind, standing for any engine that is not TRON's.
private final class TonEngineStub: TransactionConfirmationController {
    var signHandler: ((TransferData, Wallet) async throws(TransactionConfirmationError) -> SignedTransactions)?
    private let wallet: Wallet

    init(wallet: Wallet) {
        self.wallet = wallet
    }

    func getModel() -> TransactionConfirmationModel {
        TransactionConfirmationModel(
            wallet: wallet,
            recipient: nil,
            recipientAddress: nil,
            transaction: .transfer(.ton(false)),
            amount: nil,
            extraState: .none,
            availableExtraTypes: [],
            totalFee: 0
        )
    }

    func setLoading() {}

    func emulate() async -> Result<Void, TransactionConfirmationError> {
        .success(())
    }

    func sendTransaction() async -> Result<TransactionConfirmationSendResult, TransactionConfirmationError> {
        .success(.nothingToRecord)
    }
}

private actor SignedRequests {
    private(set) var all = 0

    func count() {
        all += 1
    }
}

/// TON's node as a jetton engine reaches it: a seqno to sign at, and every message emulated to cost the
/// wallet `fee`.
private struct TonEmulatingSend: SendService {
    static let fee: BigUInt = 2_980_000
    var beforeEmulate: (() async throws -> Void)?

    func loadSeqno(wallet _: Wallet) async throws -> UInt64 {
        try await beforeEmulate?()
        return 7
    }

    func loadTransactionInfo(
        boc _: String,
        wallet _: Wallet,
        params _: [EmulateMessageToWalletRequestParamsInner]?,
        currency _: Currency?
    ) async throws -> TonAPI.Components.Schemas.MessageConsequences {
        try await beforeEmulate?()
        try Task.checkCancellation()
        let account = #"{"address": "0:0000000000000000000000000000000000000000000000000000000000000005", "is_scam": false, "is_wallet": true}"#
        return try JSONDecoder().decode(TonAPI.Components.Schemas.MessageConsequences.self, from: Data(#"""
        {
          "trace": {
            "transaction": {
              "hash": "00", "lt": 1, "account": \#(account), "success": true, "utime": 1,
              "orig_status": "active", "end_status": "active", "total_fees": 1, "end_balance": 1,
              "transaction_type": "TransOrd", "state_update_old": "", "state_update_new": "",
              "out_msgs": [], "block": "", "aborted": false, "destroyed": false, "raw": ""
            },
            "interfaces": []
          },
          "risk": {"transfer_all_remaining_balance": false, "gram": 0, "jettons": [], "nfts": []},
          "event": {
            "event_id": "event", "account": \#(account), "timestamp": 1, "actions": [], "is_scam": false,
            "lt": 1, "in_progress": false, "extra": -\#(Self.fee), "progress": 1
          }
        }
        """#.utf8))
    }

    func sendTransaction(boc _: String, wallet _: Wallet, headers _: [String: String]) async throws {
        throw UnusedStub()
    }

    func sendTransactions(batch _: [String], wallet _: Wallet) async throws {
        throw UnusedStub()
    }

    func getTimeoutSafely(wallet _: Wallet, TTL _: UInt64) async -> UInt64 {
        1_790_000_600
    }

    func getGaslessRelayAddress(wallet _: Wallet) async throws -> TonSwift.Address {
        throw UnusedStub()
    }

    func getJettonCustomPayload(wallet _: Wallet, jetton _: TonSwift.Address) async throws -> JettonTransferPayload {
        throw UnusedStub()
    }

    func getIndexingLatency(wallet _: Wallet) async throws -> Int {
        throw UnusedStub()
    }
}

/// A TON balance of 1 TON beside `jetton`, which its engine finds without the network.
private struct JettonHoldingBalance: BalanceService {
    let jetton: JettonItem

    func loadWalletBalance(wallet: Wallet, currency _: Currency, includingTransferFees _: Bool) async throws -> WalletBalance {
        try getBalance(wallet: wallet)
    }

    func getBalance(wallet _: Wallet) throws -> WalletBalance {
        WalletBalance(
            date: Date(),
            balance: KeeperCore.Balance(
                tonBalance: TonBalance(amount: 1_000_000_000),
                jettonsBalance: [JettonBalance(item: jetton, quantity: 5_000_000_000, rates: [:])]
            ),
            stacking: [],
            batteryBalance: nil,
            tronBalance: nil
        )
    }
}

/// No account can be read.
private struct NoAccounts: AccountService {
    func loadAccount(network _: KeeperCore.Network, address _: TonSwift.Address) async throws -> KeeperCore.Account {
        throw UnusedStub()
    }

    func loadAccount(network _: KeeperCore.Network, domain _: String) async throws -> KeeperCore.Account {
        throw UnusedStub()
    }
}

private struct BlockchainServiceStub: BlockchainService {
    func getWalletAddress(jettonMaster _: String, owner _: String, network _: KeeperCore.Network) async throws -> TonSwift.Address {
        throw UnusedStub()
    }
}

private struct RatesRepositoryStub: RatesRepository {
    func saveRates(_: Rates) throws {}

    func getRates() throws -> Rates {
        Rates(ton: [], usdt: [], jettonRates: [:])
    }
}

private actor FeeFunding {
    private(set) var value: Bool

    init(_ value: Bool) {
        self.value = value
    }

    func set(_ value: Bool) {
        self.value = value
    }
}
