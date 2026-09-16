import BigInt
import ChainKit
@testable import KeeperCore
import TonSwift
import XCTest

/// A swap confirmed with a battery fee method must be sent by that method's engine and by nothing
/// else: falling back to a ChainKit broadcast would spend the coin the user chose not to spend.
final class MultichainSwapBatteryExecutionTests: XCTestCase {
    func testBatteryMethodSendsThroughTheEngine() async throws {
        let engine = StubBatteryFeeEngine(sendResult: .success("relayed-hash"))
        let pipeline = StubChainKitSwapPipeline()
        let pendingTransactions = PendingTransactionsServiceFake()
        let service = makeExecutionService(
            swapPipeline: pipeline,
            pendingTransactionsService: pendingTransactions,
            engines: [engine]
        )

        let result = try await service.execute(
            passcodeProvider: { "1111" },
            wallet: makeWallet(),
            sourceAsset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"),
            destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
            executionPlan: makeExecutionPlan(),
            approvalMode: .exact,
            feeMethod: .battery
        )

        XCTAssertEqual(result.txHash, "relayed-hash")
        XCTAssertEqual(result.broadcastedPayloads.map(\.payloadId), ["main"])
        XCTAssertEqual(engine.sentPayloadIds, ["main"])
        // The price the plan carries is what the engine is asked to honour; anything else would let
        // the relayer bill a swap the user never confirmed.
        XCTAssertEqual(engine.sentCharges, [3])
        XCTAssertEqual(pipeline.executedPayloadIds, [])
        let reported = await pendingTransactions.reported
        XCTAssertEqual(reported.map(\.txHash), ["relayed-hash"])
    }

    func testNativeMethodKeepsUsingThePipeline() async throws {
        let engine = StubBatteryFeeEngine(sendResult: .success("relayed-hash"))
        let pipeline = StubChainKitSwapPipeline(
            executionResult: MultichainSwapBroadcastResult(
                txHash: "broadcast-hash",
                broadcastedPayloads: []
            )
        )
        let service = makeExecutionService(swapPipeline: pipeline, engines: [engine])

        let result = try await service.execute(
            passcodeProvider: { "1111" },
            wallet: makeWallet(),
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
                wallet: makeWallet(),
                sourceAsset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"),
                destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
                executionPlan: makeExecutionPlan(),
                approvalMode: .exact,
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
        let engine = StubBatteryFeeEngine(sendResult: .success("relayed-hash"))
        let pipeline = StubChainKitSwapPipeline()
        let service = makeExecutionService(swapPipeline: pipeline, engines: [engine])

        do {
            _ = try await service.execute(
                passcodeProvider: { "1111" },
                wallet: makeWallet(),
                sourceAsset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"),
                destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
                executionPlan: makeExecutionPlan(feeOptions: [
                    MultichainSwapFeeOption(cost: .batteryCharges(count: 3, excess: nil, isInsufficient: true)),
                ]),
                approvalMode: .exact,
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
        let engine = StubBatteryFeeEngine(
            optionResult: MultichainSwapFeeOption(cost: .batteryCharges(count: 3, excess: nil, isInsufficient: false)),
            sendResult: .success("relayed-hash")
        )
        let service = makeExecutionService(
            swapPipeline: StubChainKitSwapPipeline(
                preparation: makePreparation(nativeFeeShortage: makeShortage())
            ),
            engines: [engine]
        )

        let plan = try await service.prepareExecutionPlan(
            wallet: makeWallet(),
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
        let engine = StubBatteryFeeEngine(sendResult: .success("relayed-hash"))
        let service = makeExecutionService(
            swapPipeline: StubChainKitSwapPipeline(
                preparation: makePreparation(nativeFeeShortage: makeShortage())
            ),
            engines: [engine]
        )

        do {
            _ = try await service.prepareExecutionPlan(
                wallet: makeWallet(),
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

    func testNativeShortageKeepsARefillableBatteryOnTheRoute() async throws {
        let engine = StubBatteryFeeEngine(
            optionResult: MultichainSwapFeeOption(cost: .batteryCharges(count: 3, excess: nil, isInsufficient: true)),
            sendResult: .success("relayed-hash")
        )
        let service = makeExecutionService(
            swapPipeline: StubChainKitSwapPipeline(
                preparation: makePreparation(nativeFeeShortage: makeShortage())
            ),
            engines: [engine]
        )

        let plan = try await service.prepareExecutionPlan(
            wallet: makeWallet(),
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
        let tonEngine = StubBatteryFeeEngine(family: .ton, sendResult: .success("ton-hash"))
        let tronEngine = StubBatteryFeeEngine(family: .tron, sendResult: .success("tron-hash"))
        let service = makeExecutionService(
            swapPipeline: StubChainKitSwapPipeline(),
            engines: [tonEngine, tronEngine]
        )

        let result = try await service.execute(
            passcodeProvider: { "1111" },
            wallet: makeWallet(),
            sourceAsset: makeAsset(assetId: "tron/mainnet/coin"),
            destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
            executionPlan: makeExecutionPlan(
                batteryPayload: .tron(
                    TronSwapTransfer(to: "TDepositAddress", amount: 9_191_671)
                )
            ),
            approvalMode: .exact,
            feeMethod: .battery
        )

        XCTAssertEqual(result.txHash, "tron-hash")
        XCTAssertEqual(tronEngine.sentPayloadIds, ["main"])
        XCTAssertEqual(tonEngine.sentPayloadIds, [])
    }

    func testUnpricedOptionIsNeverRelayed() async {
        let engine = StubBatteryFeeEngine(sendResult: .success("relayed-hash"))
        let pipeline = StubChainKitSwapPipeline()
        let service = makeExecutionService(swapPipeline: pipeline, engines: [engine])

        do {
            _ = try await service.execute(
                passcodeProvider: { "1111" },
                wallet: makeWallet(),
                sourceAsset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"),
                destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
                executionPlan: makeExecutionPlan(feeOptions: [
                    MultichainSwapFeeOption(cost: .batteryUnpriced),
                ]),
                approvalMode: .exact,
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
        let engine = StubBatteryFeeEngine(
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
                wallet: makeWallet(),
                sourceAsset: makeAsset(assetId: "ton/mainnet/jetton/0:jetton-master"),
                destinationAsset: makeAsset(assetId: "ton/mainnet/coin"),
                executionPlan: makeExecutionPlan(),
                approvalMode: .exact,
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
}

private extension MultichainSwapBatteryExecutionTests {
    func makeExecutionService(
        swapPipeline: ChainKitSwapPipeline,
        pendingTransactionsService: PendingTransactionsService = PendingTransactionsServiceFake(),
        engines: [any MultichainSwapBatteryFeeEngine]
    ) -> MultichainSwapExecutionServiceImplementation {
        MultichainSwapExecutionServiceImplementation(
            swapService: StubSwapService(),
            swapPipeline: swapPipeline,
            pendingTransactionsService: pendingTransactionsService,
            feeMethodResolver: MultichainSwapFeeMethodResolver(engines: engines),
            now: { Date(timeIntervalSince1970: 0) }
        )
    }

    func makeExecutionPlan(
        batteryPayload: MultichainSwapBatteryPayload = .ton(
            TonSwapMessage(
                to: "0:0000000000000000000000000000000000000000000000000000000000000001",
                amount: 350_000_000,
                payload: "te6cckEBAQEAAgAAAEysuc0=",
                stateInit: nil
            )
        ),
        feeOptions: [MultichainSwapFeeOption] = [
            MultichainSwapFeeOption(cost: .batteryCharges(count: 3, excess: nil, isInsufficient: false)),
        ]
    ) -> MultichainSwapExecutionPlan {
        MultichainSwapExecutionPlan(
            routeId: "route",
            aggregator: .swapKit,
            providerRouteId: "provider-route",
            payloads: .main(makePayload()),
            networkFees: [],
            feeOptions: feeOptions,
            payloadFees: MultichainSwapPayloadFees(),
            batteryPayload: batteryPayload
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
            batteryPayload: .ton(
                TonSwapMessage(
                    to: "0:0000000000000000000000000000000000000000000000000000000000000001",
                    amount: 350_000_000,
                    payload: "te6cckEBAQEAAgAAAEysuc0=",
                    stateInit: nil
                )
            ),
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

    func makePayload() -> MultichainSwapPreparedPayload {
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
            dateExpire: Date(timeIntervalSince1970: 1000)
        )
    }

    func makeWallet() -> Wallet {
        Wallet(
            id: "wallet-id",
            identity: .init(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v5R1)
            ),
            metaData: .init(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: .init(isSetupFinished: true),
            batterySettings: .init(),
            multichain: .multichain(
                .init(
                    walletId: "multichain-wallet-id",
                    addresses: [
                        .init(chain: .ton, address: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"),
                    ]
                )
            )
        )
    }

    func makeAsset(assetId: String) -> MultichainAsset {
        MultichainAsset(
            asset: .init(
                assetId: assetId,
                name: "Test asset",
                symbol: "TEST",
                decimals: 9,
                image: ""
            ),
            price: .init(prices: [:], diff24h: [:], diff7d: [:], diff30d: [:]),
            balance: 0
        )
    }
}

private final class StubBatteryFeeEngine: MultichainSwapBatteryFeeEngine, @unchecked Sendable {
    enum Family {
        case ton
        case tron
    }

    private(set) var sentPayloadIds = [String]()
    private(set) var sentCharges = [Int]()
    private let family: Family
    private let optionResult: MultichainSwapFeeOption?
    private let sendResult: Result<String, MultichainSwapExecutionFailure>

    init(
        family: Family = .ton,
        optionResult: MultichainSwapFeeOption? = nil,
        sendResult: Result<String, MultichainSwapExecutionFailure>
    ) {
        self.family = family
        self.optionResult = optionResult
        self.sendResult = sendResult
    }

    var chain: MultichainChain {
        switch family {
        case .ton:
            return .ton
        case .tron:
            return .tron
        }
    }

    func option(context _: MultichainSwapFeeContext) async -> MultichainSwapFeeOption? {
        optionResult
    }

    func send(
        context: MultichainSwapFeeContext,
        confirmedCharges: Int,
        passcodeProvider _: @escaping () async -> String?
    ) async throws(MultichainSwapExecutionFailure) -> String {
        sentPayloadIds.append(context.payloadId)
        sentCharges.append(confirmedCharges)
        return try sendResult.get()
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
        wallet _: Wallet,
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
        passcodeProvider _: @escaping () async -> String?,
        wallet _: Wallet,
        sourceAsset _: MultichainAsset,
        destinationAsset _: MultichainAsset,
        payloads: MultichainSwapRoutePayloads,
        payloadFees _: MultichainSwapPayloadFees,
        provider _: MultichainSwapProvider,
        approvalMode _: MultichainSwapApprovalMode
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

    func getCrossSwapAsset(assetId _: String) async throws -> MultichainSwapAsset {
        throw StubError.unimplemented
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
