import BigInt
import ChainKit
import Foundation
import HTTPTypes
@testable import KeeperCore
import SwapAPI
import XCTest

/// `/v3/crosschain` read into chain-kit operations, on recorded backend responses
/// (`SwapFixture.responses`).
final class MultichainSwapPreparedOperationTests: XCTestCase {
    private static let recordedSwaps = ["btc_eth", "ton_usdt", "usdteth_eth", "usdttron_ton"]
    private static let walletId = "wallet-1"
    private static let evmWallet = "0x7ECebAF27c989adEF9EA3DD06D316F6F463a5109"
    private static let usdtEthereum = "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7"
    private static let omnistonRouter = "EQAH4MY1EbqP7Gg2wJkoZvoCG4BYPsEG5lVBXPZn0UqXNz4y"
    private static let swapsXyzRouter = "0x1b6257cae4192e62b629efca21771be3d759183d"
    private static let request = MultichainSwapQuoteRequest(
        sourceAsset: usdtEthereum,
        destinationAsset: "eth/mainnet/coin",
        amount: .source(20_000_000),
        senderAddress: evmWallet,
        recipientAddress: evmWallet
    )

    // MARK: - Quote

    func test_aQuoteAsksForTheSwapAsAndroidDoes() async throws {
        let backend = try SwapBackend(answering: SwapFixture.data("confirm_v3_quote_usdteth_eth"))
        var request = Self.request
        request.slippageBps = 100
        request.aggregators = MultichainSwapQuoteRequest.requestedAggregators(isSwapKitEnabled: true)
        request.returnDepositAddress = true

        _ = try await backend.api.createCrossSwapQuoteV3(request: request, walletId: Self.walletId)

        let sent = await backend.request
        let body = await backend.body
        XCTAssertEqual(sent?.method, .post)
        XCTAssertEqual(sent?.path, "/v3/crosschain/quotes")
        XCTAssertEqual(
            try JSONSerialization.jsonObject(with: XCTUnwrap(body)) as? NSDictionary,
            [
                "source_asset": Self.usdtEthereum,
                "source_amount": "20000000",
                "destination_asset": "eth/mainnet/coin",
                "sender_address": Self.evmWallet,
                "recipient_address": Self.evmWallet,
                "slippage_bps": 100,
                "return_deposit_address": true,
                "exact_type": "exact_input",
                "aggregators": ["swapsxyz", "swapkit"],
            ] as NSDictionary
        )
    }

    /// Routes are picked as on `/v2`: swaps.xyz's wherever the backend lists it, and never one of an
    /// aggregator that screened the wallet.
    func test_aQuotesRoutesArePickedAsOnV2() async throws {
        var quote = try await SwapBackend(answering: SwapFixture.data("confirm_v3_quote_usdteth_eth")).api
            .createCrossSwapQuoteV3(request: Self.request, walletId: Self.walletId)
        let now = try XCTUnwrap(quote.routes.first?.dateExpire).addingTimeInterval(-1)
        quote.routes.reverse()

        XCTAssertEqual(quote.routes.map(\.aggregator), ["swapkit", "swapkit", "swapkit", "swapsxyz"])
        XCTAssertEqual(quote.preferredRoute(at: now)?.routeId, "9462c7d9-637c-460e-8a36-a883c00b6f40")

        quote.providerErrors?.append(MultichainSwapProviderError(aggregator: "swapsxyz", code: "wallet_screened", message: "screened"))

        XCTAssertEqual(quote.preferredRoute(at: now)?.routeId, "f5a848a2-59b2-47bc-a2e6-eed867ba9474")
    }

    func test_everyRecordedQuotePicksTheRouteItsPrepareWasMadeFor() async throws {
        for swap in Self.recordedSwaps {
            let quote = try await SwapBackend(answering: SwapFixture.data("confirm_v3_quote_\(swap)")).api
                .createCrossSwapQuoteV3(request: Self.request, walletId: Self.walletId)
            let prepared = try await read(swap)
            let now = try XCTUnwrap(quote.routes.first?.dateExpire).addingTimeInterval(-1)

            XCTAssertTrue(quote.routes.allSatisfy { $0.payloads == nil }, swap)
            XCTAssertEqual(quote.preferredRoute(at: now)?.routeId, prepared.routeId, swap)
            XCTAssertEqual(quote.preferredRoute(at: now)?.aggregator, prepared.aggregator, swap)
        }
    }

    /// A `/v3` route reads field for field as `/v2` reads the same route, and remembers it is `/v3`'s.
    func test_aV3RouteReadsAsAV2One() async throws {
        for swap in Self.recordedSwaps {
            let swapAPI = try SwapBackend(answering: SwapFixture.data("confirm_v3_quote_\(swap)")).api

            let v3 = try await swapAPI.createCrossSwapQuoteV3(request: Self.request, walletId: Self.walletId)
            var v2 = try await swapAPI.createCrossSwapQuote(request: Self.request, walletId: Self.walletId)

            XCTAssertEqual(Set(v2.routes.map(\.apiVersion)), [.v2], swap)
            XCTAssertEqual(Set(v3.routes.map(\.apiVersion)), [.v3], swap)
            v2.routes = v2.routes.map { route in
                var route = route
                route.apiVersion = .v3
                return route
            }
            XCTAssertEqual(v3, v2, swap)
        }
    }

    // MARK: - Prepare

    func test_aRouteIsPreparedWithNoBody() async throws {
        let backend = try SwapBackend(answering: SwapFixture.data("confirm_v3_prepare_ton_usdt"))

        _ = try await backend.api.prepareCrossSwapRouteV3(routeId: "036bb244-764a-4cb0-b5b8-8e1362551794", walletId: Self.walletId)

        let request = await backend.request
        let body = await backend.body
        XCTAssertEqual(request?.method, .post)
        XCTAssertEqual(request?.path, "/v3/crosschain/routes/036bb244-764a-4cb0-b5b8-8e1362551794/prepare")
        XCTAssertNil(body)
    }

    func test_aTonSwapIsItsMessageToTheRouter() async throws {
        let prepared = try await read("ton_usdt")

        XCTAssertEqual(prepared.operation.id, "036bb244-764a-4cb0-b5b8-8e1362551794")
        XCTAssertEqual(prepared.operation.payloads.count, 1)
        let payload = try XCTUnwrap(prepared.operation.payloads.first)
        XCTAssertEqual(payload.chain.caip2, MultichainChain.ton.asChainKitChain.caip2)
        XCTAssertNil(payload.fee)
        let meta = try XCTUnwrap(payload.meta as? PayloadMetaTonMain)
        XCTAssertEqual(meta.to.display, Self.omnistonRouter)
        XCTAssertEqual(meta.value.description, "1280000000")
        XCTAssertEqual(meta.body?.hasPrefix("te6cc"), true)
        XCTAssertNil(meta.token)
        XCTAssertEqual(prepared.routeId, "036bb244-764a-4cb0-b5b8-8e1362551794")
        XCTAssertNil(prepared.providerRouteId)
        XCTAssertEqual(prepared.aggregator, "omniston")
        XCTAssertEqual(prepared.executionId, "2d4c0861-02f2-4477-bb15-8747dc399838")
        XCTAssertNil(prepared.depositAddress)
        XCTAssertEqual(prepared.receiveAmount, 1_183_456)
        XCTAssertNil(prepared.minimumReceiveAmount)
        XCTAssertEqual(prepared.expiresAt, ISO8601DateFormatter().date(from: "2026-11-02T15:50:28Z"))
    }

    /// The approve the backend sends first keeps its gas; the router call behind it quotes a price
    /// and no limit, which prices nothing: chain-kit leaves it unpriced rather than refusing it.
    func test_anEVMTokenSwapIsItsApproveAheadOfTheRouterCall() async throws {
        let prepared = try await read("usdteth_eth")

        let payloads = prepared.operation.payloads
        XCTAssertEqual(payloads.map { $0.id }, ["62f4f101-9be6-4400-a671-eb6caa5f5332", "6626b85b-3990-4e43-8f54-6d7737fd8bf2"])
        XCTAssertEqual(payloads.map { $0.chain.caip2 }, Array(repeating: MultichainChain.eth.asChainKitChain.caip2, count: 2))
        let approve = try XCTUnwrap(payloads.first?.meta as? PayloadMetaEvmMain)
        XCTAssertEqual(approve.to.display.lowercased(), "0xdac17f958d2ee523a2206206994597c13d831ec7")
        XCTAssertEqual(approve.data?.hasPrefix("0x095ea7b3"), true)
        let approveFee = try XCTUnwrap(payloads.first?.fee as? FeeGas)
        XCTAssertEqual(approveFee.limit.description, "63617")
        XCTAssertEqual(approveFee.price.description, "301418031")
        XCTAssertEqual(approveFee.amount.description, "19175310878127")
        let swap = try XCTUnwrap(payloads.last?.meta as? PayloadMetaEvmMain)
        XCTAssertEqual(swap.to.display.lowercased(), Self.swapsXyzRouter)
        XCTAssertEqual(swap.value.description, "0")
        XCTAssertNil(payloads.last?.fee)
        XCTAssertEqual(prepared.receiveAmount, 8_673_111_496_476_925)
        XCTAssertEqual(prepared.minimumReceiveAmount, 8_586_380_381_512_155)
    }

    func test_aBitcoinSwapIsItsDeposit() async throws {
        let prepared = try await read("btc_eth")

        XCTAssertEqual(prepared.operation.payloads.count, 1)
        let payload = try XCTUnwrap(prepared.operation.payloads.first)
        XCTAssertEqual(payload.chain.caip2, MultichainChain.btc.asChainKitChain.caip2)
        XCTAssertNil(payload.fee)
        let meta = try XCTUnwrap(payload.meta as? PayloadMetaBitcoinMain)
        XCTAssertEqual(meta.to.display, "3FHycwXWPjdpMubBrsugoFdwLGiSNBR4WJ")
        XCTAssertEqual(meta.value.description, "100000")
        XCTAssertEqual(prepared.minimumReceiveAmount, 33_013_233_000_000_000)
    }

    /// Whatever order its keys arrive in, an operation reads as the same meta, which its review's id
    /// is made of.
    func test_anOperationReadsAsItsJSONWithSortedKeys() async throws {
        let prepared = try await read("btc_eth")

        XCTAssertEqual(
            prepared.operation.meta,
            #"{"id":"73da9a8c-5d26-4002-9298-d8d61349c301","payloads":[{"amount_editable":true,"chain_id":"btc/mainnet","#
                + #""id":"828936e0-0daa-414e-b057-76acd0f7be28","meta":{"to":"3FHycwXWPjdpMubBrsugoFdwLGiSNBR4WJ","value":"100000"},"#
                + #""type":"main","version":1}]}"#
        )
    }

    func test_aTRC20SwapIsTheTokensTransferCall() async throws {
        let prepared = try await read("usdttron_ton")

        XCTAssertEqual(prepared.operation.payloads.count, 1)
        let payload = try XCTUnwrap(prepared.operation.payloads.first)
        XCTAssertEqual(payload.chain.caip2, MultichainChain.tron.asChainKitChain.caip2)
        XCTAssertNil(payload.fee)
        let meta = try XCTUnwrap(payload.meta as? PayloadMetaTronMain)
        XCTAssertEqual(meta.to.display, "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t")
        XCTAssertEqual(meta.value.description, "0")
        XCTAssertEqual(meta.data?.hasPrefix("a9059cbb"), true)
    }

    func test_aTonJettonDepositKeepsItsToken() async throws {
        let jetton = "0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe"

        let prepared = try await read("ton_usdt", meta: {
            $0 = ["to": Self.omnistonRouter, "value": "1000000", "token": jetton]
        })

        let meta = try XCTUnwrap(prepared.operation.payloads.first?.meta as? PayloadMetaTonMain)
        XCTAssertEqual(meta.value.description, "1000000")
        XCTAssertEqual(try XCTUnwrap(meta.token), Address.Companion.shared.from(value: jetton, chain: MultichainChain.ton.asChainKitChain))
    }

    func test_aRoutePayingADepositAddressNamesIt() async throws {
        let deposit = "3FHycwXWPjdpMubBrsugoFdwLGiSNBR4WJ"

        let named = try await read("btc_eth", summary: { $0["deposit_address"] = deposit })
        let blank = try await read("btc_eth", summary: { $0["deposit_address"] = " " })

        XCTAssertEqual(named.depositAddress, deposit)
        XCTAssertNil(blank.depositAddress)
    }

    func test_anAmountTheSummaryDoesNotWriteAsDigitsIsNotRead() async throws {
        let prepared = try await read("usdteth_eth", summary: {
            $0["receive_amount"] = ""
            $0["minimum_receive_amount"] = "+8586380381512155"
        })

        XCTAssertNil(prepared.receiveAmount)
        XCTAssertNil(prepared.minimumReceiveAmount)
    }

    /// The status is read before the operation: a route still being validated is prepared again
    /// whatever its operation holds.
    func test_aRouteStillBeingValidatedMayPassOnAnotherPrepare() async throws {
        let prepared = try await prepare(
            "ton_usdt",
            root: { $0["validation_status"] = "pending" },
            operation: { $0["payloads"] = [Any]() }
        )

        XCTAssertEqual(refusal(of: prepared), .pending)
    }

    func test_aRouteItsValidationRejectedIsRefused() async throws {
        let prepared = try await prepare(
            "ton_usdt",
            root: { $0["validation_status"] = "rejected" },
            operation: { $0["payloads"] = [Any]() }
        )

        XCTAssertEqual(refusal(of: prepared), .rejected)
    }

    func test_anOperationChainKitCannotReadIsRefused() async throws {
        let prepared = try await prepare("ton_usdt", payload: { $0["chain_id"] = "nowhere/mainnet" })

        guard case .unreadable = refusal(of: prepared) else {
            return XCTFail("expected an unreadable operation, got \(String(describing: refusal(of: prepared)))")
        }
    }

    func test_anOperationWithNoPayloadsIsRefused() async throws {
        let prepared = try await prepare("ton_usdt", operation: { $0["payloads"] = [Any]() })

        guard case .unreadable = refusal(of: prepared) else {
            return XCTFail("expected an unreadable operation, got \(String(describing: refusal(of: prepared)))")
        }
    }

    func test_anAmountWrittenAsAJSONNumberIsRefused() async throws {
        let prepared = try await prepare("ton_usdt", meta: { $0["value"] = 1_280_000_000 })

        XCTAssertEqual(refusal(of: prepared), .unreadable("value is a JSON number"))
    }

    func test_aFeeWrittenAsAJSONNumberIsRefused() async throws {
        let fees: [String: [String: Any]] = [
            "limit": ["type": "gas", "asset_id": "eth/mainnet/coin", "data": ["limit": 63617, "price": "301418031"]],
            "price": ["type": "gas", "asset_id": "eth/mainnet/coin", "data": ["limit": "63617", "price": 301_418_031]],
            "max_fee_per_gas": [
                "type": "eip1559",
                "asset_id": "eth/mainnet/coin",
                "data": ["limit": "63617", "max_fee_per_gas": 301_418_031, "max_priority_fee_per_gas": "1000000"],
            ],
            "max_priority_fee_per_gas": [
                "type": "eip1559",
                "asset_id": "eth/mainnet/coin",
                "data": ["limit": "63617", "max_fee_per_gas": "301418031", "max_priority_fee_per_gas": 1_000_000],
            ],
            "amount": ["type": "value", "asset_id": "battery/mainnet", "data": ["amount": 45]],
        ]
        for (key, fee) in fees {
            let prepared = try await prepare("usdteth_eth", payload: { $0["fee"] = fee })

            XCTAssertEqual(refusal(of: prepared), .unreadable("\(key) is a JSON number"), key)
        }
    }

    // MARK: - The quoted route as prepared

    func test_aQuotedRouteReceivesWhatItsOperationStates() async throws {
        let route = try await quotedRoute("confirm_v3_quote_usdteth_eth")
        let prepared = try await read("usdteth_eth")

        let shown = route.prepared(as: prepared)

        XCTAssertEqual(shown.estimatedDestinationAmount, "8673111496476925")
        XCTAssertEqual(shown.minimumDestinationAmount, "8586380381512155")
        XCTAssertEqual(shown.providerRouteId, "0xf4a6c7d60c9852471d571261da4cc5c9da056120aaf8edec34371b6b09967d0c")
        XCTAssertNil(shown.valueDifferenceBps)
    }

    func test_whatTheBackendLeavesOutMovesWithWhatTheOperationReceives() async throws {
        let route = try await quotedRoute("confirm_v3_quote_usdttron_ton")
        let prepared = try await read("usdttron_ton", summary: {
            $0["receive_amount"] = "6096748200"
            $0["minimum_receive_amount"] = nil
        })

        let shown = route.prepared(as: prepared)

        XCTAssertEqual(shown.estimatedDestinationAmount, "6096748200")
        XCTAssertEqual(shown.minimumDestinationAmount, "6035780718")
        XCTAssertEqual(shown.valueDifferenceBps, -6338)
    }

    func test_theLeastARouteReceivesIsNeverAboveWhatItReceives() async throws {
        let route = try await quotedRoute("confirm_v3_quote_usdteth_eth")
        let prepared = try await read("usdteth_eth", summary: {
            $0["minimum_receive_amount"] = "9999999999999999"
        })

        XCTAssertEqual(route.prepared(as: prepared).minimumDestinationAmount, "8673111496476925")
    }

    /// Omniston's prepare names neither the provider's route nor the least the swap receives.
    func test_aRouteKeepsWhatItsOperationDoesNotName() async throws {
        let route = try await quotedRoute("confirm_v3_quote_ton_usdt")
        let prepared = try await read("ton_usdt")

        let shown = route.prepared(as: prepared)

        XCTAssertEqual(shown.providerRouteId, "ecb2e9d79c939c00629d8bbdd1a75fcea4214c93c870a93264b2472b89405b3c")
        XCTAssertEqual(shown.estimatedDestinationAmount, "1183456")
        XCTAssertEqual(shown.minimumDestinationAmount, "1171621")
        XCTAssertNil(shown.valueDifferenceBps)
    }

    func test_aRouteKeepsWhatItWasQuotedToReceiveWhereItsOperationDoesNotSay() async throws {
        let route = try await quotedRoute("confirm_v3_quote_usdteth_eth")
        let prepared = try await read("usdteth_eth", summary: { $0["receive_amount"] = nil })

        let shown = route.prepared(as: prepared)

        XCTAssertEqual(shown.estimatedDestinationAmount, "8678161447483770")
        XCTAssertEqual(shown.minimumDestinationAmount, "8586380381512155")
    }

    func test_aRouteQuotedToReceiveNothingIsNotScaledByIt() async throws {
        var route = try await quotedRoute("confirm_v3_quote_ton_usdt")
        route.estimatedDestinationAmount = "0"
        route.valueDifferenceBps = -500
        let prepared = try await read("ton_usdt")

        let shown = route.prepared(as: prepared)

        XCTAssertEqual(shown.estimatedDestinationAmount, "1183456")
        XCTAssertEqual(shown.minimumDestinationAmount, "1171621")
        XCTAssertEqual(shown.valueDifferenceBps, -500)
    }
}

private extension MultichainSwapPreparedOperationTests {
    func quotedRoute(_ name: String) async throws -> MultichainSwapRoute {
        let quote = try await SwapBackend(answering: SwapFixture.data(name)).api
            .createCrossSwapQuoteV3(request: Self.request, walletId: Self.walletId)
        return try XCTUnwrap(quote.routes.first)
    }

    /// The recorded prepare of `swap`, edited as `SwapFixture.prepare` edits it.
    func prepare(
        _ swap: String,
        root: (inout [String: Any]) -> Void = { _ in },
        summary: (inout [String: Any]) -> Void = { _ in },
        operation: (inout [String: Any]) -> Void = { _ in },
        payload: (inout [String: Any]) -> Void = { _ in },
        meta: (inout [String: Any]) -> Void = { _ in }
    ) async throws -> SwapAPI.Components.Schemas.CrossSwapPrepareV3 {
        let recorded = try SwapFixture.prepare(swap, root: root, summary: summary, operation: operation, payload: payload, meta: meta)
        return try await SwapBackend(answering: recorded).api.prepareCrossSwapRouteV3(routeId: "route", walletId: Self.walletId)
    }

    func read(
        _ swap: String,
        summary: (inout [String: Any]) -> Void = { _ in },
        meta: (inout [String: Any]) -> Void = { _ in }
    ) async throws -> MultichainSwapPreparedOperation {
        try await MultichainSwapPreparedOperation(prepare(swap, summary: summary, meta: meta))
    }

    func refusal(of prepared: SwapAPI.Components.Schemas.CrossSwapPrepareV3) -> MultichainSwapPreparedOperationError? {
        do {
            _ = try MultichainSwapPreparedOperation(prepared)
            return nil
        } catch {
            return error
        }
    }
}
