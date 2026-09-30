import BigInt
import ChainKit
import Foundation
@testable import KeeperCore
import TKLogging
import TonSwift
import XCTest

final class MultichainSwapExecutionTests: XCTestCase {
    func test_transactionFailureLogDescriptionIncludesStageAndErrorKindWithoutReason() {
        let reason = "signature does not match transaction"
        let failure = MultichainTransactionFailure.failedToSign(
            kind: .verificationFailed,
            reason: reason
        )

        XCTAssertEqual(
            failure.logDescription,
            "type=MultichainTransactionFailure, case=failedToSign, kind=verificationFailed"
        )
        XCTAssertFalse(failure.logDescription.contains(reason))
    }

    func test_swapExecutionFailureLogDescriptionIncludesPayloadWithoutReason() {
        let reason = "signature does not match transaction"
        let failure = MultichainSwapExecutionFailure.signingFailed(
            payloadId: "approval-payload",
            kind: .verificationFailed,
            reason: reason
        )

        XCTAssertEqual(
            failure.logDescription,
            "type=MultichainSwapExecutionFailure, case=signingFailed, payloadId=approval-payload, kind=verificationFailed"
        )
        XCTAssertFalse(failure.logDescription.contains(reason))
    }

    func test_swapAPIErrorLogDescriptionIncludesStatusCode() {
        let error = MultichainSwapAPIError.unknown(statusCode: 503)

        XCTAssertEqual(
            error.logDescription,
            "type=KeeperCore.MultichainSwapAPIError, case=unknown, statusCode=503"
        )
    }

    func test_multichainWalletState_addressLookupUsesRequestedChain() {
        let state = MultichainWalletState(
            walletId: "wallet",
            addresses: [
                MultichainWalletAddress(chain: .ton, address: "ton-address"),
                MultichainWalletAddress(chain: .eth, address: "eth-address"),
            ]
        )

        XCTAssertEqual(state.address(for: .eth), "eth-address")
        XCTAssertNil(state.address(for: .btc))
    }

    func test_aggregator_mapsStringsAndCollapsesIntoAProvider() throws {
        XCTAssertEqual(try MultichainSwapAggregator(aggregator: "swapkit"), .swapKit)
        XCTAssertEqual(try MultichainSwapAggregator(aggregator: "omniston"), .omniston)
        XCTAssertEqual(try MultichainSwapAggregator(aggregator: "swapsxyz"), .swapsXyz)
        XCTAssertThrowsError(try MultichainSwapAggregator(aggregator: "unknown")) { error in
            XCTAssertEqual(
                error as? MultichainSwapExecutionFailure,
                .unsupportedAggregator("unknown")
            )
        }

        XCTAssertEqual(MultichainSwapAggregator.swapKit.provider, .swapKit)
        XCTAssertEqual(MultichainSwapAggregator.omniston.provider, .swapXyz)
        XCTAssertEqual(MultichainSwapAggregator.swapsXyz.provider, .swapXyz)
    }

    /// The plan derives the provider, so no caller can report one aggregator while signing as another.
    func test_executionPlan_derivesTheProviderFromItsAggregator() {
        for aggregator in MultichainSwapAggregator.allCases {
            XCTAssertEqual(
                makeExecutionPlan(payloads: .main(makePayload(id: "main", kind: "main")), aggregator: aggregator).provider,
                aggregator.provider,
                "\(aggregator)"
            )
        }
    }

    func test_prepareExecutionPlan_rejectsUnknownAggregatorBeforeEmulation() async throws {
        let payloads = [makePayload(id: "main", kind: "main")]
        let swapService = StubMultichainSwapService(prepare: MultichainSwapPrepare(routeId: "route", payloads: payloads))
        let swapPipeline = StubChainKitSwapPipeline()
        let service = makeExecutionService(
            swapService: swapService,
            swapPipeline: swapPipeline
        )

        do {
            _ = try await service.prepareExecutionPlan(
                wallet: makeWallet(),
                sourceAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
                destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
                route: makeRoute(aggregator: "unknown")
            )
            XCTFail("Expected unsupported aggregator failure")
        } catch {
            XCTAssertEqual(
                error,
                .unsupportedAggregator("unknown")
            )
        }
        XCTAssertTrue(swapPipeline.emulatedPayloadIds.isEmpty)
    }

    func test_prepareExecutionPlan_storesProviderInExecutionPlanAndPassesToPipeline() async throws {
        let payloads = [makePayload(id: "main", kind: "main")]
        let swapService = StubMultichainSwapService(prepare: MultichainSwapPrepare(routeId: "route", payloads: payloads))
        let swapPipeline = StubChainKitSwapPipeline(
            emulationResults: ["main": makeFee(1, assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18)]
        )
        let service = makeExecutionService(
            swapService: swapService,
            swapPipeline: swapPipeline
        )

        let executionPlan = try await service.prepareExecutionPlan(
            wallet: makeWallet(),
            sourceAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
            destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
            route: makeRoute(aggregator: "swapsxyz")
        )

        XCTAssertEqual(executionPlan.provider, .swapXyz)
        XCTAssertEqual(swapPipeline.emulatedProviders, [.swapXyz])
    }

    func test_prepareExecutionPlan_sendsTheWalletIdWithThePrepareRequest() async throws {
        let payloads = [makePayload(id: "main", kind: "main")]
        let swapService = StubMultichainSwapService(prepare: MultichainSwapPrepare(routeId: "route", payloads: payloads))
        let service = makeExecutionService(
            swapService: swapService,
            swapPipeline: StubChainKitSwapPipeline(
                emulationResults: ["main": makeFee(1, assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18)]
            )
        )
        let wallet = makeWallet()

        _ = try await service.prepareExecutionPlan(
            wallet: wallet,
            sourceAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
            destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
            route: makeRoute(aggregator: "swapsxyz")
        )

        XCTAssertEqual(swapService.lastPrepareWalletId, wallet.multichainWalletId)
    }

    func test_prepareExecutionPlan_mapsPrepareTransportFailureToTypedNetworkFailure() async throws {
        let swapService = StubMultichainSwapService(
            prepareError: .transportError(
                diagnostic: MultichainAPIDiagnostic(error: StubError.unimplemented)
            )
        )
        let service = makeExecutionService(swapService: swapService)

        do {
            _ = try await service.prepareExecutionPlan(
                wallet: makeWallet(),
                sourceAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
                destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
                route: makeRoute()
            )
            XCTFail("Expected preparation failure")
        } catch {
            guard case let .preparationFailed(kind, reason) = error else {
                return XCTFail("Expected preparationFailed, got \(error)")
            }
            XCTAssertEqual(kind, .networkError)
            XCTAssertFalse(reason.isEmpty)
        }
    }

    func test_prepareExecutionPlan_logsTypedPipelineFailureWithRouteContext() async throws {
        let backend = SwapRecordingLogBackend()
        let configuration = Log.configuration
        defer { Log.configuration = configuration }
        Log.configuration = LoggingConfiguration(
            minimumSeverity: .debug,
            defaultSubsystem: "test",
            backends: [backend]
        )

        let privateReason = "private backend diagnostic"
        let swapPipeline = StubChainKitSwapPipeline(
            emulationError: .emulationFailed(kind: .networkError, reason: privateReason)
        )
        let service = makeExecutionService(swapPipeline: swapPipeline)

        do {
            _ = try await service.prepareExecutionPlan(
                wallet: makeWallet(),
                sourceAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
                destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
                route: makeRoute(payloads: [makePayload(id: "main", kind: "main")])
            )
            XCTFail("Expected pipeline failure")
        } catch {
            XCTAssertEqual(
                error,
                .emulationFailed(kind: .networkError, reason: privateReason)
            )
        }

        let record = try XCTUnwrap(
            backend.records.first(where: { $0.message == "swap preparation pipeline failed" })
        )
        XCTAssertEqual(
            record.extraInfo["error"],
            "type=MultichainSwapExecutionFailure, case=emulationFailed, kind=networkError"
        )
        XCTAssertEqual(record.extraInfo["routeId"], "route")
        XCTAssertFalse(record.extraInfo.values.joined().contains(privateReason))
    }

    func test_prepareErrorMapper_preservesHTTPFailureCategory() {
        let internalFailure = SwapExecutionFailureMapper.failure(
            from: MultichainSwapAPIError.internalServerError(
                message: "backend failed",
                code: "internal",
                requestId: "request"
            )
        )
        let badResponseFailure = SwapExecutionFailureMapper.failure(
            from: MultichainSwapAPIError.notFound(
                message: "route missing",
                code: nil,
                requestId: nil
            )
        )

        guard case .preparationFailed(kind: .internalError, _) = internalFailure else {
            return XCTFail("Expected internal preparation failure")
        }
        guard case .preparationFailed(kind: .badResponse, _) = badResponseFailure else {
            return XCTFail("Expected bad-response preparation failure")
        }
    }

    func test_execute_passesExecutionPlanProviderToPipeline() async throws {
        let payloads = MultichainSwapRoutePayloads.main(makePayload(id: "main", kind: "main"))
        let swapPipeline = StubChainKitSwapPipeline(
            executionResult: MultichainSwapBroadcastResult(txHash: "main-hash", broadcastedPayloads: [])
        )
        let service = makeExecutionService(swapPipeline: swapPipeline)

        _ = try await service.execute(
            passcodeProvider: { "passcode" },
            wallet: makeWallet(),
            sourceAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
            destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
            executionPlan: makeExecutionPlan(payloads: payloads, aggregator: .swapsXyz)
        )

        XCTAssertEqual(swapPipeline.executedProvider, .swapXyz)
    }

    func test_execute_reportsBroadcastHashAsPendingSwapWithBothLegs() async throws {
        let pendingTransactionsService = PendingTransactionsServiceFake()
        let swapPipeline = StubChainKitSwapPipeline(
            executionResult: MultichainSwapBroadcastResult(txHash: "main-hash", broadcastedPayloads: [])
        )
        let service = makeExecutionService(
            swapPipeline: swapPipeline,
            pendingTransactionsService: pendingTransactionsService
        )

        _ = try await service.execute(
            passcodeProvider: { "passcode" },
            wallet: makeWallet(),
            sourceAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
            destinationAsset: makeAsset(assetId: "eth/mainnet/erc20/0xabc", symbol: "USDT", decimals: 6),
            executionPlan: makeExecutionPlan(
                payloads: .main(makePayload(id: "main", kind: "main"))
            )
        )

        let reported = await pendingTransactionsService.reported
        XCTAssertEqual(
            reported,
            [
                MultichainPendingTransaction(
                    walletId: "wallet",
                    chain: .eth,
                    network: .mainnet,
                    txHash: "main-hash",
                    activityType: .swap(
                        MultichainPendingTransaction.SwapDetails(
                            fromAssetId: "eth/mainnet/coin",
                            toAssetId: "eth/mainnet/erc20/0xabc",
                            quote: .init(aggregator: "swapkit", routeId: "route", providerRouteId: "provider-route")
                        )
                    )
                ),
            ]
        )
    }

    func test_execute_reportsCrossChainBroadcastHashAsPendingSwapToo() async throws {
        let pendingTransactionsService = PendingTransactionsServiceFake()
        let swapPipeline = StubChainKitSwapPipeline(
            executionResult: MultichainSwapBroadcastResult(txHash: "main-hash", broadcastedPayloads: [])
        )
        let service = makeExecutionService(
            swapPipeline: swapPipeline,
            pendingTransactionsService: pendingTransactionsService
        )

        _ = try await service.execute(
            passcodeProvider: { "passcode" },
            wallet: makeWallet(),
            sourceAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
            destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
            executionPlan: makeExecutionPlan(
                payloads: .main(makePayload(id: "main", kind: "main"))
            )
        )

        let reported = await pendingTransactionsService.reported
        XCTAssertEqual(
            reported,
            [
                MultichainPendingTransaction(
                    walletId: "wallet",
                    chain: .eth,
                    network: .mainnet,
                    txHash: "main-hash",
                    activityType: .swap(
                        MultichainPendingTransaction.SwapDetails(
                            fromAssetId: "eth/mainnet/coin",
                            toAssetId: "base/mainnet/coin",
                            quote: .init(aggregator: "swapkit", routeId: "route", providerRouteId: "provider-route")
                        )
                    )
                ),
            ]
        )
    }

    func test_execute_reportsNoPendingTransactionWhenBroadcastFails() async {
        let pendingTransactionsService = PendingTransactionsServiceFake()
        let swapPipeline = StubChainKitSwapPipeline(
            executionError: .broadcastFailed(payloadId: "main", kind: .unknown, reason: "offline")
        )
        let service = makeExecutionService(
            swapPipeline: swapPipeline,
            pendingTransactionsService: pendingTransactionsService
        )

        _ = try? await service.execute(
            passcodeProvider: { "passcode" },
            wallet: makeWallet(),
            sourceAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
            destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
            executionPlan: makeExecutionPlan(
                payloads: .main(makePayload(id: "main", kind: "main"))
            )
        )

        let reported = await pendingTransactionsService.reported
        XCTAssertTrue(reported.isEmpty)
    }

    func test_execute_reportsSwapWithoutProviderRouteIdWhenTheQuoteOmitsIt() async throws {
        let pendingTransactionsService = PendingTransactionsServiceFake()
        let swapPipeline = StubChainKitSwapPipeline(
            executionResult: MultichainSwapBroadcastResult(txHash: "main-hash", broadcastedPayloads: [])
        )
        let service = makeExecutionService(
            swapPipeline: swapPipeline,
            pendingTransactionsService: pendingTransactionsService
        )

        _ = try await service.execute(
            passcodeProvider: { "passcode" },
            wallet: makeWallet(),
            sourceAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
            destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
            executionPlan: makeExecutionPlan(
                payloads: .main(makePayload(id: "main", kind: "main")),
                aggregator: .omniston,
                providerRouteId: nil
            )
        )

        let reported = await pendingTransactionsService.reported
        XCTAssertEqual(
            reported.map(\.activityType),
            [
                .swap(
                    MultichainPendingTransaction.SwapDetails(
                        fromAssetId: "eth/mainnet/coin",
                        toAssetId: "base/mainnet/coin",
                        quote: .init(aggregator: "omniston", routeId: "route")
                    )
                ),
            ]
        )
    }

    /// `provider` collapses `swapsxyz` and `omniston`, so the aggregator the backend needs to
    /// interpret `providerRouteId` can only come from the quote itself; with inline payloads no
    /// prepare call happens, so the quote is the only source of the id as well.
    func test_prepareExecutionPlan_carriesAggregatorAndProviderRouteIdFromTheQuoteWithInlinePayloads() async throws {
        let swapPipeline = StubChainKitSwapPipeline(
            emulationResults: ["main": makeFee(1, assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18)]
        )
        let service = makeExecutionService(swapPipeline: swapPipeline)

        let executionPlan = try await service.prepareExecutionPlan(
            wallet: makeWallet(),
            sourceAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
            destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
            route: makeRoute(
                aggregator: "omniston",
                providerRouteId: "quote-id",
                payloads: [makePayload(id: "main", kind: "main")]
            )
        )

        XCTAssertEqual(executionPlan.aggregator, .omniston)
        XCTAssertEqual(executionPlan.providerRouteId, "quote-id")
        XCTAssertEqual(executionPlan.provider, .swapXyz)
    }

    /// A quote without payloads only carries an id of ours; the aggregator's own id is minted
    /// when the route is built, so the prepare response wins over the quote.
    func test_prepareExecutionPlan_prefersProviderRouteIdFromPrepare() async throws {
        let swapService = StubMultichainSwapService(
            prepare: MultichainSwapPrepare(
                routeId: "route",
                providerRouteId: "prepare-tx-id",
                payloads: [makePayload(id: "main", kind: "main")]
            )
        )
        let swapPipeline = StubChainKitSwapPipeline(
            emulationResults: ["main": makeFee(1, assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18)]
        )
        let service = makeExecutionService(swapService: swapService, swapPipeline: swapPipeline)

        let executionPlan = try await service.prepareExecutionPlan(
            wallet: makeWallet(),
            sourceAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
            destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
            route: makeRoute(aggregator: "swapsxyz", providerRouteId: "quote-id")
        )

        XCTAssertEqual(swapService.prepareCallCount, 1)
        XCTAssertEqual(executionPlan.providerRouteId, "prepare-tx-id")
    }

    func test_prepareExecutionPlan_fallsBackToQuoteProviderRouteIdWhenPrepareOmitsIt() async throws {
        let swapService = StubMultichainSwapService(
            prepare: MultichainSwapPrepare(routeId: "route", payloads: [makePayload(id: "main", kind: "main")])
        )
        let swapPipeline = StubChainKitSwapPipeline(
            emulationResults: ["main": makeFee(1, assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18)]
        )
        let service = makeExecutionService(swapService: swapService, swapPipeline: swapPipeline)

        let executionPlan = try await service.prepareExecutionPlan(
            wallet: makeWallet(),
            sourceAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
            destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
            route: makeRoute(providerRouteId: "quote-id")
        )

        XCTAssertEqual(executionPlan.providerRouteId, "quote-id")
    }

    func test_execute_reportsProviderRouteIdFromPrepare() async throws {
        let pendingTransactionsService = PendingTransactionsServiceFake()
        let swapService = StubMultichainSwapService(
            prepare: MultichainSwapPrepare(
                routeId: "route",
                providerRouteId: "prepare-tx-id",
                payloads: [makePayload(id: "main", kind: "main")]
            )
        )
        let swapPipeline = StubChainKitSwapPipeline(
            emulationResults: ["main": makeFee(1, assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18)],
            executionResult: MultichainSwapBroadcastResult(txHash: "main-hash", broadcastedPayloads: [])
        )
        let service = makeExecutionService(
            swapService: swapService,
            swapPipeline: swapPipeline,
            pendingTransactionsService: pendingTransactionsService
        )
        let sourceAsset = makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18)
        let destinationAsset = makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18)

        let executionPlan = try await service.prepareExecutionPlan(
            wallet: makeWallet(),
            sourceAsset: sourceAsset,
            destinationAsset: destinationAsset,
            route: makeRoute(aggregator: "swapsxyz", providerRouteId: "quote-id")
        )
        _ = try await service.execute(
            passcodeProvider: { "passcode" },
            wallet: makeWallet(),
            sourceAsset: sourceAsset,
            destinationAsset: destinationAsset,
            executionPlan: executionPlan
        )

        let reported = await pendingTransactionsService.reported
        XCTAssertEqual(
            reported.map(\.activityType),
            [
                .swap(
                    MultichainPendingTransaction.SwapDetails(
                        fromAssetId: "eth/mainnet/coin",
                        toAssetId: "base/mainnet/coin",
                        quote: .init(aggregator: "swapsxyz", routeId: "route", providerRouteId: "prepare-tx-id")
                    )
                ),
            ]
        )
    }

    func test_prepareExecutionPlan_usesInlineRoutePayloadsAndSkipsPrepareCall() async throws {
        let payloads = [makePayload(id: "main", kind: "main")]
        let swapService = StubMultichainSwapService()
        let swapPipeline = StubChainKitSwapPipeline(
            emulationResults: ["main": makeFee(1, assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18)]
        )
        let service = makeExecutionService(
            swapService: swapService,
            swapPipeline: swapPipeline
        )

        let executionPlan = try await service.prepareExecutionPlan(
            wallet: makeWallet(),
            sourceAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
            destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
            route: makeRoute(payloads: payloads)
        )

        XCTAssertEqual(swapService.prepareCallCount, 0)
        XCTAssertEqual(executionPlan.payloads.all.map(\.payloadId), ["main"])
    }

    func test_validatedPayloads_rejectsExpiredPayloadBeforeSigning() {
        let service = makeExecutionService(now: Date(timeIntervalSince1970: 100))
        let payload = makePayload(
            id: "expired",
            kind: "main",
            validationStatus: "validated",
            dateExpire: Date(timeIntervalSince1970: 99)
        )

        XCTAssertThrowsError(
            try service.validatedPayloads([payload], routeId: "route")
        ) { error in
            XCTAssertEqual(
                error as? MultichainSwapExecutionFailure,
                .payloadExpired(payloadId: "expired")
            )
        }
    }

    func test_validatedPayloads_rejectsNonValidatedPayloadBeforeSigning() {
        let service = makeExecutionService(now: Date(timeIntervalSince1970: 100))
        let payload = makePayload(
            id: "pending",
            kind: "main",
            validationStatus: "pending",
            dateExpire: Date(timeIntervalSince1970: 101)
        )

        XCTAssertThrowsError(
            try service.validatedPayloads([payload], routeId: "route")
        ) { error in
            XCTAssertEqual(
                error as? MultichainSwapExecutionFailure,
                .payloadNotValidated(payloadId: "pending", status: "pending")
            )
        }
    }

    func test_prepareExecutionPlan_aggregatesFeesForAllPreparedPayloadsByAsset() async throws {
        let payloads = [
            makePayload(id: "approval", kind: "approval"),
            makePayload(id: "main", kind: "main"),
        ]
        let swapService = StubMultichainSwapService(prepare: MultichainSwapPrepare(routeId: "route", payloads: payloads))
        let swapPipeline = StubChainKitSwapPipeline(
            emulationResults: [
                "approval": makeFee(1, assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
                "main": makeFee(2, assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
            ],
            emulationFees: ["main": makeChainKitFee(limit: 2, price: 1)]
        )
        let service = makeExecutionService(
            swapService: swapService,
            swapPipeline: swapPipeline
        )

        let executionPlan = try await service.prepareExecutionPlan(
            wallet: makeWallet(),
            sourceAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
            destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
            route: makeRoute()
        )

        XCTAssertEqual(swapPipeline.emulatedPayloadIds, ["approval", "main"])
        XCTAssertEqual(executionPlan.routeId, "route")
        XCTAssertEqual(executionPlan.payloads.all.map(\.payloadId), ["approval", "main"])
        XCTAssertEqual(executionPlan.networkFees.map(\.asset.assetId), ["eth/mainnet/coin"])
        XCTAssertEqual(executionPlan.networkFees.map(\.fee), [BigUInt(3)])
        XCTAssertEqual(executionPlan.payloadFees.payloadIds.sorted(), ["main"])
    }

    func test_aggregatedFees_sumsByAssetPreservingFirstSeenOrder() {
        let aggregated = MultichainSwapExecutionServiceImplementation.aggregatedFees([
            makeFee(1, assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
            makeFee(5, assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9),
            makeFee(2, assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
        ])

        XCTAssertEqual(aggregated.map(\.asset.assetId), ["eth/mainnet/coin", "ton/mainnet/coin"])
        XCTAssertEqual(aggregated.map(\.fee), [BigUInt(3), BigUInt(5)])
    }

    func test_prepareExecutionPlan_throwsWhenAnyPayloadFeeEmulationFails() async throws {
        let payloads = [
            makePayload(id: "approval", kind: "approval"),
            makePayload(id: "main", kind: "main"),
        ]
        let swapService = StubMultichainSwapService(prepare: MultichainSwapPrepare(routeId: "route", payloads: payloads))
        let swapPipeline = StubChainKitSwapPipeline(
            emulationResults: [
                "approval": makeFee(1, assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
            ]
        )
        let service = makeExecutionService(
            swapService: swapService,
            swapPipeline: swapPipeline
        )

        do {
            _ = try await service.prepareExecutionPlan(
                wallet: makeWallet(),
                sourceAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
                destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
                route: makeRoute()
            )
            XCTFail("Expected preparation failure")
        } catch {
            guard case .emulationFailed = error else {
                return XCTFail("Expected emulationFailed, got \(error)")
            }
        }
        XCTAssertEqual(swapPipeline.emulatedPayloadIds, ["approval", "main"])
    }

    func test_prepareExecutionPlan_preservesPayloadAdapterInvalidPayloadFailure() async throws {
        let expected = MultichainSwapExecutionFailure.invalidPayload(
            payloadId: "main",
            reason: "bad payload"
        )
        let payloads = [makePayload(id: "main", kind: "main")]
        let swapService = StubMultichainSwapService(prepare: MultichainSwapPrepare(routeId: "route", payloads: payloads))
        let swapPipeline = StubChainKitSwapPipeline(emulationError: expected)
        let service = makeExecutionService(
            swapService: swapService,
            swapPipeline: swapPipeline
        )

        do {
            _ = try await service.prepareExecutionPlan(
                wallet: makeWallet(),
                sourceAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
                destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
                route: makeRoute()
            )
            XCTFail("Expected invalid payload failure")
        } catch {
            XCTAssertEqual(error, expected)
        }
    }

    func test_prepareExecutionPlan_preservesInsufficientNativeFeeFailure() async throws {
        let expected = MultichainSwapExecutionFailure.insufficientNativeFee(
            shortage: MultichainNativeFeeShortage(
                asset: MultichainAssetDetails(
                    assetId: "base/mainnet/coin",
                    name: "Ethereum",
                    symbol: "ETH",
                    decimals: 18,
                    image: ""
                ),
                requiredAmount: 42
            )
        )
        let payloads = [makePayload(id: "main", kind: "main")]
        let swapService = StubMultichainSwapService(prepare: MultichainSwapPrepare(routeId: "route", payloads: payloads))
        let swapPipeline = StubChainKitSwapPipeline(emulationError: expected)
        let service = makeExecutionService(
            swapService: swapService,
            swapPipeline: swapPipeline
        )

        do {
            _ = try await service.prepareExecutionPlan(
                wallet: makeWallet(),
                sourceAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
                destinationAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
                route: makeRoute()
            )
            XCTFail("Expected insufficient native fee failure")
        } catch {
            XCTAssertEqual(error, expected)
        }
    }

    func test_prepareExecutionPlan_preservesPayloadAdapterMissingWalletAddressFailure() async throws {
        let expected = MultichainSwapExecutionFailure.missingWalletAddress(chain: .eth)
        let payloads = [makePayload(id: "main", kind: "main")]
        let swapService = StubMultichainSwapService(prepare: MultichainSwapPrepare(routeId: "route", payloads: payloads))
        let swapPipeline = StubChainKitSwapPipeline(emulationError: expected)
        let service = makeExecutionService(
            swapService: swapService,
            swapPipeline: swapPipeline
        )

        do {
            _ = try await service.prepareExecutionPlan(
                wallet: makeWallet(),
                sourceAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
                destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
                route: makeRoute()
            )
            XCTFail("Expected missing wallet address failure")
        } catch {
            XCTAssertEqual(error, expected)
        }
    }

    func test_prepareExecutionPlan_rejectsPayloadsWithoutMainTransaction() async throws {
        let payloads = [makePayload(id: "approval", kind: "approval")]
        let swapService = StubMultichainSwapService(prepare: MultichainSwapPrepare(routeId: "route", payloads: payloads))
        let service = makeExecutionService(swapService: swapService)

        do {
            _ = try await service.prepareExecutionPlan(
                wallet: makeWallet(),
                sourceAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
                destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
                route: makeRoute()
            )
            XCTFail("Expected missing main payload failure")
        } catch {
            XCTAssertEqual(error, .missingMainPayload(routeId: "route"))
        }
    }

    func test_execute_broadcastsPreparedPayloadsWithClientSideChainKit() async throws {
        let payloads = MultichainSwapRoutePayloads.approvalThenMain(
            approval: makePayload(id: "approval", kind: "approval"),
            main: makePayload(id: "main", kind: "main")
        )
        let swapService = StubMultichainSwapService()
        let swapPipeline = StubChainKitSwapPipeline(
            executionResult: MultichainSwapBroadcastResult(
                txHash: "main-hash",
                broadcastedPayloads: [
                    MultichainSwapBroadcastedPayload(
                        payloadId: "approval",
                        kind: "approval",
                        payloadType: "evm_tx",
                        txHash: "approval-hash"
                    ),
                    MultichainSwapBroadcastedPayload(
                        payloadId: "main",
                        kind: "main",
                        payloadType: "evm_tx",
                        txHash: "main-hash"
                    ),
                ]
            )
        )
        let service = makeExecutionService(
            swapService: swapService,
            swapPipeline: swapPipeline
        )

        let result = try await service.execute(
            passcodeProvider: { "passcode" },
            wallet: makeWallet(),
            sourceAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
            destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
            executionPlan: makeExecutionPlan(payloads: payloads),
            approvalMode: .unlimited
        )

        XCTAssertEqual(swapService.prepareCallCount, 0)
        XCTAssertEqual(swapPipeline.executedPayloadIds, ["approval", "main"])
        XCTAssertEqual(swapPipeline.executedApprovalMode, .unlimited)
        XCTAssertEqual(result.routeId, "route")
        XCTAssertEqual(result.txHash, "main-hash")
        XCTAssertEqual(result.broadcastedPayloads.map(\.txHash), ["approval-hash", "main-hash"])
    }

    func test_execute_passesExecutionPlanFeesToSigning() async throws {
        let payloads = MultichainSwapRoutePayloads.main(makePayload(id: "main", kind: "main"))
        let swapPipeline = StubChainKitSwapPipeline(
            executionResult: MultichainSwapBroadcastResult(
                txHash: "main-hash",
                broadcastedPayloads: []
            )
        )
        let service = makeExecutionService(swapPipeline: swapPipeline)

        _ = try await service.execute(
            passcodeProvider: { "passcode" },
            wallet: makeWallet(),
            sourceAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
            destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
            executionPlan: makeExecutionPlan(
                payloads: payloads,
                payloadFees: ["main": makeChainKitFee(limit: 21000, price: 2)]
            )
        )

        XCTAssertEqual(swapPipeline.executedPayloadFeeIds, ["main"])
    }

    func test_execute_rejectsExpiredExecutionPlanPayload() async throws {
        let payloads = MultichainSwapRoutePayloads.main(
            makePayload(
                id: "main",
                kind: "main",
                dateExpire: Date(timeIntervalSince1970: 99)
            )
        )
        let service = makeExecutionService(now: Date(timeIntervalSince1970: 100))

        do {
            _ = try await service.execute(
                passcodeProvider: { "passcode" },
                wallet: makeWallet(),
                sourceAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
                destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
                executionPlan: makeExecutionPlan(payloads: payloads)
            )
            XCTFail("Expected expired payload failure")
        } catch {
            XCTAssertEqual(error as? MultichainSwapExecutionFailure, .payloadExpired(payloadId: "main"))
        }
    }

    func test_execute_mapsClientCancellationToExecutionCancellation() async throws {
        let payloads = MultichainSwapRoutePayloads.main(makePayload(id: "main", kind: "main"))
        let swapPipeline = StubChainKitSwapPipeline(executionError: .canceled)
        let service = makeExecutionService(swapPipeline: swapPipeline)

        do {
            _ = try await service.execute(
                passcodeProvider: { nil },
                wallet: makeWallet(),
                sourceAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
                destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
                executionPlan: makeExecutionPlan(payloads: payloads)
            )
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertEqual(error as? MultichainSwapExecutionFailure, .canceled)
        }
    }

    func test_execute_preservesPayloadAdapterUnsupportedPayloadTypeFailure() async throws {
        let expected = MultichainSwapExecutionFailure.unsupportedPayloadType("unknown")
        let payloads = MultichainSwapRoutePayloads.main(makePayload(id: "main", kind: "main"))
        let swapPipeline = StubChainKitSwapPipeline(executionError: expected)
        let service = makeExecutionService(swapPipeline: swapPipeline)

        do {
            _ = try await service.execute(
                passcodeProvider: { "passcode" },
                wallet: makeWallet(),
                sourceAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
                destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
                executionPlan: makeExecutionPlan(payloads: payloads)
            )
            XCTFail("Expected unsupported payload type failure")
        } catch {
            XCTAssertEqual(error as? MultichainSwapExecutionFailure, expected)
        }
    }

    func test_execute_preservesSigningFailurePayloadContext() async throws {
        let failure = try await executeFailure(
            executionError: .signingFailed(
                payloadId: "approval",
                kind: .dustAmount,
                reason: "sign failed"
            )
        )

        guard case let .signingFailed(payloadId, kind, reason) = failure else {
            return XCTFail("Expected signingFailed, got \(failure)")
        }
        XCTAssertEqual(payloadId, "approval")
        XCTAssertEqual(kind, .dustAmount)
        XCTAssertEqual(reason, "sign failed")
    }

    func test_execute_preservesNonceFailurePayloadContext() async throws {
        let failure = try await executeFailure(
            executionError: .nonceFailed(
                payloadId: "main",
                kind: .noAvailableNodes,
                reason: "nonce failed"
            )
        )

        guard case let .nonceFailed(payloadId, kind, reason) = failure else {
            return XCTFail("Expected nonceFailed, got \(failure)")
        }
        XCTAssertEqual(payloadId, "main")
        XCTAssertEqual(kind, .noAvailableNodes)
        XCTAssertEqual(reason, "nonce failed")
    }

    func test_execute_preservesEmulationFailure() async throws {
        let failure = try await executeFailure(
            executionError: .emulationFailed(kind: .utxoError, reason: "fee failed")
        )

        guard case let .emulationFailed(kind, reason) = failure else {
            return XCTFail("Expected emulationFailed, got \(failure)")
        }
        XCTAssertEqual(kind, .utxoError)
        XCTAssertTrue(reason.contains("fee failed"))
    }

    func test_execute_preservesBroadcastFailurePayloadContext() async throws {
        let failure = try await executeFailure(
            executionError: .broadcastFailed(
                payloadId: "approval",
                kind: .networkError,
                reason: "node failed"
            )
        )

        guard case let .broadcastFailed(payloadId, kind, reason) = failure else {
            return XCTFail("Expected broadcastFailed, got \(failure)")
        }
        XCTAssertEqual(payloadId, "approval")
        XCTAssertEqual(kind, .networkError)
        XCTAssertEqual(reason, "node failed")
    }

    func test_errorKindClassifier_mirrorsAndroidParsers() {
        XCTAssertEqual(
            ChainKitErrorKindClassifier.kind(signError: SignError.DustAmount(message: "dust")),
            .dustAmount
        )
        XCTAssertEqual(
            ChainKitErrorKindClassifier.kind(signError: SignError.InsufficientInputs(message: "inputs")),
            .insufficientBalance
        )
        XCTAssertEqual(
            ChainKitErrorKindClassifier.kind(signError: SignError.Unknown(cause: nil)),
            .unknown
        )
        XCTAssertEqual(
            ChainKitErrorKindClassifier.kind(signError: nil),
            .unknown
        )
        XCTAssertEqual(
            ChainKitErrorKindClassifier.kind(nodeError: NodeError.NoAvailableNodes(chain: ChainBitcoinMainnet.shared)),
            .noAvailableNodes
        )
        XCTAssertEqual(
            ChainKitErrorKindClassifier.kind(nodeError: NodeError.Unauthorized()),
            .unauthorized
        )
        XCTAssertEqual(
            ChainKitErrorKindClassifier.kind(chainError: ChainError.BitcoinDustError(message: "dust")),
            .dustAmount
        )
        XCTAssertEqual(
            ChainKitErrorKindClassifier.kind(chainError: ChainError.UtxoError(message: "utxo")),
            .utxoError
        )
        XCTAssertEqual(
            ChainKitErrorKindClassifier.kind(chainError: ChainError.BadResponse(cause: nil, message: "bad")),
            .badResponse
        )
    }

    func test_validatedPayloads_requiresMainPayload() {
        let service = makeExecutionService(now: Date(timeIntervalSince1970: 100))

        XCTAssertThrowsError(
            try service.validatedPayloads(
                [makePayload(id: "approval", kind: "approval")],
                routeId: "route"
            )
        ) { error in
            XCTAssertEqual(
                error as? MultichainSwapExecutionFailure,
                .missingMainPayload(routeId: "route")
            )
        }
    }

    func test_validatedPayloads_rejectsUnknownPayloadKind() {
        let service = makeExecutionService(now: Date(timeIntervalSince1970: 100))

        XCTAssertThrowsError(
            try service.validatedPayloads(
                [
                    makePayload(id: "main", kind: "main"),
                    makePayload(id: "other", kind: "custom"),
                ],
                routeId: "route"
            )
        ) { error in
            XCTAssertEqual(
                error as? MultichainSwapExecutionFailure,
                .invalidPayload(payloadId: "other", reason: "unsupported payload kind custom")
            )
        }
    }

    func test_realPipeline_preparesApprovalWithFallbackAndCombinedReserve() async throws {
        let stages = RecordingSwapPipelineStages()
        let pipeline = ChainKitSwapPipelineImplementation(stages: stages)
        let payloads = makePipelinePayloads()

        let preparation = try await pipeline.prepareSwapPayloads(
            wallet: makeWallet(),
            sourceAsset: makeAsset(
                assetId: "eth/mainnet/erc20/0x4444444444444444444444444444444444444444",
                symbol: "USDT",
                decimals: 6
            ),
            destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
            payloads: payloads,
            provider: .swapKit
        )

        XCTAssertTrue(preparation.requiresApproval)
        XCTAssertEqual(preparation.payloadFees.payloadIds.sorted(), ["approval", "main"])
        XCTAssertEqual(preparation.fees.map(\.fee), [10, 15])
        XCTAssertEqual(stages.events, ["fee:main", "build:exact", "reserve:25"])
        XCTAssertEqual(stages.approvalFeeInputs, [nil])
    }

    func test_realPipeline_keepsTheReserveFatalWithoutARelayableMessage() async {
        let shortage = MultichainNativeFeeShortage(
            asset: .init(
                assetId: "eth/mainnet/coin",
                name: "Ether",
                symbol: "ETH",
                decimals: 18,
                image: ""
            ),
            requiredAmount: 10
        )
        let stages = RecordingSwapPipelineStages(reserveShortage: shortage)
        let pipeline = ChainKitSwapPipelineImplementation(stages: stages)

        do {
            _ = try await pipeline.prepareSwapPayloads(
                wallet: makeWallet(),
                sourceAsset: makeAsset(
                    assetId: "eth/mainnet/erc20/0x4444444444444444444444444444444444444444",
                    symbol: "USDT",
                    decimals: 6
                ),
                destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
                payloads: makePipelinePayloads(),
                provider: .swapKit
            )
            XCTFail("Expected the reserve failure to fail the preparation")
        } catch {
            guard case .insufficientNativeFee = error else {
                return XCTFail("Unexpected failure \(error)")
            }
        }
    }

    func test_realPipeline_reportsANativeShortageWhenPricingFailsOnAWalletThatCannotPay() async {
        let shortage = MultichainNativeFeeShortage(
            asset: .init(
                assetId: "eth/mainnet/coin",
                name: "Ether",
                symbol: "ETH",
                decimals: 18,
                image: ""
            ),
            requiredAmount: 12
        )
        let stages = RecordingSwapPipelineStages(
            reserveShortage: shortage,
            feeFailure: .emulationFailed(kind: .unknown, reason: "node rejected the message")
        )
        let pipeline = ChainKitSwapPipelineImplementation(stages: stages)

        do {
            _ = try await pipeline.prepareSwapPayloads(
                wallet: makeWallet(),
                sourceAsset: makeAsset(
                    assetId: "eth/mainnet/erc20/0x4444444444444444444444444444444444444444",
                    symbol: "USDT",
                    decimals: 6
                ),
                destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
                payloads: makePipelinePayloads(),
                provider: .swapKit
            )
            XCTFail("Expected the fee failure to fail the preparation")
        } catch {
            guard case let .insufficientNativeFee(reported) = error else {
                return XCTFail("Unexpected failure \(error)")
            }
            XCTAssertEqual(reported, shortage)
        }
        XCTAssertEqual(stages.events, ["fee:main", "defaultFee:main", "reserve:12"])
    }

    func test_realPipeline_keepsARelayableRouteAliveWhenPricingFailsOnAWalletThatCannotPay() async throws {
        let shortage = MultichainNativeFeeShortage(
            asset: .init(
                assetId: "ton/mainnet/coin",
                name: "Toncoin",
                symbol: "TON",
                decimals: 9,
                image: ""
            ),
            requiredAmount: 12
        )
        let stages = RecordingSwapPipelineStages(
            reserveShortage: shortage,
            feeFailure: .emulationFailed(kind: .unknown, reason: "node rejected the message")
        )
        let pipeline = ChainKitSwapPipelineImplementation(stages: stages)

        let preparation = try await pipeline.prepareSwapPayloads(
            wallet: makeWallet(),
            sourceAsset: makeAsset(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9),
            destinationAsset: makeAsset(assetId: "btc/mainnet/coin", symbol: "BTC", decimals: 8),
            payloads: makeRelayableTonPayloads(),
            provider: .swapXyz
        )

        XCTAssertNotNil(preparation.batteryPayload)
        XCTAssertEqual(preparation.nativeFeeShortage, shortage)
        XCTAssertEqual(preparation.fees.map(\.fee), [12])
        XCTAssertEqual(stages.events, ["fee:main", "defaultFee:main", "reserve:12", "reserve:12"])
    }

    func test_realPipeline_keepsThePricingFailureWhenTheBalanceCoversTheDefaultFee() async {
        let failure = MultichainSwapExecutionFailure.emulationFailed(
            kind: .unknown,
            reason: "node rejected the message"
        )
        let stages = RecordingSwapPipelineStages(feeFailure: failure)
        let pipeline = ChainKitSwapPipelineImplementation(stages: stages)

        do {
            _ = try await pipeline.prepareSwapPayloads(
                wallet: makeWallet(),
                sourceAsset: makeAsset(
                    assetId: "eth/mainnet/erc20/0x4444444444444444444444444444444444444444",
                    symbol: "USDT",
                    decimals: 6
                ),
                destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
                payloads: makePipelinePayloads(),
                provider: .swapKit
            )
            XCTFail("Expected the fee failure to fail the preparation")
        } catch {
            XCTAssertEqual(error, failure)
        }
        XCTAssertEqual(stages.events, ["fee:main", "defaultFee:main", "reserve:12"])
    }

    func test_realPipeline_executesApprovalAtNThenAdjustedMainAtNPlusOne() async throws {
        let stages = RecordingSwapPipelineStages()
        let pipeline = ChainKitSwapPipelineImplementation(stages: stages)
        let payloads = makePipelinePayloads()
        let fees = MultichainSwapPayloadFees([
            "main": stages.mainFee,
            "approval": stages.approvalFee,
        ])

        let result = try await pipeline.executeSwapPayloads(
            passcodeProvider: { "passcode" },
            wallet: makeWallet(),
            sourceAsset: makeAsset(
                assetId: "eth/mainnet/erc20/0x4444444444444444444444444444444444444444",
                symbol: "USDT",
                decimals: 6
            ),
            destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
            payloads: payloads,
            payloadFees: fees,
            provider: .swapKit,
            approvalMode: .unlimited
        )

        XCTAssertEqual(result.txHash, "hash-main")
        XCTAssertEqual(result.broadcastedPayloads.map(\.payloadId), ["approval", "main"])
        XCTAssertEqual(
            stages.events,
            [
                "fee:main",
                "build:unlimited",
                "unlock",
                "nonce:main",
                "reserve:25",
                "build:unlimited",
                "submit:approval:7:0",
                "submit:main:8:7",
            ]
        )
        XCTAssertEqual(stages.approvalMainAmounts, ["1", "7"])
        XCTAssertEqual(stages.reservePolicies, [.shrinktofit])
    }

    /// An `exact` main payload reserves with `DrainOrError` and goes out with the quoted amount
    /// even when the reserve hands back a trimmed one: the approval is built against, and the
    /// main transaction signed with, the amount the calldata was quoted for.
    func test_realPipeline_exactCalldataKeepsTheQuotedAmount() async throws {
        let stages = RecordingSwapPipelineStages()
        let pipeline = ChainKitSwapPipelineImplementation(stages: stages)
        let payloads = makePipelinePayloads(mainCalldataType: .exact)
        let fees = MultichainSwapPayloadFees([
            "main": stages.mainFee,
            "approval": stages.approvalFee,
        ])

        let result = try await pipeline.executeSwapPayloads(
            passcodeProvider: { "passcode" },
            wallet: makeWallet(),
            sourceAsset: makeAsset(
                assetId: "eth/mainnet/erc20/0x4444444444444444444444444444444444444444",
                symbol: "USDT",
                decimals: 6
            ),
            destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
            payloads: payloads,
            payloadFees: fees,
            provider: .swapKit,
            approvalMode: .unlimited
        )

        XCTAssertEqual(result.txHash, "hash-main")
        XCTAssertEqual(stages.reservePolicies, [.drainorerror])
        XCTAssertEqual(
            stages.events,
            [
                "fee:main",
                "build:unlimited",
                "unlock",
                "nonce:main",
                "reserve:25",
                "build:unlimited",
                "submit:approval:7:0",
                "submit:main:8:1",
            ]
        )
        XCTAssertEqual(stages.approvalMainAmounts, ["1", "1"])
    }

    func test_realPipeline_invalidApprovalFailsBeforeUnlockOrSubmit() async throws {
        let stages = RecordingSwapPipelineStages(failingBuildCall: 1)
        let pipeline = ChainKitSwapPipelineImplementation(stages: stages)

        do {
            _ = try await pipeline.executeSwapPayloads(
                passcodeProvider: { "passcode" },
                wallet: makeWallet(),
                sourceAsset: makeAsset(
                    assetId: "eth/mainnet/erc20/0x4444444444444444444444444444444444444444",
                    symbol: "USDT",
                    decimals: 6
                ),
                destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
                payloads: makePipelinePayloads(),
                payloadFees: [:],
                provider: .swapKit,
                approvalMode: .exact
            )
            XCTFail("Expected invalid approval failure")
        } catch {
            guard case .invalidPayload(payloadId: "approval", _) = error else {
                return XCTFail("Expected invalid approval, got \(error)")
            }
        }
        XCTAssertEqual(stages.events, ["fee:main", "build:exact"])
    }

    func test_realPipeline_approvalBroadcastFailureStopsBeforeMain() async throws {
        let stages = RecordingSwapPipelineStages(failingSubmitPayloadId: "approval")
        let pipeline = ChainKitSwapPipelineImplementation(stages: stages)

        do {
            _ = try await pipeline.executeSwapPayloads(
                passcodeProvider: { "passcode" },
                wallet: makeWallet(),
                sourceAsset: makeAsset(
                    assetId: "eth/mainnet/erc20/0x4444444444444444444444444444444444444444",
                    symbol: "USDT",
                    decimals: 6
                ),
                destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
                payloads: makePipelinePayloads(),
                payloadFees: MultichainSwapPayloadFees([
                    "main": stages.mainFee,
                    "approval": stages.approvalFee,
                ]),
                provider: .swapKit,
                approvalMode: .exact
            )
            XCTFail("Expected approval broadcast failure")
        } catch {
            guard case .broadcastFailed(payloadId: "approval", _, _) = error else {
                return XCTFail("Expected approval broadcast failure, got \(error)")
            }
        }
        XCTAssertTrue(stages.events.contains("submit:approval:7:0"))
        XCTAssertFalse(stages.events.contains { $0.hasPrefix("submit:main") })
    }

    func test_approvalFallback_scalesGasPriceAndAmountByOnePointFive() throws {
        let fee = makeChainKitFee(limit: 2, price: 10)
        let scaled = try XCTUnwrap(
            SwapApprovalTransactionResolver.scaledApprovalFee(from: fee) as? FeeGas
        )

        XCTAssertEqual(scaled.limit.description, "2")
        XCTAssertEqual(scaled.price.description, "15")
        XCTAssertEqual(scaled.amount.description, "30")
    }

    func test_payloadFees_roundTripImmutableFeeSnapshots() throws {
        let one = BignumBigInteger.Companion.shared.fromInt(int: 1)
        let two = BignumBigInteger.Companion.shared.fromInt(int: 2)
        let three = BignumBigInteger.Companion.shared.fromInt(int: 3)
        let four = BignumBigInteger.Companion.shared.fromInt(int: 4)
        let five = BignumBigInteger.Companion.shared.fromInt(int: 5)
        let fees = MultichainSwapPayloadFees([
            "none": FeeNone.shared,
            "value": FeeValue(amount: one),
            "gas": FeeGas(limit: two, price: three, amount: four),
            "eip1559": FeeEip1559(
                limit: one,
                networkPrice: two,
                maxPrice: three,
                minerPrice: four,
                amount: five
            ),
        ])

        XCTAssertTrue(try fees.fee(for: "none") is FeeNone)
        XCTAssertEqual(try fees.fee(for: "value")?.amount.description, "1")

        let gas = try XCTUnwrap(try fees.fee(for: "gas") as? FeeGas)
        XCTAssertEqual(gas.limit.description, "2")
        XCTAssertEqual(gas.price.description, "3")
        XCTAssertEqual(gas.amount.description, "4")

        let eip1559 = try XCTUnwrap(try fees.fee(for: "eip1559") as? FeeEip1559)
        XCTAssertEqual(eip1559.limit.description, "1")
        XCTAssertEqual(eip1559.networkPrice.description, "2")
        XCTAssertEqual(eip1559.maxPrice.description, "3")
        XCTAssertEqual(eip1559.minerPrice.description, "4")
        XCTAssertEqual(eip1559.amount.description, "5")
        XCTAssertNil(try fees.fee(for: "missing"))
    }
}

private extension MultichainSwapExecutionTests {
    func makePayload(
        id: String,
        kind: String,
        payloadType: String = "evm_tx",
        validationStatus: String = "validated",
        dateExpire: Date = Date(timeIntervalSince1970: 1000),
        payloadJSON: String = #"{"to":"0x1111111111111111111111111111111111111111","value":"0x1","data":"0x"}"#,
        calldataPayloadType: MultichainSwapCalldataPayloadType? = nil
    ) -> MultichainSwapPreparedPayload {
        MultichainSwapPreparedPayload(
            payloadId: id,
            kind: kind,
            chainId: "eth/mainnet",
            chainFamily: "evm",
            payloadType: payloadType,
            payload: Data(payloadJSON.utf8).base64EncodedString(),
            humanSummary: MultichainSwapHumanSummary(
                action: "swap",
                spendAsset: "eth/mainnet/coin",
                spendAmount: "1",
                receiveAsset: "base/mainnet/coin"
            ),
            validationStatus: validationStatus,
            dateExpire: dateExpire,
            calldataPayloadType: calldataPayloadType
        )
    }

    func makeRelayableTonPayloads() -> MultichainSwapRoutePayloads {
        let recipient = "UQB0k9JyF2iP0AN_iTYUwt8gmeGWxTlXrbuf3NdNNJSxU2hr"
        let payload = MultichainSwapPreparedPayload(
            payloadId: "main",
            kind: "main",
            chainId: "ton/mainnet",
            chainFamily: "ton",
            payloadType: "ton_boc",
            payload: #"[{"to":"\#(recipient)","value":"700000000","payload":"ton-payload"}]"#,
            humanSummary: MultichainSwapHumanSummary(
                action: "swap",
                spendAsset: "ton/mainnet/coin",
                spendAmount: "1000000000",
                receiveAsset: "btc/mainnet/coin"
            ),
            validationStatus: "validated",
            dateExpire: Date(timeIntervalSince1970: 1000)
        )
        return .main(payload)
    }

    func makeExecutionService(
        now: Date = Date(timeIntervalSince1970: 100),
        swapService: MultichainSwapService = StubMultichainSwapService(),
        swapPipeline: ChainKitSwapPipeline = StubChainKitSwapPipeline(),
        pendingTransactionsService: PendingTransactionsService = PendingTransactionsServiceFake()
    ) -> MultichainSwapExecutionServiceImplementation {
        MultichainSwapExecutionServiceImplementation(
            swapService: swapService,
            swapPipeline: swapPipeline,
            pendingTransactionsService: pendingTransactionsService,
            feeMethodResolver: MultichainSwapFeeMethodResolver(engines: []),
            now: { now }
        )
    }

    func executeFailure(
        executionError: MultichainSwapExecutionFailure
    ) async throws -> MultichainSwapExecutionFailure {
        let payloads = MultichainSwapRoutePayloads.main(makePayload(id: "main", kind: "main"))
        let swapPipeline = StubChainKitSwapPipeline(executionError: executionError)
        let service = makeExecutionService(swapPipeline: swapPipeline)

        do {
            _ = try await service.execute(
                passcodeProvider: { "passcode" },
                wallet: makeWallet(),
                sourceAsset: makeAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18),
                destinationAsset: makeAsset(assetId: "base/mainnet/coin", symbol: "ETH", decimals: 18),
                executionPlan: makeExecutionPlan(payloads: payloads)
            )
            XCTFail("Expected execution failure")
            return .internal(reason: "test did not throw")
        } catch let failure as MultichainSwapExecutionFailure {
            return failure
        } catch {
            XCTFail("Expected MultichainSwapExecutionFailure, got \(error)")
            return .internal(reason: "\(error)")
        }
    }

    func makeExecutionPlan(
        payloads: MultichainSwapRoutePayloads,
        payloadFees: [String: any Fee] = [:],
        aggregator: MultichainSwapAggregator = .swapKit,
        providerRouteId: String? = "provider-route"
    ) -> MultichainSwapExecutionPlan {
        MultichainSwapExecutionPlan(
            routeId: "route",
            aggregator: aggregator,
            providerRouteId: providerRouteId,
            payloads: payloads,
            networkFees: [],
            payloadFees: MultichainSwapPayloadFees(payloadFees)
        )
    }

    func makeChainKitFee(limit: Int32, price: Int32) -> FeeGas {
        let limitValue = BignumBigInteger.Companion.shared.fromInt(int: limit)
        let priceValue = BignumBigInteger.Companion.shared.fromInt(int: price)
        return FeeGas(
            limit: limitValue,
            price: priceValue,
            amount: limitValue.multiply(other: priceValue)
        )
    }

    func makeWallet() -> Wallet {
        let publicKey = PublicKey(data: Data(repeating: 1, count: 32))
        return Wallet(
            id: "wallet",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v4R2)),
            metaData: WalletMetaData(label: "wallet", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: .multichain(
                MultichainWalletState(
                    walletId: "wallet",
                    addresses: [
                        MultichainWalletAddress(chain: .eth, address: "0x2222222222222222222222222222222222222222"),
                        MultichainWalletAddress(chain: .base, address: "0x3333333333333333333333333333333333333333"),
                        MultichainWalletAddress(
                            chain: .ton,
                            address: "UQDjcVuq603VRoJJBLScazVm04HHMWwpd8dmYsHN4JeROjRZ",
                            type: .tonV4R2
                        ),
                        MultichainWalletAddress(
                            chain: .btc,
                            address: "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
                            type: .btcP2WPKH
                        ),
                    ]
                )
            )
        )
    }

    func makeAsset(
        assetId: String,
        symbol: String,
        decimals: Int
    ) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: assetId,
                name: symbol,
                symbol: symbol,
                decimals: decimals,
                image: ""
            ),
            price: MultichainAssetPrice(prices: [:], diff24h: [:], diff7d: [:], diff30d: [:]),
            balance: 0
        )
    }

    func makeFee(
        _ fee: BigUInt,
        assetId: String,
        symbol: String,
        decimals: Int
    ) -> MultichainTransactionEmulationResult {
        MultichainTransactionEmulationResult(
            fee: fee,
            asset: MultichainAssetDetails(
                assetId: assetId,
                name: symbol,
                symbol: symbol,
                decimals: decimals,
                image: ""
            )
        )
    }

    func makeRoute(
        dateExpire: Date = Date(timeIntervalSince1970: 1000),
        aggregator: String = "swapkit",
        providerRouteId: String? = "provider-route",
        payloads: [MultichainSwapPreparedPayload]? = nil
    ) -> MultichainSwapRoute {
        MultichainSwapRoute(
            routeId: "route",
            providerRouteId: providerRouteId,
            aggregator: aggregator,
            protocolSlug: "test",
            routeType: "single",
            sourceAmount: "1",
            estimatedDestinationAmount: "1",
            minimumDestinationAmount: "1",
            legs: [],
            dateExpire: dateExpire,
            riskLevel: "low",
            payloads: payloads
        )
    }

    func makePipelinePayloads(
        mainCalldataType: MultichainSwapCalldataPayloadType? = nil
    ) -> MultichainSwapRoutePayloads {
        let approvalJSON = #"{"to":"0x4444444444444444444444444444444444444444","value":"0","data":"0x095ea7b3"}"#
        var approval = makePayload(
            id: "approval",
            kind: "approval",
            payloadType: "evm_approval_tx",
            payloadJSON: approvalJSON
        )
        approval.payload = approvalJSON

        // ChainKit parses swap calldata only for an `exact` payload; a `flex` one is a
        // deposit-style transfer it rebuilds itself, so it must not carry calldata.
        let mainJSON = mainCalldataType == .exact
            ? #"{"to":"0x1111111111111111111111111111111111111111","value":"0x1","data":"0xabcdef"}"#
            : #"{"to":"0x1111111111111111111111111111111111111111","value":"0x1","data":"0x"}"#
        var main = makePayload(
            id: "main",
            kind: "main",
            payloadJSON: mainJSON,
            calldataPayloadType: mainCalldataType
        )
        main.payload = mainJSON
        return .approvalThenMain(approval: approval, main: main)
    }
}

private final class StubMultichainSwapService: MultichainSwapService {
    private let prepareResult: MultichainSwapPrepare?
    private let prepareError: MultichainSwapAPIError?
    private(set) var prepareCallCount = 0
    private(set) var lastPrepareRequest: MultichainSwapPrepareRouteRequest?
    private(set) var lastPrepareWalletId: String?

    init(
        prepare: MultichainSwapPrepare? = nil,
        prepareError: MultichainSwapAPIError? = nil
    ) {
        self.prepareResult = prepare
        self.prepareError = prepareError
    }

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
        request: MultichainSwapPrepareRouteRequest?,
        walletId: String?
    ) async throws -> MultichainSwapPrepare {
        prepareCallCount += 1
        lastPrepareRequest = request
        lastPrepareWalletId = walletId
        if let prepareError {
            throw prepareError
        }
        guard let prepareResult else {
            throw StubError.unimplemented
        }
        return prepareResult
    }
}

private final class StubChainKitSwapPipeline: ChainKitSwapPipeline {
    private let emulationResults: [String: MultichainTransactionEmulationResult]
    private let emulationFees: [String: any Fee]
    private let emulationError: MultichainSwapExecutionFailure?
    private let executionResult: MultichainSwapBroadcastResult?
    private let executionError: MultichainSwapExecutionFailure?
    private(set) var emulatedPayloadIds = [String]()
    private(set) var emulatedProviders = [MultichainSwapProvider]()
    private(set) var executedPayloadIds = [String]()
    private(set) var executedPayloadFeeIds = [String]()
    private(set) var executedProvider: MultichainSwapProvider?
    private(set) var executedApprovalMode: MultichainSwapApprovalMode?

    init(
        emulationResults: [String: MultichainTransactionEmulationResult] = [:],
        emulationFees: [String: any Fee] = [:],
        emulationError: MultichainSwapExecutionFailure? = nil,
        executionResult: MultichainSwapBroadcastResult? = nil,
        executionError: MultichainSwapExecutionFailure? = nil
    ) {
        self.emulationResults = emulationResults
        self.emulationFees = emulationFees
        self.emulationError = emulationError
        self.executionResult = executionResult
        self.executionError = executionError
    }

    func prepareSwapPayloads(
        wallet _: Wallet,
        sourceAsset _: MultichainAsset,
        destinationAsset _: MultichainAsset,
        payloads: MultichainSwapRoutePayloads,
        provider: MultichainSwapProvider
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapPipelinePreparation {
        emulatedPayloadIds.append(contentsOf: payloads.all.map(\.payloadId))
        emulatedProviders.append(contentsOf: payloads.all.map { _ in provider })
        if let emulationError {
            throw emulationError
        }
        var fees = [MultichainTransactionEmulationResult]()
        var payloadFees = [String: any Fee]()
        for payload in payloads.all {
            guard let result = emulationResults[payload.payloadId] else {
                throw .emulationFailed(kind: .unknown, reason: "unimplemented")
            }
            fees.append(result)
            if let fee = emulationFees[payload.payloadId] {
                payloadFees[payload.payloadId] = fee
            }
        }
        return MultichainSwapPipelinePreparation(
            fees: fees,
            payloadFees: MultichainSwapPayloadFees(payloadFees),
            requiresApproval: payloads.approval != nil
        )
    }

    func executeSwapPayloads(
        passcodeProvider _: @escaping () async -> String?,
        wallet _: Wallet,
        sourceAsset _: MultichainAsset,
        destinationAsset _: MultichainAsset,
        payloads: MultichainSwapRoutePayloads,
        payloadFees: MultichainSwapPayloadFees,
        provider: MultichainSwapProvider,
        approvalMode: MultichainSwapApprovalMode
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapBroadcastResult {
        executedPayloadIds = payloads.all.map(\.payloadId)
        executedPayloadFeeIds = payloadFees.payloadIds.sorted()
        executedProvider = provider
        executedApprovalMode = approvalMode
        if let executionError {
            throw executionError
        }
        guard let executionResult else {
            throw .internal(reason: "unimplemented")
        }
        return executionResult
    }
}

private final class SwapRecordingLogBackend: LogBackend {
    private(set) var records = [LogRecord]()

    func log(_ record: LogRecord) {
        records.append(record)
    }
}

private final class RecordingSwapPipelineStages: SwapPipelineStageProvider {
    let mainFee: any Fee
    let approvalFee: any Fee
    let defaultFee: any Fee
    private let failingBuildCall: Int?
    private let failingSubmitPayloadId: String?
    private let reserveShortage: MultichainNativeFeeShortage?
    private let feeFailure: MultichainSwapExecutionFailure?
    private var buildCallCount = 0
    private(set) var events = [String]()
    private(set) var approvalFeeInputs = [String?]()
    private(set) var approvalMainAmounts = [String]()
    private(set) var reservePolicies = [GasReservePolicy]()

    init(
        failingBuildCall: Int? = nil,
        failingSubmitPayloadId: String? = nil,
        reserveShortage: MultichainNativeFeeShortage? = nil,
        feeFailure: MultichainSwapExecutionFailure? = nil
    ) {
        self.failingBuildCall = failingBuildCall
        self.failingSubmitPayloadId = failingSubmitPayloadId
        self.reserveShortage = reserveShortage
        self.feeFailure = feeFailure
        mainFee = FeeValue(amount: BignumBigInteger.Companion.shared.fromInt(int: 10))
        approvalFee = FeeValue(amount: BignumBigInteger.Companion.shared.fromInt(int: 15))
        defaultFee = FeeValue(amount: BignumBigInteger.Companion.shared.fromInt(int: 12))
    }

    func resolveFee(
        transaction _: any ChainKit.Transaction,
        payloadFee: (any Fee)?,
        networkType _: ChainKit.Network.Type_,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> any Fee {
        events.append("fee:\(payloadId)")
        if let feeFailure {
            throw feeFailure
        }
        return payloadFee ?? mainFee
    }

    func defaultFee(
        transaction _: any ChainKit.Transaction,
        networkType _: ChainKit.Network.Type_,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> any Fee {
        events.append("defaultFee:\(payloadId)")
        return defaultFee
    }

    func reserve(
        transaction _: TransactionSwap,
        feeAsset _: AssetCoin,
        fee: any Fee,
        policy: GasReservePolicy,
        payloadId _: String
    ) async throws(MultichainSwapExecutionFailure) -> GasReserveResult {
        events.append("reserve:\(fee.amount.description)")
        reservePolicies.append(policy)
        if let reserveShortage {
            throw .insufficientNativeFee(shortage: reserveShortage)
        }
        return GasReserveResult(
            amount: BignumBigInteger.Companion.shared.fromInt(int: 7),
            isAmountAdjusted: true,
            error: nil
        )
    }

    func buildApproval(
        mainTransaction: TransactionSwap,
        approvalData _: String?,
        approvalFee: (any Fee)?,
        mainFee _: any Fee,
        approvalMode: MultichainSwapApprovalMode
    ) -> SwapApprovalTransaction? {
        buildCallCount += 1
        events.append("build:\(approvalMode.rawValue)")
        approvalFeeInputs.append(approvalFee?.amount.description)
        approvalMainAmounts.append(mainTransaction.amount.description)
        if buildCallCount == failingBuildCall {
            return nil
        }
        return SwapApprovalTransaction(
            transaction: TransactionCall(
                account: mainTransaction.account,
                amount: BignumBigInteger.Companion.shared.ZERO,
                energy: mainTransaction.energy,
                contract: mainTransaction.to,
                data: "0x"
            ),
            fee: approvalFee ?? self.approvalFee
        )
    }

    func nonce(
        account _: ChainKit.Account,
        networkType _: ChainKit.Network.Type_,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> BignumBigInteger {
        events.append("nonce:\(payloadId)")
        return BignumBigInteger.Companion.shared.fromInt(int: 7)
    }

    func unlockSigningWallet(
        passcodeProvider _: @escaping () async -> String?,
        wallet _: Wallet
    ) async throws(MultichainSwapExecutionFailure) -> CryptoWallet {
        events.append("unlock")
        do {
            return try CryptoWallet.Companion.shared.fromMnemonic(
                mnemonic_: "circle inch grow apart leaf cool crop tomato confirm teach example curtain"
            )
        } catch {
            throw .internal(reason: "failed to build test wallet: \(error)")
        }
    }

    func signAndBroadcast(
        transaction: any ChainKit.Transaction,
        fee _: any Fee,
        nonce: BignumBigInteger,
        sourceChain _: MultichainChain,
        networkType _: ChainKit.Network.Type_,
        wallet _: CryptoWallet,
        payloadId: String
    ) async throws(MultichainSwapExecutionFailure) -> String {
        events.append(
            "submit:\(payloadId):\(nonce.description):\(transaction.amount.description)"
        )
        if payloadId == failingSubmitPayloadId {
            throw .broadcastFailed(
                payloadId: payloadId,
                kind: .networkError,
                reason: "test failure"
            )
        }
        return "hash-\(payloadId)"
    }
}

private enum StubError: Error {
    case unimplemented
}
