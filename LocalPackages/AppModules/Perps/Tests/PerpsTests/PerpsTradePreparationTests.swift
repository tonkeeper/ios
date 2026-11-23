@testable import Perps
import PerpsModels
import TKLocalize
import TKTestSupport
import XCTest

private let changed = TestSignal()

@MainActor
final class PerpsTradePreparationTests: XCTestCase {
    func testACashOutIsPreparedOnceUntilItsConfirmCloses() async {
        let (preparation, _) = makePreparation(StubTradingService(prepareClose: .success(closeAction())))
        var prepared = 0

        preparation.prepareClose(marketId: 1, isOnScreen: { true }) {
            if case .prepared = $0 { prepared += 1 }
            changed.send()
        }
        preparation.prepareClose(marketId: 1, isOnScreen: { true }) { _ in XCTFail("a second cash out while one runs") }
        await waitUntil { prepared == 1 }
        preparation.prepareClose(marketId: 1, isOnScreen: { true }) { _ in XCTFail("a second cash out while one is confirmed") }

        XCTAssertEqual(prepared, 1)
        XCTAssertTrue(preparation.cancelClose())
        XCTAssertFalse(preparation.cancelClose())
        preparation.prepareClose(marketId: 1, isOnScreen: { true }) {
            if case .prepared = $0 { prepared += 1 }
            changed.send()
        }
        await waitUntil { prepared == 2 }
        XCTAssertEqual(prepared, 2)
    }

    func testCloseSubmitsTheLastReviewDisplayedByTheConfirmScreen() async {
        let refreshed = PerpsCloseReview(
            symbol: "BTC", side: .long, leverage: 10, marginUsd: 20, notionalUsd: 200, baseSize: 2,
            estimatedFeeUsd: 0.1, feeRatePercent: 0.095, estimatedPnlUsd: 1, estimatedReceiveUsd: 20.9, worstPrice: 99
        )
        let submitted = expectation(description: "submitted with refreshed review")
        let service = StubTradingService(
            prepareClose: .success(closeAction()), previewClose: .success(refreshed),
            onCloseSubmit: { prepared in
                XCTAssertEqual(prepared.operationId, "op")
                XCTAssertEqual(prepared.review, refreshed)
                submitted.fulfill()
            }
        )
        let (preparation, _) = makePreparation(service)
        var ready = false
        preparation.prepareClose(marketId: 1, isOnScreen: { true }) {
            if case .prepared = $0 { ready = true }
            changed.send()
        }
        await waitUntil { ready }

        let review = await preparation.closeReview()
        XCTAssertEqual(review, refreshed)
        XCTAssertTrue(preparation.submitClose(onSlippage: {}))
        await fulfillment(of: [submitted], timeout: 2)
    }

    func testMarginChangeSubmitsTheLastReviewDisplayedByTheConfirmScreen() async {
        func review(margin: Double) -> PerpsMarginChangeReview {
            .init(
                symbol: "BTC", direction: .add, side: .long, leverage: 10, amountUsd: 5,
                allocatedMargin: .init(old: margin, new: margin + 5), liquidationPrice: nil,
                liquidationUnavailableReason: nil, isImmediateRisk: false
            )
        }
        let initial = PerpsPreparedMarginChangeAction(
            operationId: "margin", walletId: "wallet", marketId: 1, intent: marginIntent, review: review(margin: 10)
        )
        let refreshed = review(margin: 20)
        let submitted = expectation(description: "submitted with refreshed margin review")
        let service = StubTradingService(
            prepareMargin: .success(initial), previewMargin: .success(refreshed),
            onMarginSubmit: { prepared in
                XCTAssertEqual(prepared.operationId, initial.operationId)
                XCTAssertEqual(prepared.review, refreshed)
                submitted.fulfill()
            }
        )
        let (preparation, _) = makePreparation(service)
        var ready = false
        preparation.prepareMarginChange(marginIntent, isOnScreen: { true }) {
            if case .prepared = $0 { ready = true }
            changed.send()
        }
        await waitUntil { ready }

        let updated = await preparation.marginChangeReview()
        XCTAssertEqual(updated, refreshed)
        XCTAssertTrue(preparation.submitMarginChange())
        await fulfillment(of: [submitted], timeout: 2)
    }

    func testACashOutStillSettlingLeavesTheNextCashOutFree() async {
        let (preparation, _) = makePreparation(StubTradingService(prepareClose: .success(closeAction())))
        var prepared = 0

        preparation.prepareClose(marketId: 1, isOnScreen: { true }) {
            if case .prepared = $0 { prepared += 1 }
            changed.send()
        }
        await waitUntil { prepared == 1 }
        XCTAssertTrue(preparation.submitClose(onSlippage: {}))
        preparation.prepareClose(marketId: 2, isOnScreen: { true }) {
            if case .prepared = $0 { prepared += 1 }
            changed.send()
        }
        await waitUntil { prepared == 2 }

        XCTAssertEqual(prepared, 2)
    }

    func testACashOutPreparedAfterItsPageLeftIsDropped() async {
        let (preparation, _) = makePreparation(StubTradingService(prepareClose: .success(closeAction())))
        var left = false
        var reopened = false

        preparation.prepareClose(marketId: 1, isOnScreen: {
            left = true
            changed.send()
            return false
        }) { _ in XCTFail("presented without its page") }
        await waitUntil { left }
        preparation.prepareClose(marketId: 1, isOnScreen: { true }) {
            if case .prepared = $0 { reopened = true }
            changed.send()
        }
        await waitUntil { reopened }

        XCTAssertTrue(reopened)
    }

    func testACashOutTheVenueCannotFindTellsThePageAndReloadsIt() async {
        let account = StubRootAccountStore()
        let (preparation, runner) = makePreparation(StubTradingService(prepareClose: .failure(.positionNotFound)), account: account)
        let page = runner.outcomes(marketId: 1)

        preparation.prepareClose(marketId: 1, isOnScreen: { true }) { _ in XCTFail("no confirm for a missing position") }
        await TKTestSupport.waitUntil(account.callsChanged) { account.calls.contains(.refresh) }

        let received = await drain(page, runner: runner)
        XCTAssertEqual(received, [.busy(false), .toast(.failure(PerpsTradingErrorText.message(for: .positionNotFound))), .reload])
        XCTAssertEqual(account.calls, [.refresh])
    }

    func testAMarginChangeOnAGonePositionClosesTheTradeAndOtherFailuresStayOnTheForm() async {
        let account = StubRootAccountStore()
        let (gone, runner) = makePreparation(StubTradingService(prepareMargin: .failure(.orderNotFound)), account: account)
        let page = runner.outcomes(marketId: 1)
        let (refused, _) = makePreparation(StubTradingService(prepareMargin: .failure(.insufficientBalance)))
        var closedTrade = false
        var warning: String??

        gone.prepareMarginChange(marginIntent, isOnScreen: { true }) {
            if case .closeTrade = $0 { closedTrade = true }
            changed.send()
        }
        refused.prepareMarginChange(marginIntent, isOnScreen: { true }) {
            if case let .failed(text) = $0 { warning = text }
            changed.send()
        }
        await waitUntil { closedTrade && warning != nil }

        let received = await drain(page, runner: runner)
        XCTAssertTrue(closedTrade)
        XCTAssertEqual(received, [
            .busy(false),
            .reload,
            .toast(.failure(PerpsTradingErrorText.message(for: .orderNotFound, fallback: TKLocales.Perps.Toast.adjustFailed))),
        ])
        XCTAssertEqual(account.calls, [.refresh])
        XCTAssertEqual(
            warning,
            PerpsTradingErrorText.message(for: .insufficientBalance, fallback: TKLocales.Perps.Toast.adjustFailed)
        )
    }

    func testASizeChangeAnswerForASessionTheFormReplacedIsDropped() async throws {
        let (preparation, _) = makePreparation(StubTradingService(prepareSize: { intent in .success(Self.sizeAction(intent)) }))
        let replaced = preparation.beginSizeChange(marketId: 1, direction: .add, priceDecimals: 2)
        replaced.setAmount("10")
        let replacedRequest = try XCTUnwrap(replaced.beginPreparation())
        preparation.prepareSizeChange(replaced, request: replacedRequest, isOnScreen: { true }) { _ in
            XCTFail("answered a session the form replaced")
        }

        let current = preparation.beginSizeChange(marketId: 1, direction: .add, priceDecimals: 2)
        current.setAmount("20")
        let request = try XCTUnwrap(current.beginPreparation())
        var prepared = false
        preparation.prepareSizeChange(current, request: request, isOnScreen: { true }) {
            if case .prepared = $0 { prepared = true }
            changed.send()
        }
        await waitUntil { prepared }

        XCTAssertTrue(prepared)
        XCTAssertEqual(current.phase, .reviewing)
        XCTAssertEqual(replaced.phase, .finished)
    }

    func testASizeChangePreparedAfterTheTradeLeftTheScreenGoesBackToEditing() async throws {
        let (preparation, _) = makePreparation(StubTradingService(prepareSize: { intent in .success(Self.sizeAction(intent)) }))
        let session = preparation.beginSizeChange(marketId: 1, direction: .add, priceDecimals: 2)
        session.setAmount("10")
        let request = try XCTUnwrap(session.beginPreparation())

        preparation.prepareSizeChange(session, request: request, isOnScreen: { false }) { _ in
            XCTFail("answered a trade that left the screen")
        }
        await TKTestSupport.waitUntil(session) { session.phase != .preparing }

        XCTAssertEqual(session.phase, .editing)
        XCTAssertNil(session.prepared)
    }

    func testOpeningAMarketWithAnUnresolvedOperationIsRefusedOnItsPage() async {
        let (preparation, runner) = makePreparation(StubTradingService(blockedMarkets: [1]))
        let page = runner.outcomes(marketId: 1)
        var opened: [Int64] = []

        preparation.prepareOpening(marketId: 1) {
            opened.append(1)
            changed.send()
        }
        preparation.prepareOpening(marketId: 2) {
            opened.append(2)
            changed.send()
        }
        await waitUntil { opened == [2] }

        let received = await drain(page, runner: runner)
        XCTAssertEqual(opened, [2])
        XCTAssertEqual(received, [.busy(false), .toast(.failure(PerpsTradingErrorText.message(for: .operationInProgress)))])
    }

    func testAConfirmWithATakeProfitBehindThePriceOffersToGoOnWithTheStopLossOnly() async {
        let (preparation, _) = makePreparation(StubTradingService())
        let stopLoss = PerpsAutoCloseTrigger(triggerPrice: 80)
        var check: PerpsTradePreparation.AutoCloseCheck?

        preparation.checkAutoClose(
            of: openContext(autoClose: PerpsAutoClose(takeProfit: PerpsAutoCloseTrigger(triggerPrice: 90), stopLoss: stopLoss))
        ) {
            check = $0
            changed.send()
        }
        await waitUntil { check != nil }

        guard case let .stale(kind, remaining) = check else {
            return XCTFail("expected the take profit to be stale, got \(String(describing: check))")
        }
        XCTAssertEqual(kind, .takeProfit)
        XCTAssertEqual(remaining, PerpsAutoClose(takeProfit: nil, stopLoss: stopLoss))
    }

    func testAPrepareWaitsForTheActivationAndAFailedOneStaysOnTheForm() async {
        let account = StubRootAccountStore()
        account.state = .active(PerpsAccount(accountIndex: 1, availableBalance: "0", needsActivation: true))
        let (preparation, _) = makePreparation(StubTradingService(prepareMargin: .failure(.insufficientBalance)), account: account)
        var activations = 0
        preparation.activateAccount = { _ in
            activations += 1
            return .failed
        }
        var warning: String??

        preparation.prepareMarginChange(marginIntent, isOnScreen: { true }) {
            if case let .failed(text) = $0 { warning = text }
            changed.send()
        }
        await waitUntil { warning != nil }

        XCTAssertEqual(activations, 1)
        XCTAssertEqual(warning, .some(nil))
        XCTAssertEqual(account.calls, [])
    }

    private func makePreparation(
        _ service: StubTradingService,
        account: StubRootAccountStore = StubRootAccountStore()
    ) -> (PerpsTradePreparation, PerpsTradeRunner) {
        let context = PerpsFlowContext(
            dependencies: StubDependencies(),
            wallet: PerpsWalletDependencies(
                accountStore: account,
                tradingService: service,
                activateAccount: { _, _, _ in .canceled },
                signingPasscode: { _, _ in nil },
                recoverFunding: {},
                refreshFunding: {},
                makeDeposit: { _ in nil },
                makeHistory: { _, _, _, _, _ in nil },
                track: { _ in }
            )
        )
        return (PerpsTradePreparation(context: context, passcodeProvider: { nil }), context.tradeRunner)
    }

    private func drain(
        _ outcomes: AsyncStream<PerpsTradeRunner.Outcome>,
        runner: PerpsTradeRunner
    ) async -> [PerpsTradeRunner.Outcome] {
        let end = PerpsTradeRunner.Outcome.dismissToast(.progress("end"))
        runner.publish(end, marketId: 1)
        var received: [PerpsTradeRunner.Outcome] = []
        for await outcome in outcomes {
            if outcome == end { break }
            received.append(outcome)
        }
        return received
    }

    private func waitUntil(file: StaticString = #filePath, line: UInt = #line, _ condition: () -> Bool) async {
        await TKTestSupport.waitUntil(changed, file: file, line: line, condition)
    }

    private let marginIntent = PerpsMarginChangeIntent(marketId: 1, direction: .add, amountUsd: "5")

    private func closeAction() -> PerpsPreparedCloseAction {
        PerpsPreparedCloseAction(
            operationId: "op",
            walletId: "wallet",
            marketId: 1,
            review: PerpsCloseReview(
                symbol: "BTC", side: .long, leverage: 10, marginUsd: 10, notionalUsd: 100, baseSize: 1,
                estimatedFeeUsd: nil, feeRatePercent: nil, estimatedPnlUsd: nil, estimatedReceiveUsd: nil
            )
        )
    }

    private nonisolated static func sizeAction(_ intent: PerpsSizeChangeIntent) -> PerpsPreparedSizeChangeAction {
        PerpsPreparedSizeChangeAction(
            operationId: "op",
            walletId: "wallet",
            marketId: intent.marketId,
            intent: intent,
            review: PerpsSizeChangeReviewFixture.make(),
            normalizedAutoClose: nil
        )
    }

    private func openContext(autoClose: PerpsAutoClose) -> PerpsConfirmContext {
        PerpsConfirmContext(
            intent: PerpsOpenMarketIntent(
                marketId: 1, side: .long, marginUsd: "10", leverage: 5, maxSlippage: 0.01, autoClose: autoClose
            ),
            sizeDecimals: 2,
            priceDecimals: 2,
            review: PerpsOpenOrderReview(
                symbol: "BTC", marginUsd: 10, entryPrice: 100, liquidationPrice: 50, notionalUsd: 50, baseSize: 0.5,
                estimatedFeeUsd: nil, feeRatePercent: nil, liquidationUnavailableReason: nil
            )
        )
    }
}
