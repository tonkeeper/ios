import ChainKit
@testable import KeeperCore
import XCTest

/// Live smoke for the Lighter stack against the staging deployment — exercises
/// the real Darwin transport and the Kotlin/Native bridge, which unit tests and
/// compilation cannot. Network-bound, so it is skipped unless the test runner
/// environment sets `LIGHTER_SMOKE=1` (pass `TEST_RUNNER_LIGHTER_SMOKE=1` to
/// `xcodebuild test`).
final class LighterStagingSmokeTests: XCTestCase {
    func testMarketsAndFreshWalletActivationAgainstStaging() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["LIGHTER_SMOKE"] == "1",
            "live staging smoke; run with TEST_RUNNER_LIGHTER_SMOKE=1"
        )

        // Fresh BIP39 mnemonic: a real activation flow whose outcome is
        // deterministic — the derived L1 address has no Lighter account.
        let phrase = ChainKit.Mnemonic.companion
            .create(size: ChainKit.EntropySize.b128)
            .toWordsUnsafeList()
            .joined(separator: " ")
        let cryptoWallet = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: phrase)
        let keyStore = InMemoryLighterKeyStore()
        let kit = LighterKit_iosKt.makeLighterKit(
            environment: LighterEnvironment.Staging.shared,
            keyStore: keyStore,
            operationStore: InMemoryLighterOperationStore(),
            httpClient: LighterHttpClient_iosKt.createLighterHttpClient()
        )
        let probe = makeStagingProbe(keyStore: keyStore)

        let markets: [PerpsMarket] = try await bridgeKotlin { kit.reads.markets(completionHandler: $0) }
        XCTAssertFalse(markets.isEmpty, "staging returned no perp markets")

        // Passcode-free probe path: a fresh L1 address has no account.
        let ethAddress = cryptoWallet.getAddress(chain: ChainEthereumMainnet.shared).display
        let probed: KotlinLong? = try await bridgeKotlinOptional {
            probe.accountIndex(l1Address: ethAddress, completionHandler: $0)
        }
        XCTAssertNil(probed, "fresh address must have no Lighter account")

        let state: ActivationState = try await bridgeKotlin { kit.activate(wallet: cryptoWallet, completionHandler: $0) }
        guard let noAccount = state as? ActivationStateNoAccount else {
            XCTFail("fresh wallet should resolve to NoAccount, got: \(state)")
            return
        }
        XCTAssertTrue(noAccount.ethAddress.hasPrefix("0x"), noAccount.ethAddress)
        XCTAssertEqual(noAccount.ethAddress.count, 42, noAccount.ethAddress)
    }

    /// One-shot bootstrap of a staging test account, exercising the only path
    /// the regular smoke can't: the live `ChangePubKey` registration. Uses a
    /// caller-supplied disposable wallet, asks the (undocumented) staging faucet
    /// to fund it, waits for the account to materialize, then runs the full
    /// activation and reads the funded portfolio. The mnemonic is never logged.
    /// Run with `TEST_RUNNER_LIGHTER_BOOTSTRAP=1` and
    /// `TEST_RUNNER_LIGHTER_BOOTSTRAP_MNEMONIC=<disposable mnemonic>`.
    func testBootstrapStagingTestAccount() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["LIGHTER_BOOTSTRAP"] == "1",
            "one-shot staging account bootstrap; run with TEST_RUNNER_LIGHTER_BOOTSTRAP=1"
        )

        // Supplying the disposable mnemonic makes partial bootstrap runs
        // resumable without ever leaking the recovery secret into CI logs.
        let phrase = try XCTUnwrap(
            ProcessInfo.processInfo.environment["LIGHTER_BOOTSTRAP_MNEMONIC"],
            "set TEST_RUNNER_LIGHTER_BOOTSTRAP_MNEMONIC to a disposable staging-only mnemonic"
        )
        let cryptoWallet = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: phrase)
        let keyStore = InMemoryLighterKeyStore()
        let kit = LighterKit_iosKt.makeLighterKit(
            environment: LighterEnvironment.Staging.shared,
            keyStore: keyStore,
            operationStore: InMemoryLighterOperationStore(),
            httpClient: LighterHttpClient_iosKt.createLighterHttpClient()
        )
        let probe = makeStagingProbe(keyStore: keyStore)
        let ethAddress = cryptoWallet.getAddress(chain: ChainEthereumMainnet.shared).display
        print("BOOTSTRAP eth: \(ethAddress)")

        // The staging faucet is GET-only (POST answers 404).
        let faucetURL = try XCTUnwrap(URL(string: "https://staging.zklighter.elliot.ai/api/v1/faucet?l1_address=\(ethAddress)"))
        let (faucetBody, faucetResponse) = try await URLSession.shared.data(from: faucetURL)
        print("BOOTSTRAP faucet: HTTP \((faucetResponse as? HTTPURLResponse)?.statusCode ?? 0) \(String(data: faucetBody, encoding: .utf8) ?? "")")

        var accountIndex: Int64?
        for _ in 0 ..< 36 {
            if let index: KotlinLong = try? await bridgeKotlinOptional({
                probe.accountIndex(l1Address: ethAddress, completionHandler: $0)
            }) {
                accountIndex = index.int64Value
                break
            }
            try await Task.sleep(nanoseconds: 5_000_000_000)
        }
        let index = try XCTUnwrap(accountIndex, "staging faucet did not create an account within 3 minutes")
        print("BOOTSTRAP accountIndex: \(index)")

        let state: ActivationState = try await bridgeKotlin { kit.activate(wallet: cryptoWallet, completionHandler: $0) }
        let active = try XCTUnwrap(state as? ActivationStateActive, "expected Active, got \(state)")
        print("BOOTSTRAP active: account \(active.accountIndex), apiKeyIndex \(active.apiKeyIndex)")

        print("BOOTSTRAP l2 api private key: stored in ephemeral smoke key store")

        let portfolio: PerpsPortfolio? = try await bridgeKotlinOptional {
            kit.reads.portfolio(accountIndex: index, completionHandler: $0)
        }
        let funded = try XCTUnwrap(portfolio, "portfolio missing for freshly funded account")
        print("BOOTSTRAP portfolio: collateral=\(funded.collateral) available=\(funded.availableBalance) positions=\(funded.positions.count)")
    }

    /// Live Market Long + Short on the funded staging account (TK-1572 open,
    /// TK-1577 close, TK-1578 resize). For each side it runs the real
    /// `setLeverage(isolated)` + `openMarket` sequence, submits, compares the
    /// review's `estimatedLiquidationPrice` against the post-open position,
    /// resizes through the size-change contract's calls (`addToPosition` then
    /// `reducePosition` with the same margin→portion conversion
    /// `prepareSizeChange` performs, reviews mapped by
    /// `PerpsSizeChangeReviewMapper`, size-delta confirms like
    /// `reconcileSizeChange`), then closes through the Cash Out contract's calls
    /// — `close(CloseIntent(portion: 1.0))`, asserting the review carries the
    /// close estimates `PerpsCloseReviewMapper` consumes, and confirming the
    /// position reads absent (`reconcileClose`'s predicate). Double-gated (real
    /// money on staging): needs `LIGHTER_TRADE_SMOKE=1` AND a funded
    /// `LIGHTER_TRADE_MNEMONIC`.
    func testMarketLongShortTradeSmoke() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["LIGHTER_TRADE_SMOKE"] == "1",
            "live staging trade smoke (submits real orders); run with TEST_RUNNER_LIGHTER_TRADE_SMOKE=1"
        )
        let phrase = try XCTUnwrap(
            ProcessInfo.processInfo.environment["LIGHTER_TRADE_MNEMONIC"],
            "set LIGHTER_TRADE_MNEMONIC to the funded staging account mnemonic"
        )

        let cryptoWallet = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: phrase)
        let keyStore = InMemoryLighterKeyStore()
        let kit = LighterKit_iosKt.makeLighterKit(
            environment: LighterEnvironment.Staging.shared,
            keyStore: keyStore,
            operationStore: InMemoryLighterOperationStore(),
            httpClient: LighterHttpClient_iosKt.createLighterHttpClient()
        )
        let state: ActivationState = try await bridgeKotlin { kit.activate(wallet: cryptoWallet, completionHandler: $0) }
        guard state is ActivationStateActive else {
            XCTFail("funded wallet should activate, got \(state)")
            return
        }
        let resolvedSession: LighterSession? = try await bridgeKotlinOptional { kit.session(completionHandler: $0) }
        let session = try XCTUnwrap(resolvedSession, "funded wallet should yield a signing session")
        let trading = session.trading

        let markets: [PerpsMarket] = try await bridgeKotlin { kit.reads.markets(completionHandler: $0) }
        let market = try XCTUnwrap(markets.first { $0.symbol == "BTC" } ?? markets.first, "no markets on staging")
        let marketId = market.marketId

        // An aborted earlier run can leave a residual position that would poison
        // this run's side assertions; flatten the market before starting.
        let residue: LighterOpenPosition? = try await bridgeKotlinOptional {
            trading.currentPosition(marketId: marketId, completionHandler: $0)
        }
        if let residue, abs(residue.size) > 0 {
            let flatten = CloseIntent(
                marketId: marketId,
                portion: 1.0,
                maxSlippage: 0.02,
                clientOrderIndex: 0,
                markPrice: nil
            )
            let _: LighterOperation = try await bridgeKotlin {
                trading.executeClose(operationId: UUID().uuidString, intent: flatten, completionHandler: $0)
            }
            var flat = false
            for _ in 0 ..< 15 {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                let remaining: LighterOpenPosition? = try? await bridgeKotlinOptional {
                    trading.currentPosition(marketId: marketId, completionHandler: $0)
                }
                if remaining == nil || abs(remaining?.size ?? 0) == 0 {
                    flat = true
                    break
                }
            }
            guard flat else {
                XCTFail("residual position on market \(marketId) did not flatten")
                return
            }
        }

        for side in [LighterTradeSide.long_, LighterTradeSide.short_] {
            try await runTradeSmoke(trading: trading, session: session, marketId: marketId, side: side)
        }
    }

    private func runTradeSmoke(
        trading: LighterTradingClient,
        session: LighterSession,
        marketId: Int64,
        side: LighterTradeSide
    ) async throws {
        let leverage = 3.0
        let label = side === LighterTradeSide.short_ ? "SHORT" : "LONG"

        let resolvedMeta: LighterMarketMeta? = try await bridgeKotlinOptional {
            trading.marketMeta(marketId: marketId, completionHandler: $0)
        }
        let meta = try XCTUnwrap(resolvedMeta, "market meta unavailable on staging")
        var mark = meta.lastTradePrice
        /// Production feeds every step a live mark from the stream; a leg-start
        /// snapshot goes stale across the polls in between, and the venue then
        /// rejects margin sized off the old price ("not enough collateral").
        func refreshMark() async {
            let fresh: LighterMarketMeta? = try? await bridgeKotlinOptional {
                trading.marketMeta(marketId: marketId, completionHandler: $0)
            }
            if let price = fresh?.lastTradePrice, price > 0 { mark = price }
        }
        // Venue minimums drift with staging prices; size every leg off the live
        // min-base notional so grid flooring keeps each order venue-valid.
        let minBaseNotionalUsd = Double(meta.minBaseAmount) / pow(10.0, Double(meta.sizeDecimals)) * mark
        let marginUsd = max(2.0, minBaseNotionalUsd * 1.25 / leverage)

        let intent = OpenMarketIntent(
            marketId: marketId,
            side: side,
            amount: LighterAmountQuote(usd: marginUsd * leverage),
            maxSlippage: 0.02,
            tpSl: nil,
            clientOrderIndex: 0,
            markPrice: KotlinDouble(value: mark),
            marginUsd: KotlinDouble(value: marginUsd)
        )
        let review: LighterOrderReview = try await bridgeKotlin {
            trading.previewOpenMarket(intent: intent, completionHandler: $0)
        }
        let previewLiquidation = review.estimatedLiquidationPrice?.doubleValue
        let _: LighterOperation = try await bridgeKotlin {
            trading.executeOpenMarket(
                operationId: UUID().uuidString,
                intent: intent,
                leverage: KotlinDouble(value: leverage),
                marginMode: LighterConstants.shared.IsolatedMargin,
                completionHandler: $0
            )
        }

        // Poll for the fill instead of a fixed sleep, then compare preview vs real.
        let polledPosition = await pollPosition(trading: trading, marketId: marketId) { _ in true }
        let position = try XCTUnwrap(polledPosition, "\(label) market open did not produce a position within 5s")
        if let previewLiquidation, position.liquidationPrice > 0 {
            let tolerance = max(1, position.liquidationPrice * 0.05)
            print("TRADE \(label): preview liq=\(previewLiquidation) actual=\(position.liquidationPrice)")
            XCTAssertEqual(
                previewLiquidation,
                position.liquidationPrice,
                accuracy: tolerance,
                "\(label) preview liquidation should track the post-open position within 5%"
            )
        } else {
            print("TRADE \(label): no liquidation preview to compare")
        }

        await refreshMark()
        let addMargin = marginUsd
        let positionLeverage = position.leverage?.doubleValue ?? leverage
        let sizeBeforeAdd = abs(position.size)
        let addOrderReview: LighterOrderReview = try await bridgeKotlin {
            trading.previewAddToPosition(
                marketId: marketId,
                amount: LighterAmountQuote(usd: addMargin * positionLeverage),
                maxSlippage: 0.02,
                markPrice: KotlinDouble(value: mark),
                marginUsd: KotlinDouble(value: addMargin),
                completionHandler: $0
            )
        }
        let addReview = PerpsSizeChangeReviewMapper.map(
            direction: .add,
            review: addOrderReview,
            position: position,
            marginDeltaUsd: addMargin
        )
        XCTAssertEqual(addReview.side, side === LighterTradeSide.short_ ? .short : .long)
        XCTAssertGreaterThan(addReview.baseSize.new, addReview.baseSize.old, "\(label) add review must grow the base size")
        print("TRADE \(label) add: size \(addReview.baseSize.old) → \(addReview.baseSize.new) entry \(addReview.entryPrice.old) → \(addReview.entryPrice.new)")
        let _: LighterOperation = try await bridgeKotlin {
            trading.executeAddToPosition(
                operationId: UUID().uuidString,
                marketId: marketId,
                amount: LighterAmountQuote(usd: addMargin * positionLeverage),
                maxSlippage: 0.02,
                markPrice: KotlinDouble(value: mark),
                marginUsd: KotlinDouble(value: addMargin),
                tpSl: nil,
                orderIndexesToCancel: [],
                completionHandler: $0
            )
        }

        let polledGrown = await pollPosition(trading: trading, marketId: marketId) { abs($0.size) > sizeBeforeAdd }
        let grownPosition = try XCTUnwrap(polledGrown, "\(label) add did not grow the position within 5s")

        await refreshMark()
        let grownMargin = grownPosition.allocatedMargin
        let reduceMargin = min(addMargin, grownMargin * 0.5)
        let sizeBeforeReduce = abs(grownPosition.size)
        let reduceIntent = CloseIntent(
            marketId: marketId,
            portion: reduceMargin / grownMargin,
            maxSlippage: 0.02,
            clientOrderIndex: 0,
            markPrice: KotlinDouble(value: mark)
        )
        let reduceOrderReview: LighterOrderReview = try await bridgeKotlin {
            trading.previewClose(intent: reduceIntent, completionHandler: $0)
        }
        let reduceReview = PerpsSizeChangeReviewMapper.map(
            direction: .reduce,
            review: reduceOrderReview,
            position: grownPosition,
            marginDeltaUsd: reduceMargin
        )
        XCTAssertFalse(reduceReview.entryPrice.isChanged, "\(label) reduce must not move the entry price")
        XCTAssertLessThan(reduceReview.baseSize.new, reduceReview.baseSize.old)
        print("TRADE \(label) reduce: size \(reduceReview.baseSize.old) → \(reduceReview.baseSize.new)")
        let _: LighterOperation = try await bridgeKotlin {
            trading.executeReducePosition(
                operationId: UUID().uuidString,
                marketId: marketId,
                portion: reduceMargin / grownMargin,
                maxSlippage: 0.02,
                markPrice: KotlinDouble(value: mark),
                tpSl: nil,
                orderIndexesToCancel: [],
                completionHandler: $0
            )
        }

        let polledReduced = await pollPosition(trading: trading, marketId: marketId) { abs($0.size) < sizeBeforeReduce }
        let reducedPosition = try XCTUnwrap(polledReduced, "\(label) reduce did not shrink the position within 5s")

        await refreshMark()
        let marginDelta = 1.0
        let marginBeforeAdd = reducedPosition.allocatedMargin
        let addMarginSdkReview: LighterMarginReview = try await bridgeKotlin {
            trading.previewAddMargin(marketId: marketId, usdc: marginDelta, markPrice: KotlinDouble(value: mark), completionHandler: $0)
        }
        let addMarginReview = PerpsMarginChangeReviewMapper.map(direction: .add, review: addMarginSdkReview, position: reducedPosition)
        XCTAssertEqual(addMarginReview.side, side === LighterTradeSide.short_ ? .short : .long)
        XCTAssertEqual(
            addMarginReview.allocatedMargin.new - addMarginReview.allocatedMargin.old,
            marginDelta,
            accuracy: 0.01,
            "\(label) addMargin review must raise the allocated margin by the amount"
        )
        if let liquidation = addMarginReview.liquidationPrice, liquidation.isChanged {
            // More collateral moves liquidation away from the mark.
            if side === LighterTradeSide.short_ {
                XCTAssertGreaterThan(liquidation.new, liquidation.old, "\(label) addMargin must push liquidation up, away from the mark")
            } else {
                XCTAssertLessThan(liquidation.new, liquidation.old, "\(label) addMargin must push liquidation down, away from the mark")
            }
        }
        print("TRADE \(label) addMargin: margin \(addMarginReview.allocatedMargin.old) → \(addMarginReview.allocatedMargin.new) liq \(String(describing: addMarginReview.liquidationPrice))")
        let _: LighterOperation = try await bridgeKotlin {
            trading.executeMarginUpdate(
                operationId: UUID().uuidString,
                marketId: marketId,
                usdc: marginDelta,
                direction: LighterMarginDirection.add,
                markPrice: KotlinDouble(value: mark),
                completionHandler: $0
            )
        }

        let marginTolerance = max(0.000001, marginDelta * 1e-9)
        let polledMarginAdded = await pollPosition(trading: trading, marketId: marketId) {
            $0.allocatedMargin - marginBeforeAdd >= marginDelta - marginTolerance
        }
        let marginAddedPosition = try XCTUnwrap(polledMarginAdded, "\(label) addMargin did not raise the allocated margin within 5s")

        let marginBeforeReduce = marginAddedPosition.allocatedMargin
        let reduceMarginSdkReview: LighterMarginReview = try await bridgeKotlin {
            trading.previewReduceMargin(marketId: marketId, usdc: marginDelta, markPrice: KotlinDouble(value: mark), completionHandler: $0)
        }
        let reduceMarginReview = PerpsMarginChangeReviewMapper.map(direction: .reduce, review: reduceMarginSdkReview, position: marginAddedPosition)
        XCTAssertEqual(
            reduceMarginReview.allocatedMargin.old - reduceMarginReview.allocatedMargin.new,
            marginDelta,
            accuracy: 0.01,
            "\(label) reduceMargin review must lower the allocated margin by the amount"
        )
        if let liquidation = reduceMarginReview.liquidationPrice, liquidation.isChanged {
            // Less collateral moves liquidation toward the mark.
            if side === LighterTradeSide.short_ {
                XCTAssertLessThan(liquidation.new, liquidation.old, "\(label) reduceMargin must pull liquidation down, toward the mark")
            } else {
                XCTAssertGreaterThan(liquidation.new, liquidation.old, "\(label) reduceMargin must pull liquidation up, toward the mark")
            }
        }
        print("TRADE \(label) reduceMargin: margin \(reduceMarginReview.allocatedMargin.old) → \(reduceMarginReview.allocatedMargin.new) liq \(String(describing: reduceMarginReview.liquidationPrice))")
        let _: LighterOperation = try await bridgeKotlin {
            trading.executeMarginUpdate(
                operationId: UUID().uuidString,
                marketId: marketId,
                usdc: marginDelta,
                direction: LighterMarginDirection.remove,
                markPrice: KotlinDouble(value: mark),
                completionHandler: $0
            )
        }

        let polledMarginReduced = await pollPosition(trading: trading, marketId: marketId) {
            marginBeforeReduce - $0.allocatedMargin >= marginDelta - marginTolerance
        }
        let marginSettledPosition = try XCTUnwrap(polledMarginReduced, "\(label) reduceMargin did not lower the allocated margin within 5s")

        let entry = marginSettledPosition.avgEntryPrice
        let isShort = side === LighterTradeSide.short_
        let tpSl1 = LighterTpSl(
            takeProfit: LighterAutoClose(
                triggerPrice: entry * (isShort ? 0.95 : 1.05),
                maxSlippage: 0.02
            ),
            stopLoss: LighterAutoClose(
                triggerPrice: entry * (isShort ? 1.02 : 0.98),
                maxSlippage: 0.02
            )
        )
        let setSdkReview: LighterTpSlReview = try await bridgeKotlin {
            trading.previewTpSl(marketId: marketId, tpSl: tpSl1, completionHandler: $0)
        }
        let restingBefore = try await triggerOrders(session: session, marketId: marketId)
        let setReview = PerpsAutoCloseChangeReviewMapper.map(review: setSdkReview, position: marginSettledPosition)
        let expectedTarget = try XCTUnwrap(setReview.new, "\(label) set review must carry the target legs")
        XCTAssertNotNil(expectedTarget.takeProfit)
        XCTAssertNotNil(expectedTarget.stopLoss)
        let _: LighterOperation = try await bridgeKotlin {
            trading.executeTpSlChange(
                operationId: UUID().uuidString,
                marketId: marketId,
                tpSl: tpSl1,
                orderIndexesToCancel: restingBefore.map { KotlinLong(value: $0.orderIndex) },
                completionHandler: $0
            )
        }

        let setPending = PerpsPendingAutoCloseChange(target: expectedTarget, restingOrderIndexes: restingBefore.map(\.orderIndex))
        let legsAfterSet = try await pollTriggerOrders(session: session, marketId: marketId) {
            PerpsAutoCloseChangePlanner.isConfirmed(pending: setPending, orders: $0)
        }
        let restingPair = try XCTUnwrap(legsAfterSet, "\(label) setTpSl did not surface both legs within 5s")
        print("TRADE \(label) setTpSl: legs \(restingPair.map { "\($0.kind) @ \($0.triggerPrice) idx=\($0.orderIndex)" })")

        let tpSl2 = LighterTpSl(
            takeProfit: LighterAutoClose(
                triggerPrice: entry * (isShort ? 0.93 : 1.07),
                maxSlippage: 0.02
            ),
            stopLoss: LighterAutoClose(
                triggerPrice: entry * (isShort ? 1.03 : 0.97),
                maxSlippage: 0.02
            )
        )
        let replaceSdkReview: LighterTpSlReview = try await bridgeKotlin {
            trading.previewTpSl(marketId: marketId, tpSl: tpSl2, completionHandler: $0)
        }
        let replaceReview = PerpsAutoCloseChangeReviewMapper.map(review: replaceSdkReview, position: marginSettledPosition)
        let replaceTarget = try XCTUnwrap(replaceReview.new)
        let _: LighterOperation = try await bridgeKotlin {
            trading.executeTpSlChange(
                operationId: UUID().uuidString,
                marketId: marketId,
                tpSl: tpSl2,
                orderIndexesToCancel: restingPair.map { KotlinLong(value: $0.orderIndex) },
                completionHandler: $0
            )
        }

        let replacePending = PerpsPendingAutoCloseChange(target: replaceTarget, restingOrderIndexes: restingPair.map(\.orderIndex))
        let legsAfterReplace = try await pollTriggerOrders(session: session, marketId: marketId) {
            PerpsAutoCloseChangePlanner.isConfirmed(pending: replacePending, orders: $0)
        }
        let replacedPair = try XCTUnwrap(
            legsAfterReplace,
            "\(label) TP/SL replacement did not settle on exactly the new pair"
        )
        print("TRADE \(label) replace: legs \(replacedPair.map { "\($0.kind) @ \($0.triggerPrice) idx=\($0.orderIndex)" })")

        let uniqueIndexes = Array(Set(replacedPair.map { $0.orderIndex })).sorted()
        print("TRADE \(label) clear: \(uniqueIndexes.count) unique order index(es) for the pair")
        let _: LighterOperation = try await bridgeKotlin {
            trading.executeTpSlChange(
                operationId: UUID().uuidString,
                marketId: marketId,
                tpSl: nil,
                orderIndexesToCancel: uniqueIndexes.map { KotlinLong(value: $0) },
                completionHandler: $0
            )
        }
        let clearPending = PerpsPendingAutoCloseChange(target: nil, restingOrderIndexes: uniqueIndexes)
        let afterClear = try await pollTriggerOrders(session: session, marketId: marketId) {
            PerpsAutoCloseChangePlanner.isConfirmed(pending: clearPending, orders: $0)
        }
        XCTAssertNotNil(afterClear, "\(label) TP/SL clear did not settle within 5s")

        let _: LighterOperation = try await bridgeKotlin {
            trading.executeTpSlChange(
                operationId: UUID().uuidString,
                marketId: marketId,
                tpSl: tpSl1,
                orderIndexesToCancel: [],
                completionHandler: $0
            )
        }
        let legsBeforeClose = try await pollTriggerOrders(session: session, marketId: marketId) { !$0.isEmpty }
        XCTAssertNotNil(legsBeforeClose, "\(label) re-set before close did not surface legs within 5s")

        let closeIntent = CloseIntent(
            marketId: marketId,
            portion: 1.0,
            maxSlippage: 0.02,
            clientOrderIndex: 0,
            markPrice: nil
        )
        let closeOrderReview: LighterOrderReview = try await bridgeKotlin {
            trading.previewClose(intent: closeIntent, completionHandler: $0)
        }
        let closeReview = PerpsCloseReviewMapper.map(review: closeOrderReview, position: marginSettledPosition)
        print("TRADE \(label) close: pnl=\(String(describing: closeReview.estimatedPnlUsd)) receive=\(String(describing: closeReview.estimatedReceiveUsd)) fee=\(String(describing: closeReview.estimatedFeeUsd))")
        XCTAssertEqual(
            closeReview.side,
            side === LighterTradeSide.short_ ? .short : .long,
            "\(label) close review must report the position's side"
        )
        XCTAssertNotNil(closeReview.estimatedReceiveUsd, "\(label) staging close review should estimate receive")
        let _: LighterOperation = try await bridgeKotlin {
            trading.executeClose(operationId: UUID().uuidString, intent: closeIntent, completionHandler: $0)
        }

        var closed = false
        for _ in 0 ..< 5 {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let remaining: LighterOpenPosition? = try await bridgeKotlinOptional {
                trading.currentPosition(marketId: marketId, completionHandler: $0)
            }
            if remaining == nil || abs(remaining?.size ?? 0) == 0 {
                closed = true
                break
            }
        }
        XCTAssertTrue(closed, "\(label) position should read absent after the full close")

        let legsAfterClose = (try? await triggerOrders(session: session, marketId: marketId)) ?? []
        print("TRADE \(label) legs after full close: \(legsAfterClose.isEmpty ? "gone (venue cancels on close)" : "\(legsAfterClose.count) still resting — \(legsAfterClose.map { "\($0.kind) @ \($0.triggerPrice)" })")")
        if !legsAfterClose.isEmpty {
            let _: LighterOperation? = try? await bridgeKotlin {
                trading.executeTpSlChange(
                    operationId: UUID().uuidString,
                    marketId: marketId,
                    tpSl: nil,
                    orderIndexesToCancel: legsAfterClose.map { KotlinLong(value: $0.orderIndex) },
                    completionHandler: $0
                )
            }
        }
    }

    private func triggerOrders(session: LighterSession, marketId: Int64) async throws -> [PerpsTriggerOrderSummary] {
        let orders: [PerpsOrder] = try await bridgeKotlinOptional {
            session.reads.activeOrders(accountIndex: session.accountIndex, marketId: KotlinLong(value: marketId), completionHandler: $0)
        } ?? []
        return orders.compactMap(PerpsTriggerOrderSummary.init(order:))
    }

    private func pollTriggerOrders(
        session: LighterSession,
        marketId: Int64,
        until predicate: ([PerpsTriggerOrderSummary]) -> Bool
    ) async throws -> [PerpsTriggerOrderSummary]? {
        for _ in 0 ..< 5 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if let orders = try? await triggerOrders(session: session, marketId: marketId), predicate(orders) {
                return orders
            }
        }
        return nil
    }

    /// Polls the live position until the predicate holds; transient read errors
    /// count as a miss, not a failure.
    private func pollPosition(
        trading: LighterTradingClient,
        marketId: Int64,
        until predicate: (LighterOpenPosition) -> Bool
    ) async -> LighterOpenPosition? {
        for _ in 0 ..< 5 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            let position: LighterOpenPosition? = try? await bridgeKotlinOptional {
                trading.currentPosition(marketId: marketId, completionHandler: $0)
            }
            if let position, predicate(position) { return position }
        }
        return nil
    }
}

private func makeLighterClient() -> LighterClient {
    LighterClient(
        crypto: LighterCryptoBridge(crypto: CoreLighterCrypto()),
        nowMillis: { KotlinLong(value: Int64(Date().timeIntervalSince1970 * 1000)) }
    )
}

private func makeStagingProbe(keyStore: SecureKeyStore) -> LighterPerps {
    LighterPerps(
        environment: LighterEnvironment.Staging.shared,
        keyStore: keyStore,
        httpClient: LighterHttpClient_iosKt.createLighterHttpClient(),
        apiKeyIndex: LighterAuth.shared.DEFAULT_API_KEY_INDEX,
        lighter: makeLighterClient(),
        operationStore: InMemoryLighterOperationStore()
    )
}

private final class InMemoryLighterKeyStore: NSObject, SecureKeyStore {
    private var l2PrivateKey: KotlinByteArray?
    private var account: StoredLighterAccount?

    func loadL2PrivateKey(completionHandler: @escaping (KotlinByteArray?, Error?) -> Void) {
        completionHandler(l2PrivateKey, nil)
    }

    func saveL2PrivateKey(key: KotlinByteArray, completionHandler: @escaping (Error?) -> Void) {
        l2PrivateKey = key
        completionHandler(nil)
    }

    func loadAccount(completionHandler: @escaping (StoredLighterAccount?, Error?) -> Void) {
        completionHandler(account, nil)
    }

    func saveAccount(account: StoredLighterAccount, completionHandler: @escaping (Error?) -> Void) {
        self.account = account
        completionHandler(nil)
    }

    func clear(completionHandler: @escaping (Error?) -> Void) {
        l2PrivateKey = nil
        account = nil
        completionHandler(nil)
    }
}
