import BigInt
import ChainKit
@testable import KeeperCore
import TKTestSupport
import TonSwift
import XCTest

/// A swap confirmed with a relayed fee method must be sent by that method's engine and by nothing
/// else: falling back to a ChainKit broadcast would spend the coin the user chose not to spend.
final class MultichainSwapRelayedExecutionTests: XCTestCase {
    func testFundedMultichainBatterySwapDoesNotWaitForLegacyServices() async throws {
        let session = BatteryPaymentTestSession(fails: true)
        let engine = StubRelayedFeeEngine(sendResult: .success("relayed"))
        let service = makeExecutionService(
            swapPipeline: StubChainKitSwapPipeline(),
            engines: [engine],
            batteryPaymentPreparation: BatteryPaymentPreparation(
                needsMigration: { _ in true },
                migrate: { _, code in try await session.migrate(code) },
                currentCharges: { _ in .available(3) }
            )
        )

        let result = try await service.execute(passcodeProvider: { await session.passcode() }, swapWallet: makeSwapWallet(), sourceAsset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"), destinationAsset: makeAsset(assetId: "ton/mainnet/coin"), executionPlan: makeExecutionPlan(), feeMethod: .battery)

        XCTAssertEqual(result.txHash, "relayed")
        let events = await session.events
        XCTAssertTrue(events.isEmpty)
    }

    func test_batterySwapWaitsForMigrationAndReusesOneUnlock() async throws {
        let hold = TestGate()
        let session = BatteryPaymentTestSession(hold: hold)
        let engine = StubRelayedFeeEngine(sendResult: .success("relayed"), onSend: { signer throws(MultichainSwapExecutionFailure) in
            guard case let .mnemonic(provider) = signer, await provider() == "1234" else { throw .canceled }
            await session.record("sign")
        })
        let pipeline = StubChainKitSwapPipeline()
        let service = makeExecutionService(
            swapPipeline: pipeline,
            engines: [engine],
            batteryPaymentPreparation: BatteryPaymentPreparation(needsMigration: { _ in true }, migrate: { _, code in try await session.migrate(code) })
        )
        let wallet = makeSwapWallet()
        let source = makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master")
        let destination = makeAsset(assetId: "ton/mainnet/coin")
        let plan = makeExecutionPlan()
        let task = Task {
            try await service.execute(passcodeProvider: { await session.passcode() }, swapWallet: wallet, sourceAsset: source, destinationAsset: destination, executionPlan: plan, feeMethod: .battery)
        }
        try await session.started.wait()

        XCTAssertEqual(engine.prepareCount, 0)
        XCTAssertTrue(engine.sentPayloadIds.isEmpty)
        XCTAssertTrue(pipeline.executedPayloadIds.isEmpty)
        await hold.open()
        let result = try await task.value

        XCTAssertEqual(result.txHash, "relayed")
        XCTAssertEqual(engine.prepareCount, 1)
        let events = await session.events
        XCTAssertEqual(events, ["pin", "migration-start", "migration-complete", "sign"])
        XCTAssertEqual(engine.sentPayloadIds, ["main"])
    }

    func test_failedMigrationStopsSwapBeforePricingSigningOrBroadcast() async throws {
        let session = BatteryPaymentTestSession(fails: true)
        let engine = StubRelayedFeeEngine(sendResult: .success("relayed"))
        let pipeline = StubChainKitSwapPipeline()
        let service = makeExecutionService(
            swapPipeline: pipeline,
            engines: [engine],
            batteryPaymentPreparation: BatteryPaymentPreparation(needsMigration: { _ in true }, migrate: { _, code in try await session.migrate(code) })
        )

        do {
            _ = try await service.execute(passcodeProvider: { await session.passcode() }, swapWallet: makeSwapWallet(), sourceAsset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"), destinationAsset: makeAsset(assetId: "ton/mainnet/coin"), executionPlan: makeExecutionPlan(), feeMethod: .battery)
            XCTFail("Expected a migration error")
        } catch let error as MultichainSwapExecutionFailure {
            guard case .preparationFailed(kind: .networkError, reason: _) = error else { return XCTFail("Unexpected failure: \(error)") }
        }

        XCTAssertEqual(engine.prepareCount, 0)
        XCTAssertTrue(engine.sentPayloadIds.isEmpty)
        XCTAssertTrue(pipeline.executedPayloadIds.isEmpty)
    }

    func test_tokenPaidSwapDoesNotRequestBatteryMigration() async throws {
        let engine = StubRelayedFeeEngine(sendResult: .success("relayed"))
        let service = makeExecutionService(
            swapPipeline: StubChainKitSwapPipeline(),
            engines: [engine],
            batteryPaymentPreparation: BatteryPaymentPreparation(needsMigration: { _ in
                XCTFail("A GRAM payment must not wait for Battery migration")
                return true
            })
        )

        let result = try await service.execute(
            passcodeProvider: { "1234" },
            swapWallet: makeSwapWallet(),
            sourceAsset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"),
            destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
            executionPlan: makeExecutionPlan(feeOptions: [.init(cost: .gram(amountNano: 12_000_000, isInsufficient: false))]),
            feeMethod: .gram
        )

        XCTAssertEqual(result.txHash, "relayed")
    }

    private lazy var client = CryptoKitClient(
        netModule: ModuleNetModule(
            netConfig: ModuleNetConfig(isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil)
        )
    )

    func testBatteryMethodSendsThroughTheEngine() async throws {
        let engine = StubRelayedFeeEngine(sendResult: .success("relayed-hash"))
        let pipeline = StubChainKitSwapPipeline()
        let pendingTransactions = PendingTransactionsServiceFake()
        let service = makeExecutionService(
            swapPipeline: pipeline,
            pendingTransactionsService: pendingTransactions,
            engines: [engine]
        )

        let result = try await service.execute(
            passcodeProvider: { "1111" },
            swapWallet: makeSwapWallet(),
            sourceAsset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"),
            destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
            executionPlan: makeExecutionPlan(),
            feeMethod: .battery
        )

        XCTAssertEqual(result.txHash, "relayed-hash")
        XCTAssertEqual(result.broadcastedPayloads.map(\.payloadId), ["main"])
        XCTAssertEqual(engine.sentPayloadIds, ["main"])
        // The price the plan carries is what the engine is asked to honour; anything else would let
        // the relayer bill a swap the user never confirmed.
        XCTAssertEqual(engine.sentFees, [.batteryCharges(3)])
        XCTAssertEqual(pipeline.executedPayloadIds, [])
        let reported = await pendingTransactions.reported
        XCTAssertEqual(reported.map(\.txHash), ["relayed-hash"])
        guard case let .swap(details) = try XCTUnwrap(reported.first).activityType else {
            return XCTFail("Expected a pending swap")
        }
        XCTAssertEqual(details.fromAddress, makeSwapWallet().address(for: .ton))
        XCTAssertEqual(details.fromAmount, "1")
    }

    /// The relayer settles a GRAM-paid swap the same way; only what it bills differs, so the engine
    /// has to be handed the amount the confirmation screen priced rather than a charge count.
    func testGramMethodSendsThroughTheEngineWithTheConfirmedAmount() async throws {
        let engine = StubRelayedFeeEngine(sendResult: .success("relayed-hash"))
        let pipeline = StubChainKitSwapPipeline()
        let service = makeExecutionService(swapPipeline: pipeline, engines: [engine])

        let result = try await service.execute(
            passcodeProvider: { "1111" },
            swapWallet: makeSwapWallet(),
            sourceAsset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"),
            destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
            executionPlan: makeExecutionPlan(feeOptions: [
                MultichainSwapFeeOption(cost: .gram(amountNano: 12_000_000, isInsufficient: false)),
            ]),
            feeMethod: .gram
        )

        XCTAssertEqual(result.txHash, "relayed-hash")
        XCTAssertEqual(engine.sentFees, [.gram(amountNano: 12_000_000)])
        XCTAssertEqual(pipeline.executedPayloadIds, [])
    }

    /// The plan can hold both relayed methods at once, and the one the user confirmed is the one that
    /// has to be billed.
    func testTheConfirmedMethodPicksItsOwnPriceOutOfThePlan() async throws {
        let engine = StubRelayedFeeEngine(sendResult: .success("relayed-hash"))
        let service = makeExecutionService(swapPipeline: StubChainKitSwapPipeline(), engines: [engine])

        _ = try await service.execute(
            passcodeProvider: { "1111" },
            swapWallet: makeSwapWallet(),
            sourceAsset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"),
            destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
            executionPlan: makeExecutionPlan(feeOptions: [
                MultichainSwapFeeOption(cost: .batteryCharges(count: 3, excess: nil, isInsufficient: false)),
                MultichainSwapFeeOption(cost: .gram(amountNano: 12_000_000, isInsufficient: false)),
            ]),
            feeMethod: .gram
        )

        XCTAssertEqual(engine.sentFees, [.gram(amountNano: 12_000_000)])
    }

    /// A relayer that broadcasts on its own names no transaction: the swap is done, but there is no
    /// hash to report as pending, and a token-paid fee is relayed like any other.
    func testARelayerThatNamesNoTransactionReportsNothing() async throws {
        let usdt = MultichainAssetDetails(
            assetId: "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7",
            name: "Tether",
            symbol: "USDT",
            decimals: 6,
            image: ""
        )
        let engine = StubRelayedFeeEngine(sendResult: .success(nil))
        let pipeline = StubChainKitSwapPipeline()
        let pendingTransactions = PendingTransactionsServiceFake()
        let service = makeExecutionService(
            swapPipeline: pipeline,
            pendingTransactionsService: pendingTransactions,
            engines: [engine]
        )

        let result = try await service.execute(
            passcodeProvider: { "1111" },
            swapWallet: makeSwapWallet(),
            sourceAsset: makeAsset(assetId: usdt.assetId),
            destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
            executionPlan: makeExecutionPlan(feeOptions: [
                MultichainSwapFeeOption(cost: .token(usdt, amount: 115_304, isInsufficient: false)),
            ]),
            feeMethod: .token(assetId: usdt.assetId)
        )

        XCTAssertNil(result.txHash)
        XCTAssertEqual(result.broadcastedPayloads, [])
        XCTAssertEqual(engine.sentPayloadIds, ["main"])
        XCTAssertEqual(engine.sentFees, [.token(assetId: usdt.assetId, amount: 115_304)])
        XCTAssertEqual(pipeline.executedPayloadIds, [])
        let reported = await pendingTransactions.reported
        XCTAssertTrue(reported.isEmpty)
    }

    func testInsufficientGramIsNotRelayed() async {
        let engine = StubRelayedFeeEngine(sendResult: .success("relayed-hash"))
        let pipeline = StubChainKitSwapPipeline()
        let service = makeExecutionService(swapPipeline: pipeline, engines: [engine])

        do {
            _ = try await service.execute(
                passcodeProvider: { "1111" },
                swapWallet: makeSwapWallet(),
                sourceAsset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"),
                destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
                executionPlan: makeExecutionPlan(feeOptions: [
                    MultichainSwapFeeOption(cost: .gram(amountNano: 12_000_000, isInsufficient: true)),
                ]),
                feeMethod: .gram
            )
            XCTFail("Expected an insufficient fee method to be refused")
        } catch {
            guard case .internal = error else {
                return XCTFail("Unexpected failure \(error)")
            }
        }
        XCTAssertEqual(engine.sentPayloadIds, [])
        XCTAssertEqual(pipeline.executedPayloadIds, [])
    }

    func testNativeMethodKeepsUsingThePipeline() async throws {
        let engine = StubRelayedFeeEngine(sendResult: .success("relayed-hash"))
        let pipeline = StubChainKitSwapPipeline(
            executionResult: MultichainSwapBroadcastResult(
                txHash: "broadcast-hash",
                broadcastedPayloads: []
            )
        )
        let service = makeExecutionService(swapPipeline: pipeline, engines: [engine])

        let result = try await service.execute(
            passcodeProvider: { "1111" },
            swapWallet: makeSwapWallet(),
            sourceAsset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"),
            destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
            executionPlan: makeExecutionPlan()
        )

        XCTAssertEqual(result.txHash, "broadcast-hash")
        XCTAssertEqual(engine.sentPayloadIds, [])
        XCTAssertEqual(pipeline.executedPayloadIds, ["main"])
    }

    func testUnavailableEngineFailsInsteadOfFallingBack() async {
        let pipeline = StubChainKitSwapPipeline(
            executionResult: MultichainSwapBroadcastResult(
                txHash: "broadcast-hash",
                broadcastedPayloads: []
            )
        )
        let service = makeExecutionService(swapPipeline: pipeline, engines: [])

        do {
            _ = try await service.execute(
                passcodeProvider: { "1111" },
                swapWallet: makeSwapWallet(),
                sourceAsset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"),
                destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
                executionPlan: makeExecutionPlan(),
                feeMethod: .battery
            )
            XCTFail("Expected the send to fail without an engine")
        } catch {
            guard case .internal = error else {
                return XCTFail("Unexpected failure \(error)")
            }
        }
        XCTAssertEqual(pipeline.executedPayloadIds, [])
    }

    func testInsufficientConfirmedOptionIsNotRelayed() async {
        let engine = StubRelayedFeeEngine(sendResult: .success("relayed-hash"))
        let pipeline = StubChainKitSwapPipeline()
        let service = makeExecutionService(swapPipeline: pipeline, engines: [engine])

        do {
            _ = try await service.execute(
                passcodeProvider: { "1111" },
                swapWallet: makeSwapWallet(),
                sourceAsset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"),
                destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
                executionPlan: makeExecutionPlan(feeOptions: [
                    MultichainSwapFeeOption(cost: .batteryCharges(count: 3, excess: nil, isInsufficient: true)),
                ]),
                feeMethod: .battery
            )
            XCTFail("Expected an insufficient fee method to be refused")
        } catch {
            guard case .internal = error else {
                return XCTFail("Unexpected failure \(error)")
            }
        }
        XCTAssertEqual(engine.sentPayloadIds, [])
        XCTAssertEqual(pipeline.executedPayloadIds, [])
    }

    func testNativeShortageLeavesTheRouteConfirmableWithBattery() async throws {
        let engine = StubRelayedFeeEngine(
            optionResults: [MultichainSwapFeeOption(cost: .batteryCharges(count: 3, excess: nil, isInsufficient: false))],
            sendResult: .success("relayed-hash")
        )
        let service = makeExecutionService(
            swapPipeline: StubChainKitSwapPipeline(
                preparation: makePreparation(nativeFeeShortage: makeShortage())
            ),
            engines: [engine]
        )

        let plan = try await service.prepareExecutionPlan(
            swapWallet: makeSwapWallet(),
            sourceAsset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"),
            destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
            route: makeRoute()
        )

        XCTAssertEqual(plan.feeOptions.map(\.method), [.battery, .native])
        XCTAssertEqual(plan.feeOptions.map(\.isInsufficient), [false, true])
        XCTAssertEqual(
            MultichainSwapFeeSelection.resolve(options: plan.feeOptions, picked: nil)?.method,
            .battery
        )
    }

    func testNativeShortageOnlyFailsWhenNothingButTheChainCoinIsLeft() async {
        let engine = StubRelayedFeeEngine(sendResult: .success("relayed-hash"))
        let service = makeExecutionService(
            swapPipeline: StubChainKitSwapPipeline(
                preparation: makePreparation(nativeFeeShortage: makeShortage())
            ),
            engines: [engine]
        )

        do {
            _ = try await service.prepareExecutionPlan(
                swapWallet: makeSwapWallet(),
                sourceAsset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"),
                destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
                route: makeRoute()
            )
            XCTFail("Expected the preparation to fail without a payable method")
        } catch {
            guard case .insufficientNativeFee = error else {
                return XCTFail("Unexpected failure \(error)")
            }
        }
    }

    /// A GRAM row the wallet is short of is a deposit away from paying, so it keeps the plan alive
    /// exactly as an unaffordable battery row does.
    func testNativeShortageKeepsARefillableGramOnTheRoute() async throws {
        let engine = StubRelayedFeeEngine(
            optionResults: [MultichainSwapFeeOption(cost: .gram(amountNano: 12_000_000, isInsufficient: true))],
            sendResult: .success("relayed-hash")
        )
        let service = makeExecutionService(
            swapPipeline: StubChainKitSwapPipeline(
                preparation: makePreparation(nativeFeeShortage: makeShortage())
            ),
            engines: [engine]
        )

        let plan = try await service.prepareExecutionPlan(
            swapWallet: makeSwapWallet(),
            sourceAsset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"),
            destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
            route: makeRoute()
        )

        XCTAssertEqual(plan.feeOptions.map(\.method), [.gram, .native])
        XCTAssertTrue(plan.feeOptions.allSatisfy(\.isInsufficient))
    }

    func testNativeShortageKeepsARefillableBatteryOnTheRoute() async throws {
        let engine = StubRelayedFeeEngine(
            optionResults: [MultichainSwapFeeOption(cost: .batteryCharges(count: 3, excess: nil, isInsufficient: true))],
            sendResult: .success("relayed-hash")
        )
        let service = makeExecutionService(
            swapPipeline: StubChainKitSwapPipeline(
                preparation: makePreparation(nativeFeeShortage: makeShortage())
            ),
            engines: [engine]
        )

        let plan = try await service.prepareExecutionPlan(
            swapWallet: makeSwapWallet(),
            sourceAsset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"),
            destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
            route: makeRoute()
        )

        XCTAssertEqual(plan.feeOptions.map(\.method), [.battery, .native])
        XCTAssertTrue(plan.feeOptions.allSatisfy(\.isInsufficient))
        XCTAssertEqual(
            MultichainSwapFeeSelection.resolve(options: plan.feeOptions, picked: nil)?.method,
            .battery
        )
    }

    func testThePayloadDecidesWhichEngineRelaysTheSwap() async throws {
        let tonEngine = StubRelayedFeeEngine(family: .ton, sendResult: .success("ton-hash"))
        let tronEngine = StubRelayedFeeEngine(family: .tron, sendResult: .success("tron-hash"))
        let service = makeExecutionService(
            swapPipeline: StubChainKitSwapPipeline(),
            engines: [tonEngine, tronEngine]
        )

        let result = try await service.execute(
            passcodeProvider: { "1111" },
            swapWallet: makeSwapWallet(),
            sourceAsset: makeAsset(assetId: "tron/mainnet/coin"),
            destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
            executionPlan: makeExecutionPlan(
                batteryPayload: .tron(
                    TronSwapTransfer(to: "TDepositAddress", amount: 9_191_671)
                )
            ),
            feeMethod: .battery
        )

        XCTAssertEqual(result.txHash, "tron-hash")
        XCTAssertEqual(tronEngine.sentPayloadIds, ["main"])
        XCTAssertEqual(tonEngine.sentPayloadIds, [])
    }

    func testUnpricedOptionIsNeverRelayed() async {
        let engine = StubRelayedFeeEngine(sendResult: .success("relayed-hash"))
        let pipeline = StubChainKitSwapPipeline()
        let service = makeExecutionService(swapPipeline: pipeline, engines: [engine])

        do {
            _ = try await service.execute(
                passcodeProvider: { "1111" },
                swapWallet: makeSwapWallet(),
                sourceAsset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"),
                destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
                executionPlan: makeExecutionPlan(feeOptions: [
                    MultichainSwapFeeOption(cost: .batteryUnpriced),
                ]),
                feeMethod: .battery
            )
            XCTFail("Expected an unpriced fee method to be refused")
        } catch {
            guard case .internal = error else {
                return XCTFail("Unexpected failure \(error)")
            }
        }
        XCTAssertEqual(engine.sentPayloadIds, [])
        XCTAssertEqual(pipeline.executedPayloadIds, [])
    }

    func testBatterySendFailureIsNotRetriedOnTheChain() async {
        let engine = StubRelayedFeeEngine(
            sendResult: .failure(
                .broadcastFailed(payloadId: "main", kind: .unknown, reason: "relay rejected")
            )
        )
        let pipeline = StubChainKitSwapPipeline(
            executionResult: MultichainSwapBroadcastResult(
                txHash: "broadcast-hash",
                broadcastedPayloads: []
            )
        )
        let pendingTransactions = PendingTransactionsServiceFake()
        let service = makeExecutionService(
            swapPipeline: pipeline,
            pendingTransactionsService: pendingTransactions,
            engines: [engine]
        )

        do {
            _ = try await service.execute(
                passcodeProvider: { "1111" },
                swapWallet: makeSwapWallet(),
                sourceAsset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"),
                destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
                executionPlan: makeExecutionPlan(),
                feeMethod: .battery
            )
            XCTFail("Expected the relay failure to surface")
        } catch {
            guard case .broadcastFailed = error else {
                return XCTFail("Unexpected failure \(error)")
            }
        }
        XCTAssertEqual(pipeline.executedPayloadIds, [])
        let reported = await pendingTransactions.reported
        XCTAssertTrue(reported.isEmpty)
    }

    /// Without checks the gate builds nothing and stops nothing: not a consent that refuses
    /// everything, not a deadline the device's clock has passed already.
    func testWithoutChecksARelayedSwapIsSentAsItAlwaysWas() async throws {
        let engine = StubRelayedFeeEngine(family: .evm, sendResult: .success("relayed-hash"), expiresAt: Date(timeIntervalSince1970: -10))
        let service = makeExecutionService(swapPipeline: StubChainKitSwapPipeline(), engines: [engine])

        let result = try await service.execute(
            passcodeProvider: { "1111" },
            swapWallet: makeSwapWallet(),
            sourceAsset: makeAsset(assetId: Self.usdt.assetId, decimals: 6),
            destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
            executionPlan: makeExecutionPlan(batteryPayload: Self.evmPayload),
            feeMethod: .battery,
            spendLimit: 1_000_000,
            consent: .refuse
        )

        XCTAssertEqual(result.txHash, "relayed-hash")
        XCTAssertEqual(engine.reviewedIntents, [])
        XCTAssertEqual(engine.sentFees, [.batteryCharges(3)])
    }

    /// Charges on an EVM chain are asked about once the relayer's operation is prepared, and a
    /// refusal is the user's cancel: nothing is signed, relayed or reported.
    func testABatteryRelayOnAnEVMChainIsAskedAboutAndARefusalRelaysNothing() async {
        let engine = StubRelayedFeeEngine(family: .evm, sendResult: .success("relayed-hash"))
        let pendingTransactions = PendingTransactionsServiceFake()
        let service = makeExecutionService(
            swapPipeline: StubChainKitSwapPipeline(),
            pendingTransactionsService: pendingTransactions,
            engines: [engine],
            checks: [WarningCheck()]
        )
        let user = ConsentingUser(answering: false)

        do {
            _ = try await service.execute(
                passcodeProvider: { "1111" },
                swapWallet: makeSwapWallet(),
                sourceAsset: makeAsset(assetId: Self.usdt.assetId, decimals: 6),
                destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
                executionPlan: makeExecutionPlan(batteryPayload: Self.evmPayload),
                feeMethod: .battery,
                spendLimit: 1_000_000,
                consent: user.attempt()
            )
            XCTFail("relayed a swap the user refused")
        } catch {
            XCTAssertEqual(error, .canceled)
        }

        let asked = await user.asked
        XCTAssertEqual(asked.count, 1)
        XCTAssertEqual(engine.reviewedIntents, [.wallet(spending: [.init(assetId: Self.usdt.assetId, symbol: "TEST", decimals: 6, amount: 1_000_000)], to: Self.router)])
        XCTAssertEqual(engine.sentFees, [])
        let reported = await pendingTransactions.reported
        XCTAssertTrue(reported.isEmpty)
    }

    /// A TRON relay is asked about whatever pays for it, before the passcode or the device. GRAM is
    /// paid from the TON account, so the TRON transfer is held to what it sells alone, paid to the
    /// deposit address of its route.
    func testATronRelayIsAskedAboutInChargesAndInGram() async throws {
        let tronUsdt = makeAsset(assetId: "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t", decimals: 6)
        let options = [
            MultichainSwapFeeOption(cost: .batteryCharges(count: 3, excess: nil, isInsufficient: false)),
            MultichainSwapFeeOption(cost: .gram(amountNano: 12_000_000, isInsufficient: false)),
        ]
        for option in options {
            let engine = StubRelayedFeeEngine(family: .tron, sendResult: .success("tron-hash"))
            let service = makeExecutionService(swapPipeline: StubChainKitSwapPipeline(), engines: [engine], checks: [WarningCheck()])
            let user = ConsentingUser(answering: true)

            let result = try await service.execute(
                passcodeProvider: { "1111" },
                swapWallet: makeSwapWallet(),
                sourceAsset: tronUsdt,
                destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
                executionPlan: makeExecutionPlan(batteryPayload: Self.tronPayload, feeOptions: [option]),
                feeMethod: option.method,
                spendLimit: 9_191_671,
                consent: user.attempt()
            )

            XCTAssertEqual(result.txHash, "tron-hash", option.logValue)
            let asked = await user.asked
            XCTAssertEqual(asked.count, 1, option.logValue)
            XCTAssertEqual(
                engine.reviewedIntents,
                [.wallet(spending: [.init(assetId: tronUsdt.asset.assetId, symbol: "TEST", decimals: 6, amount: 9_191_671)], to: Self.tronDeposit)],
                option.logValue
            )
            XCTAssertEqual(engine.sentFees.count, 1, option.logValue)
        }
    }

    /// The checks only shadow a TON battery relay, which names no address of its route, and a fee in
    /// a token until the backend confirms the relayer's fee on its payload: the swap goes on for a
    /// user who would have refused.
    func testATonBatteryRelayAndATokenFeeAreReviewedWithoutAsking() async throws {
        let token = MultichainSwapFeeOption(cost: .token(Self.usdt, amount: 115_304, isInsufficient: false))
        let battery = MultichainSwapFeeOption(cost: .batteryCharges(count: 3, excess: nil, isInsufficient: false))
        let cases: [(StubRelayedFeeEngine.Family, MultichainSwapExecutionPlan, MultichainSwapFeeMethod, String?)] = [
            (.ton, makeExecutionPlan(feeOptions: [battery]), .battery, nil),
            (.evm, makeExecutionPlan(batteryPayload: Self.evmPayload, feeOptions: [token]), token.method, Self.router),
        ]
        for (family, plan, method, recipient) in cases {
            let engine = StubRelayedFeeEngine(family: family, sendResult: .success("relayed-hash"))
            let service = makeExecutionService(swapPipeline: StubChainKitSwapPipeline(), engines: [engine], checks: [WarningCheck()])
            let user = ConsentingUser(answering: false)
            let log = RecordedLog()
            defer { log.stop() }

            let result = try await service.execute(
                passcodeProvider: { "1111" },
                swapWallet: makeSwapWallet(),
                sourceAsset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"),
                destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
                executionPlan: plan,
                feeMethod: method,
                spendLimit: 1000,
                consent: user.attempt()
            )
            let logged = try await log.records("Operation review found what would ask in a flow it only logs", count: 1)

            XCTAssertEqual(result.txHash, "relayed-hash", method.id)
            let asked = await user.asked
            XCTAssertEqual(asked, [], method.id)
            XCTAssertEqual(engine.reviewedIntents.map(\.recipient), [recipient], method.id)
            XCTAssertEqual(engine.sentFees.count, 1, method.id)
            XCTAssertEqual(logged.count, 1, method.id)
        }
    }

    /// What the swap sells is held to the spend limit the user agreed to and to the router its route
    /// calls, and a fee in a token to the most a requote may come to, in the token's own decimals
    /// rather than the sold asset's.
    func testTheReviewHoldsTheSwapToItsSpendLimitAndATokenFeeToItsTolerance() async throws {
        let engine = StubRelayedFeeEngine(family: .evm, sendResult: .success(nil))
        let service = makeExecutionService(swapPipeline: StubChainKitSwapPipeline(), engines: [engine], checks: [WarningCheck()])
        let token = MultichainSwapFeeOption(cost: .token(Self.usdt, amount: 115_304, isInsufficient: false))
        let log = RecordedLog()
        defer { log.stop() }

        _ = try await service.execute(
            passcodeProvider: { "1111" },
            swapWallet: makeSwapWallet(),
            sourceAsset: makeAsset(assetId: "eth/mainnet/coin", decimals: 18),
            destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
            executionPlan: makeExecutionPlan(batteryPayload: Self.evmPayload, feeOptions: [token]),
            feeMethod: token.method,
            spendLimit: 1_000_000_000_000_000,
            consent: .refuse
        )
        _ = try await log.records("Operation review found what would ask in a flow it only logs", count: 1)

        XCTAssertEqual(
            engine.reviewedIntents,
            [
                .wallet(
                    spending: [.init(assetId: "eth/mainnet/coin", symbol: "TEST", decimals: 18, amount: 1_000_000_000_000_000)],
                    relayerFee: .init(assetId: Self.usdt.assetId, symbol: "USDT", decimals: 6, amount: 121_069),
                    to: Self.router
                ),
            ]
        )
        XCTAssertEqual(engine.sentFees, [.token(assetId: Self.usdt.assetId, amount: 115_304)])
    }

    /// A review that could not be made fails the swap as an internal error: never as the user's
    /// cancel, never as an expired quote, and with nothing relayed.
    func testARelayedSwapThatCannotBeReviewedIsNotRelayed() async {
        let engine = StubRelayedFeeEngine(family: .evm, sendResult: .success("relayed-hash"))
        let service = makeExecutionService(swapPipeline: StubChainKitSwapPipeline(), engines: [engine], checks: [FailingCheck()])
        let user = ConsentingUser(answering: true)

        do {
            _ = try await service.execute(
                passcodeProvider: { "1111" },
                swapWallet: makeSwapWallet(),
                sourceAsset: makeAsset(assetId: Self.usdt.assetId, decimals: 6),
                destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
                executionPlan: makeExecutionPlan(batteryPayload: Self.evmPayload),
                feeMethod: .battery,
                spendLimit: 1_000_000,
                consent: user.attempt()
            )
            XCTFail("relayed a swap no check could read")
        } catch {
            guard case .internal = error else {
                return XCTFail("Unexpected failure \(error)")
            }
        }

        let asked = await user.asked
        XCTAssertEqual(asked, [])
        XCTAssertEqual(engine.sentFees, [])
    }

    /// What the engine prepared has to beat its deadline by a moment: one the user read past is never
    /// sent, and fails as an expired payload, which a fresh quote recovers from.
    func testARelayThatLapsesWhileTheUserReadsIsNotSent() async {
        let clock = PaymentClock(Date(timeIntervalSince1970: 0))
        let engine = StubRelayedFeeEngine(family: .evm, sendResult: .success("relayed-hash"), expiresAt: clock.now.addingTimeInterval(30))
        let service = makeExecutionService(swapPipeline: StubChainKitSwapPipeline(), engines: [engine], checks: [WarningCheck()], clock: clock)
        let user = ConsentingUser(answering: true) { clock.advance(by: 26) }

        do {
            _ = try await service.execute(
                passcodeProvider: { "1111" },
                swapWallet: makeSwapWallet(),
                sourceAsset: makeAsset(assetId: Self.usdt.assetId, decimals: 6),
                destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
                executionPlan: makeExecutionPlan(batteryPayload: Self.evmPayload),
                feeMethod: .battery,
                spendLimit: 1_000_000,
                consent: user.attempt()
            )
            XCTFail("relayed what its deadline no longer covers")
        } catch {
            XCTAssertEqual(error, .payloadExpired(payloadId: "main"))
        }

        XCTAssertEqual(engine.sentFees, [])
    }

    /// The route's own payload expires too, and one the user read past is never sent either.
    func testARouteThatLapsesWhileTheUserReadsIsNotSent() async {
        let clock = PaymentClock(Date(timeIntervalSince1970: 0))
        let engine = StubRelayedFeeEngine(family: .tron, sendResult: .success("tron-hash"))
        let service = makeExecutionService(swapPipeline: StubChainKitSwapPipeline(), engines: [engine], checks: [WarningCheck()], clock: clock)
        let user = ConsentingUser(answering: true) { clock.advance(by: 1000) }

        do {
            _ = try await service.execute(
                passcodeProvider: { "1111" },
                swapWallet: makeSwapWallet(),
                sourceAsset: makeAsset(assetId: "tron/mainnet/coin", decimals: 6),
                destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
                executionPlan: makeExecutionPlan(batteryPayload: Self.tronPayload),
                feeMethod: .battery,
                spendLimit: 9_191_671,
                consent: user.attempt()
            )
            XCTFail("relayed a route that expired")
        } catch {
            XCTAssertEqual(error, .payloadExpired(payloadId: "main"))
        }

        XCTAssertEqual(engine.sentFees, [])
    }

    /// A deadline the device's clock had passed before the review is the relayer's to judge: a clock
    /// running ahead must not fail every relayed swap it reviews.
    func testADeadlineTheClockHadPassedBeforeTheReviewIsLeftToTheRelayer() async throws {
        let clock = PaymentClock(Date(timeIntervalSince1970: 0))
        let engine = StubRelayedFeeEngine(family: .evm, sendResult: .success("relayed-hash"), expiresAt: clock.now.addingTimeInterval(3))
        let service = makeExecutionService(swapPipeline: StubChainKitSwapPipeline(), engines: [engine], checks: [WarningCheck()], clock: clock)
        let user = ConsentingUser(answering: true) { clock.advance(by: 10) }

        let result = try await service.execute(
            passcodeProvider: { "1111" },
            swapWallet: makeSwapWallet(),
            sourceAsset: makeAsset(assetId: Self.usdt.assetId, decimals: 6),
            destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
            executionPlan: makeExecutionPlan(batteryPayload: Self.evmPayload),
            feeMethod: .battery,
            spendLimit: 1_000_000,
            consent: user.attempt()
        )

        XCTAssertEqual(result.txHash, "relayed-hash")
        let asked = await user.asked
        XCTAssertEqual(asked.count, 1)
    }

    /// Each deadline is held on its own: one the device's clock had passed before the review is left
    /// to the relayer, but the other one lapsing while the user reads still stops the swap.
    func testADeadlinePassedBeforeTheReviewDoesNotExcuseTheOther() async {
        // Seconds from the start: when the route's payload and the relay lapse, and how long the
        // engine prepares and the user reads.
        let cases: [(route: TimeInterval, preparing: TimeInterval, relay: TimeInterval, reading: TimeInterval)] = [
            (route: 2, preparing: 3, relay: 33, reading: 60),
            (route: 1000, preparing: 0, relay: 3, reading: 1000),
        ]
        for testCase in cases {
            let clock = PaymentClock(Date(timeIntervalSince1970: 0))
            let engine = StubRelayedFeeEngine(
                family: .evm,
                sendResult: .success("relayed-hash"),
                expiresAt: Date(timeIntervalSince1970: testCase.relay),
                onPrepare: { clock.advance(by: testCase.preparing) }
            )
            let service = makeExecutionService(swapPipeline: StubChainKitSwapPipeline(), engines: [engine], checks: [WarningCheck()], clock: clock)
            let user = ConsentingUser(answering: true) { clock.advance(by: testCase.reading) }

            do {
                _ = try await service.execute(
                    passcodeProvider: { "1111" },
                    swapWallet: makeSwapWallet(),
                    sourceAsset: makeAsset(assetId: Self.usdt.assetId, decimals: 6),
                    destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
                    executionPlan: makeExecutionPlan(batteryPayload: Self.evmPayload, dateExpire: Date(timeIntervalSince1970: testCase.route)),
                    feeMethod: .battery,
                    spendLimit: 1_000_000,
                    consent: user.attempt()
                )
                XCTFail("relayed what lapsed while it was reviewed: \(testCase)")
            } catch {
                XCTAssertEqual(error, .payloadExpired(payloadId: "main"), "\(testCase)")
            }

            XCTAssertEqual(engine.sentFees, [], "\(testCase)")
        }
    }

    /// The chain's own coin is not reviewed until the swap moves to v3: with checks registered,
    /// nothing is built and nobody is asked.
    func testTheChainsOwnCoinIsNeverReviewed() async throws {
        let check = WarningCheck()
        let engine = StubRelayedFeeEngine(sendResult: .success("relayed-hash"))
        let pipeline = StubChainKitSwapPipeline(
            executionResult: MultichainSwapBroadcastResult(txHash: "broadcast-hash", broadcastedPayloads: [])
        )
        let service = makeExecutionService(swapPipeline: pipeline, engines: [engine], checks: [check])
        let user = ConsentingUser(answering: false)

        let result = try await service.execute(
            passcodeProvider: { "1111" },
            swapWallet: makeSwapWallet(),
            sourceAsset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"),
            destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
            executionPlan: makeExecutionPlan(),
            feeMethod: .native,
            spendLimit: 1000,
            consent: user.attempt()
        )

        XCTAssertEqual(result.txHash, "broadcast-hash")
        XCTAssertEqual(pipeline.executedPayloadIds, ["main"])
        let reads = await check.reads.all
        XCTAssertEqual(reads, [])
        let asked = await user.asked
        XCTAssertEqual(asked, [])
        XCTAssertEqual(engine.reviewedIntents, [])
    }

    /// Held to the router its route calls, a relayed batch that pays the source token to anyone else
    /// is a danger chain-kit reads: charges on an EVM chain ask about it once the relayer's operation
    /// is prepared, and a refusal signs and relays nothing.
    func testAnEVMRelayPayingTheSourceTokenPastItsRouterIsAskedAboutAsADanger() async throws {
        let engine = try StubRelayedFeeEngine(
            family: .evm,
            sendResult: .success("relayed-hash"),
            reviewed: Self.reviewing(GaslessFixtures.relayedOperation(calls: [
                (GaslessFixtures.usdtContract, XCTUnwrap(EVMGaslessCall.erc20TransferData(recipient: Self.foreign, amount: 1_000_000))),
                (Self.router, Self.swapData),
            ]))
        )
        let service = makeExecutionService(swapPipeline: StubChainKitSwapPipeline(), engines: [engine], checks: [ChainKitValidationCheck(client: client)])
        let user = ConsentingUser(answering: false)

        do {
            _ = try await service.execute(
                passcodeProvider: { "1111" },
                swapWallet: makeSwapWallet(),
                sourceAsset: makeAsset(assetId: Self.usdt.assetId, decimals: 6),
                destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
                executionPlan: makeExecutionPlan(batteryPayload: Self.evmPayload),
                feeMethod: .battery,
                spendLimit: 1_000_000,
                consent: user.attempt()
            )
            XCTFail("relayed a swap that pays an address its route does not name")
        } catch {
            XCTAssertEqual(error, .canceled)
        }

        let asked = await user.asked
        XCTAssertEqual(asked.map(\.severity), [.danger])
        XCTAssertEqual(asked.map { $0.findings.filter { $0.severity > .info }.map(\.kind) }, [["ChainKitValidationErrorForeignRecipient"]])
        XCTAssertEqual(engine.reviewedIntents.map(\.recipient), [Self.router])
        XCTAssertEqual(engine.sentFees, [])
    }

    /// The route's own call, or the deposit of the source token to the address its route names, is
    /// what the swap agreed to: chain-kit finds nothing to ask about, and the swap is relayed.
    func testAnEVMRelayOfItsRoutesOwnCallIsRelayedWithoutAsking() async throws {
        let deposit = try XCTUnwrap(EVMGaslessCall.swap(
            chain: .eth,
            sender: GaslessFixtures.sender,
            assetId: Self.usdt.assetId,
            to: Self.deposit,
            amount: 1_000_000,
            data: nil
        ))
        let routes: [(payload: MultichainSwapBatteryPayload, call: EVMGaslessCall, recipient: String)] = [
            (Self.evmPayload, Self.routerCall, Self.router),
            (.evm(EVMSwapRelay(chain: .eth, call: deposit)), deposit, Self.deposit),
        ]
        for route in routes {
            let engine = try StubRelayedFeeEngine(
                family: .evm,
                sendResult: .success("relayed-hash"),
                reviewed: Self.reviewing(GaslessFixtures.relayedOperation(calls: [(route.call.to, route.call.data)]))
            )
            let service = makeExecutionService(swapPipeline: StubChainKitSwapPipeline(), engines: [engine], checks: [ChainKitValidationCheck(client: client)])
            let user = ConsentingUser(answering: false)

            let result = try await service.execute(
                passcodeProvider: { "1111" },
                swapWallet: makeSwapWallet(),
                sourceAsset: makeAsset(assetId: Self.usdt.assetId, decimals: 6),
                destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
                executionPlan: makeExecutionPlan(batteryPayload: route.payload),
                feeMethod: .battery,
                spendLimit: 1_000_000,
                consent: user.attempt()
            )

            XCTAssertEqual(result.txHash, "relayed-hash", route.recipient)
            let asked = await user.asked
            XCTAssertEqual(asked, [], route.recipient)
            XCTAssertEqual(engine.reviewedIntents.map(\.recipient), [route.recipient])
        }
    }

    /// A route that sells the chain's own coin sends it as the value of its call, which chain-kit
    /// holds to the amount agreed: the coin the swap sells goes without asking, and what goes past it,
    /// beyond chain-kit's tolerance, is an overspend asked about as a danger.
    func testTheCoinARouteSendsAlongWithItsCallIsHeldToTheAmountAgreed() async throws {
        let agreed: BigUInt = 1_000_000_000_000_000
        let eth = makeAsset(assetId: "eth/mainnet/coin", decimals: 18)
        for (value, isAsked) in [(agreed, false), (agreed * 105 / 100, true)] {
            let engine = try StubRelayedFeeEngine(
                family: .evm,
                sendResult: .success("relayed-hash"),
                reviewed: Self.reviewing(GaslessFixtures.relayedOperation(calls: [(Self.router, Self.swapData)], value: value.description), holding: eth.asset)
            )
            let service = makeExecutionService(swapPipeline: StubChainKitSwapPipeline(), engines: [engine], checks: [ChainKitValidationCheck(client: client)])
            let user = ConsentingUser(answering: true)

            _ = try await service.execute(
                passcodeProvider: { "1111" },
                swapWallet: makeSwapWallet(),
                sourceAsset: eth,
                destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
                executionPlan: makeExecutionPlan(batteryPayload: Self.evmPayload),
                feeMethod: .battery,
                spendLimit: agreed,
                consent: user.attempt()
            )

            let asked = await user.asked
            XCTAssertEqual(
                asked.map { $0.findings.filter { $0.severity > .info }.map(\.kind) },
                isAsked ? [["ChainKitValidationErrorOverspend"]] : [],
                value.description
            )
        }
    }

    /// A TRON relay is held to the deposit address its route pays: a transaction that pays another
    /// address is asked about as a danger before the passcode or the device, and a refusal relays
    /// nothing; one that pays the deposit address goes without asking.
    func testATronRelayPayingAnotherAddressThanItsDepositIsAskedAbout() async throws {
        for (payee, isAsked) in [(Self.tronDeposit, false), (Self.otherTronAddress, true)] {
            let engine = StubRelayedFeeEngine(family: .tron, sendResult: .success("tron-hash"), reviewed: Self.tronPayment(to: payee))
            let service = makeExecutionService(swapPipeline: StubChainKitSwapPipeline(), engines: [engine], checks: [ChainKitValidationCheck(client: client)])
            let user = ConsentingUser(answering: false)

            var failure: MultichainSwapExecutionFailure?
            do {
                _ = try await service.execute(
                    passcodeProvider: { "1111" },
                    swapWallet: makeSwapWallet(),
                    sourceAsset: makeAsset(assetId: "tron/mainnet/coin", decimals: 6),
                    destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
                    executionPlan: makeExecutionPlan(batteryPayload: Self.tronPayload),
                    feeMethod: .battery,
                    spendLimit: 9_191_671,
                    consent: user.attempt()
                )
            } catch {
                failure = error
            }

            let asked = await user.asked
            XCTAssertEqual(
                asked.map { $0.findings.filter { $0.severity > .info }.map(\.kind) },
                isAsked ? [["ChainKitValidationErrorForeignRecipient"]] : [],
                payee
            )
            XCTAssertEqual(failure, isAsked ? .canceled : nil, payee)
            XCTAssertEqual(engine.sentFees.count, isAsked ? 0 : 1, payee)
            XCTAssertEqual(engine.reviewedIntents.map(\.recipient), [Self.tronDeposit], payee)
        }
    }

    /// A relayer paid in a token takes its fee by a transfer in the batch it relays. Where its
    /// payload states the fee, chain-kit holds that transfer to it, and the fee is no spend besides
    /// what the swap sells; where it states none, the fee counts as one, and its transfer, which
    /// pays the relayer rather than the route, is a payment elsewhere. Either way it is only logged.
    func testARelayersTokenFeeIsASpendOnlyWhereItsPayloadStatesNone() async throws {
        let token = MultichainSwapFeeOption(cost: .token(Self.usdt, amount: 115_304, isInsufficient: false))
        let calls = try [
            (GaslessFixtures.usdtContract, XCTUnwrap(EVMGaslessCall.erc20TransferData(recipient: Self.feeRecipient, amount: 115_304))),
            (Self.router, Self.swapData),
        ]
        let cases: [(stated: String?, spends: [String], logged: String)] = [
            ("115304", ["1000000"], "warning:StubWarning"),
            (nil, ["1121069"], "danger:ChainKitValidationErrorForeignRecipient,warning:StubWarning"),
        ]
        for (stated, spends, logged) in cases {
            let label = stated ?? "no fee stated"
            let operation = try GaslessFixtures.relayedOperation(feeAssetId: Self.usdt.assetId, fee: stated, calls: calls, mode: "0x0101000000007821000100000000000000000000000000000000000000000009")
            let engine = StubRelayedFeeEngine(family: .evm, sendResult: .success("relayed-hash"), reviewed: Self.reviewing(operation))
            // The stub's warning has every review log, so the test can wait for one only logged.
            let service = makeExecutionService(
                swapPipeline: StubChainKitSwapPipeline(),
                engines: [engine],
                checks: [ChainKitValidationCheck(client: client), WarningCheck()]
            )
            let log = RecordedLog()
            defer { log.stop() }

            let result = try await service.execute(
                passcodeProvider: { "1111" },
                swapWallet: makeSwapWallet(),
                sourceAsset: makeAsset(assetId: Self.usdt.assetId, decimals: 6),
                destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
                executionPlan: makeExecutionPlan(batteryPayload: Self.evmPayload, feeOptions: [token]),
                feeMethod: token.method,
                spendLimit: 1_000_000,
                consent: ConsentingUser(answering: false).attempt()
            )
            let records = try await log.records("Operation review found what would ask in a flow it only logs", count: 1)

            XCTAssertEqual(result.txHash, "relayed-hash", label)
            let intent = try ChainKitValidationCheck.intent(of: Self.reviewing(operation)(XCTUnwrap(engine.reviewedIntents.first)))
            XCTAssertEqual(intent.spends?.map(\.amount.description), spends, label)
            XCTAssertEqual(records.map { $0.extraInfo["findings"] }, [logged], label)
        }
    }

    /// The swap gate validates unless the boot configuration's `tx_validation_enabled` turns it off,
    /// read at every swap: while it is off nothing is built and the swap goes as it did without checks,
    /// and once a configuration that validates loads, the next swap is read.
    func testTheValidationFlagIsReadAtEverySwapAndOffBuildsNothing() async throws {
        let configuration = KeeperCore.Configuration.review(validates: false, thenValidates: true)
        let engine = try StubRelayedFeeEngine(
            family: .evm,
            sendResult: .success("relayed-hash"),
            reviewed: Self.reviewing(GaslessFixtures.relayedOperation(calls: [
                (GaslessFixtures.usdtContract, XCTUnwrap(EVMGaslessCall.erc20TransferData(recipient: Self.foreign, amount: 1_000_000))),
            ]))
        )
        let service = makeExecutionService(
            swapPipeline: StubChainKitSwapPipeline(),
            engines: [engine],
            gate: OperationGate(configuration: configuration, validatingWith: client)
        )
        let user = ConsentingUser(answering: false)
        func swap() async throws(MultichainSwapExecutionFailure) -> MultichainSwapExecutionResult {
            try await service.execute(
                passcodeProvider: { "1111" },
                swapWallet: makeSwapWallet(),
                sourceAsset: makeAsset(assetId: Self.usdt.assetId, decimals: 6),
                destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
                executionPlan: makeExecutionPlan(batteryPayload: Self.evmPayload),
                feeMethod: .battery,
                spendLimit: 1_000_000,
                consent: user.attempt()
            )
        }

        let unvalidated = try await swap()
        XCTAssertEqual(engine.reviewedIntents, [])
        _ = await configuration.loadConfigurations()
        do {
            _ = try await swap()
            XCTFail("relayed a swap chain-kit flagged")
        } catch {
            XCTAssertEqual(error, .canceled)
        }

        XCTAssertEqual(unvalidated.txHash, "relayed-hash")
        XCTAssertEqual(engine.reviewedIntents.count, 1)
        let asked = await user.asked
        XCTAssertEqual(asked.map(\.severity), [.danger])
        XCTAssertEqual(engine.sentFees.count, 1)
    }
}

private extension MultichainSwapRelayedExecutionTests {
    static let router = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"
    static let swapData = "0x38ed1739"
    static let foreign = "0x00000000000000000000000000000000000000aa"
    static let deposit = "0x1111111111111111111111111111111111111111"
    /// Where the relayer takes a fee in a token.
    static let feeRecipient = "0x45a9034c5dc4e1731b7ff8f977e50012822d5b9d"
    static let tronDeposit = "TU1r33n75FL5dShBt13xcJfgBLuahLgTZo"
    static let otherTronAddress = "TCaxmZvD5kysgFNSqovSpxKKkZdD818cvr"

    static let usdt = MultichainAssetDetails(
        assetId: "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7",
        name: "Tether",
        symbol: "USDT",
        decimals: 6,
        image: ""
    )

    static let routerCall = EVMGaslessCall(kind: .swap, chainId: "eth/mainnet", sender: GaslessFixtures.sender, to: router, value: 0, data: swapData)

    static let evmPayload = MultichainSwapBatteryPayload.evm(EVMSwapRelay(chain: .eth, call: routerCall))

    static let tronPayload = MultichainSwapBatteryPayload.tron(TronSwapTransfer(to: tronDeposit, amount: 9_191_671))

    /// `operation` as the gate reads it: from the account of `asset`, the one the swap sells.
    static func reviewing(_ operation: MultichainRelayedOperation, holding asset: MultichainAssetDetails = usdt) -> (OperationIntent) throws -> SignableOperation {
        { intent in
            try SignableOperation(
                operation: operation.operation,
                account: ChainKitOperationSender.account(of: MultichainWalletAddress(chain: .eth, address: GaslessFixtures.sender), holding: asset),
                intent: intent,
                fidelity: .exact
            )
        }
    }

    /// A payment to `payee` of the TRX a TRON route sells, from the wallet's TRON address.
    static func tronPayment(to payee: String) -> (OperationIntent) throws -> SignableOperation {
        { intent in
            try SignableOperation(
                operation: ChainKitOperationSender.parse(
                    id: "relayed",
                    payloads: #"[{"chain_id":"tron/mainnet","id":"main","type":"main","version":1,"meta":{"to":"\#(payee)","value":"9191671"}}]"#
                ),
                account: ChainKitOperationSender.account(of: MultichainWalletAddress(chain: .tron, address: TronFixture.sender), asset: nil),
                intent: intent,
                fidelity: .exactWrap
            )
        }
    }

    func makeExecutionService(
        swapPipeline: ChainKitSwapPipeline,
        pendingTransactionsService: PendingTransactionsService = PendingTransactionsServiceFake(),
        engines: [any MultichainSwapRelayedFeeEngine],
        checks: [any OperationCheck] = [],
        gate: OperationGate? = nil,
        clock: PaymentClock = PaymentClock(Date(timeIntervalSince1970: 0)),
        batteryPaymentPreparation: BatteryPaymentPreparation = BatteryPaymentPreparation()
    ) -> MultichainSwapExecutionServiceImplementation {
        MultichainSwapExecutionServiceImplementation(
            swapService: StubSwapService(),
            swapAPI: SwapBackend().api,
            swapPipeline: swapPipeline,
            operationSteps: RecordedSwapOperationSteps(),
            pendingTransactionsService: pendingTransactionsService,
            feeMethodResolver: MultichainSwapFeeMethodResolver(engines: engines),
            gate: gate ?? OperationGate { checks },
            now: { clock.now },
            batteryPaymentPreparation: batteryPaymentPreparation
        )
    }

    func makeExecutionPlan(
        batteryPayload: MultichainSwapBatteryPayload = .ton([
            TonSwapMessage(
                to: "0:0000000000000000000000000000000000000000000000000000000000000001",
                amount: 350_000_000,
                payload: "te6cckEBAQEAAgAAAEysuc0=",
                stateInit: nil
            ),
        ]),
        feeOptions: [MultichainSwapFeeOption] = [
            MultichainSwapFeeOption(cost: .batteryCharges(count: 3, excess: nil, isInsufficient: false)),
        ],
        dateExpire: Date = Date(timeIntervalSince1970: 1000)
    ) -> MultichainSwapExecutionPlan {
        MultichainSwapExecutionPlan(
            routeId: "route",
            aggregator: .swapKit,
            providerRouteId: "provider-route",
            payloads: .main(makePayload(dateExpire: dateExpire)),
            networkFees: [],
            feeOptions: feeOptions,
            payloadFees: MultichainSwapPayloadFees(),
            batteryPayload: batteryPayload,
            sourceAmount: "1"
        )
    }

    func makeRoute() -> MultichainSwapRoute {
        MultichainSwapRoute(
            routeId: "route",
            providerRouteId: "provider-route",
            aggregator: "swapkit",
            protocolSlug: "test",
            routeType: "single",
            sourceAmount: "1",
            estimatedDestinationAmount: "1",
            minimumDestinationAmount: "1",
            legs: [],
            dateExpire: Date(timeIntervalSince1970: 1000),
            riskLevel: "low",
            payloads: [makePayload()]
        )
    }

    func makePreparation(
        nativeFeeShortage: MultichainNativeFeeShortage?
    ) -> MultichainSwapPipelinePreparation {
        MultichainSwapPipelinePreparation(
            fees: [
                MultichainTransactionEmulationResult(
                    fee: 350_000_000,
                    asset: .init(
                        assetId: "ton/mainnet/coin",
                        name: "Toncoin",
                        symbol: "TON",
                        decimals: 9,
                        image: ""
                    )
                ),
            ],
            payloadFees: MultichainSwapPayloadFees(),
            requiresApproval: false,
            batteryPayload: .ton([
                TonSwapMessage(
                    to: "0:0000000000000000000000000000000000000000000000000000000000000001",
                    amount: 350_000_000,
                    payload: "te6cckEBAQEAAgAAAEysuc0=",
                    stateInit: nil
                ),
            ]),
            nativeFeeShortage: nativeFeeShortage
        )
    }

    func makeShortage() -> MultichainNativeFeeShortage {
        MultichainNativeFeeShortage(
            asset: .init(
                assetId: "ton/mainnet/coin",
                name: "Toncoin",
                symbol: "TON",
                decimals: 9,
                image: ""
            ),
            requiredAmount: 350_000_000
        )
    }

    func makePayload(dateExpire: Date = Date(timeIntervalSince1970: 1000)) -> MultichainSwapPreparedPayload {
        MultichainSwapPreparedPayload(
            payloadId: "main",
            kind: "main",
            chainId: "ton/mainnet",
            chainFamily: "ton",
            payloadType: "ton_boc",
            payload: "{}",
            humanSummary: MultichainSwapHumanSummary(
                action: "swap",
                spendAsset: "ton/mainnet/jetton/0:jetton-master",
                spendAmount: "1000",
                receiveAsset: "ton/mainnet/coin"
            ),
            validationStatus: "validated",
            dateExpire: dateExpire
        )
    }

    func makeSwapWallet() -> MultichainSwapWallet {
        let state = MultichainWalletState(
            walletId: "multichain-wallet-id",
            addresses: [
                .init(chain: .ton, address: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"),
            ]
        )
        let wallet = Wallet(
            id: "wallet-id",
            identity: .init(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v5R1)
            ),
            metaData: .init(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: .init(isSetupFinished: true),
            batterySettings: .init(),
            multichain: .multichain(state)
        )
        return MultichainSwapWallet(wallet: wallet, registeredState: state)
    }

    func makeAsset(assetId: String, decimals: Int = 9) -> MultichainAsset {
        MultichainAsset(
            asset: .init(
                assetId: assetId,
                name: "Test asset",
                symbol: "TEST",
                decimals: decimals,
                image: ""
            ),
            price: .init(prices: [:], diff24h: [:], diff7d: [:]),
            balance: 0
        )
    }
}

private final class StubRelayedFeeEngine: MultichainSwapRelayedFeeEngine, @unchecked Sendable {
    private(set) var prepareCount = 0
    enum Family {
        case ton
        case tron
        case evm
    }

    private(set) var sentPayloadIds = [String]()
    private(set) var sentFees = [MultichainSwapRelayedFee]()
    /// The intent each review of what a prepared swap signs was built for.
    private(set) var reviewedIntents = [OperationIntent]()
    private let family: Family
    private let optionResults: [MultichainSwapFeeOption]
    private let sendResult: Result<String?, MultichainSwapExecutionFailure>
    private let expiresAt: Date?
    private let onPrepare: () -> Void
    private let onSend: (MultichainTransferSigner) async throws(MultichainSwapExecutionFailure) -> Void
    private let reviewed: (OperationIntent) throws -> SignableOperation

    /// `reviewed` is what the gate reads of the relayer's operation for the intent it is held to.
    init(
        family: Family = .ton,
        optionResults: [MultichainSwapFeeOption] = [],
        sendResult: Result<String?, MultichainSwapExecutionFailure>,
        expiresAt: Date? = nil,
        onPrepare: @escaping () -> Void = {},
        reviewed: @escaping (OperationIntent) throws -> SignableOperation = StubRelayedFeeEngine.callToTheRouter,
        onSend: @escaping (MultichainTransferSigner) async throws(MultichainSwapExecutionFailure) -> Void = { _ in }
    ) {
        self.family = family
        self.optionResults = optionResults
        self.sendResult = sendResult
        self.expiresAt = expiresAt
        self.onPrepare = onPrepare
        self.reviewed = reviewed
        self.onSend = onSend
    }

    var chain: MultichainChain {
        switch family {
        case .ton:
            return .ton
        case .tron:
            return .tron
        case .evm:
            return .eth
        }
    }

    func options(context _: MultichainSwapFeeContext) async -> [MultichainSwapFeeOption] {
        optionResults
    }

    func prepare(
        context: MultichainSwapFeeContext,
        confirmed: MultichainSwapRelayedFee
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapPreparedRelay {
        prepareCount += 1
        onPrepare()
        return MultichainSwapPreparedRelay(
            signables: { intent in
                self.reviewedIntents.append(intent)
                return try [self.reviewed(intent)]
            },
            expiresAt: expiresAt,
            send: { signer throws(MultichainSwapExecutionFailure) in
                try await self.onSend(signer)
                self.sentPayloadIds.append(context.payloadId)
                self.sentFees.append(confirmed)
                return try self.sendResult.get()
            }
        )
    }

    /// The relayer's operation as a call of the router on Ethereum, as chain-kit reads it.
    static func callToTheRouter(intent: OperationIntent) throws -> SignableOperation {
        try SignableOperation(
            operation: ChainKitOperationSender.parse(
                id: "relayed",
                payloads: #"[{"chain_id":"eth/mainnet","id":"main","type":"main","version":1,"meta":{"to":"\#(MultichainSwapRelayedExecutionTests.router)","value":"0"}}]"#
            ),
            account: ChainKitOperationSender.account(of: MultichainWalletAddress(chain: .eth, address: GaslessFixtures.sender), asset: nil),
            intent: intent,
            fidelity: .exact
        )
    }
}

private final class StubChainKitSwapPipeline: ChainKitSwapPipeline, @unchecked Sendable {
    private(set) var executedPayloadIds = [String]()
    private let executionResult: MultichainSwapBroadcastResult?
    private let preparation: MultichainSwapPipelinePreparation?

    init(
        executionResult: MultichainSwapBroadcastResult? = nil,
        preparation: MultichainSwapPipelinePreparation? = nil
    ) {
        self.executionResult = executionResult
        self.preparation = preparation
    }

    func prepareSwapPayloads(
        swapWallet _: MultichainSwapWallet,
        sourceAsset _: MultichainAsset,
        destinationAsset _: MultichainAsset,
        payloads _: MultichainSwapRoutePayloads,
        provider _: MultichainSwapProvider
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapPipelinePreparation {
        guard let preparation else {
            throw .internal(reason: "unimplemented")
        }
        return preparation
    }

    func executeSwapPayloads(
        signer _: MultichainTransferSigner,
        swapWallet _: MultichainSwapWallet,
        sourceAsset _: MultichainAsset,
        destinationAsset _: MultichainAsset,
        payloads: MultichainSwapRoutePayloads,
        payloadFees _: MultichainSwapPayloadFees,
        provider _: MultichainSwapProvider
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapBroadcastResult {
        executedPayloadIds.append(contentsOf: payloads.all.map(\.payloadId))
        guard let executionResult else {
            throw .internal(reason: "unimplemented")
        }
        return executionResult
    }
}

private struct StubSwapService: MultichainSwapService {
    func listCrossSwapAssets(query _: MultichainSwapAssetsQuery) async throws -> [MultichainSwapAsset] {
        []
    }

    func getCrossSwapConfig(
        walletId _: String,
        fromAssetId _: String?,
        toAssetId _: String?
    ) async throws -> MultichainSwapConfig {
        throw StubError.unimplemented
    }

    func createCrossSwapQuote(
        request _: MultichainSwapQuoteRequest,
        walletId _: String?
    ) async throws(MultichainSwapAPIError) -> MultichainSwapQuote {
        throw .unknown(statusCode: -1)
    }

    func createCrossSwapQuoteV3(
        request _: MultichainSwapQuoteRequest,
        walletId _: String
    ) async throws(MultichainSwapAPIError) -> MultichainSwapQuote {
        throw .unknown(statusCode: -1)
    }

    func prepareCrossSwapRoute(
        routeId _: String,
        request _: MultichainSwapPrepareRouteRequest?,
        walletId: String?
    ) async throws -> MultichainSwapPrepare {
        throw StubError.unimplemented
    }
}

private enum StubError: Error {
    case unimplemented
}
