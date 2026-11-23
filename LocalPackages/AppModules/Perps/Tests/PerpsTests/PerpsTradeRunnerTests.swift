@testable import Perps
import PerpsModels
import TKLocalize
import UIKit
import XCTest

@MainActor
final class PerpsTradeRunnerTests: XCTestCase {
    func testAConfirmedCloseTellsItsPageAndFinishes() async {
        let account = StubRootAccountStore()
        let runner = makeRunner(
            StubTradingService(submit: .submitted(pending(.close)), reconciles: [.pending, .confirmed]),
            account: account
        )
        let page = runner.outcomes(marketId: 1)
        var slippages = 0
        var finished = false

        runner.close(closeAction(), passcodeProvider: { nil }, onSlippage: { slippages += 1 }, onFinish: { finished = true })
        await waitUntil { finished }

        let closed = PerpsAssetPageViewModel.closeToastText(
            verb: TKLocales.Perps.Toast.closed, symbol: "BTC", side: .long, leverage: 10, format: .test
        )
        let received = await drain(page, marketId: 1, runner: runner)
        XCTAssertTrue(finished)
        XCTAssertEqual(received, [.busy(false), .toast(.success(closed)), .reload])
        XCTAssertEqual(account.calls, [])
        XCTAssertEqual(slippages, 0)
    }

    func testAConfirmedCloseReportsHowLongTheUserWaited() async {
        let reported = expectation(description: "wait reported")
        let runner = makeRunner(StubTradingService(submit: .submitted(pending(.close)), onWait: { wait in
            XCTAssertEqual(wait, .positionClose)
            reported.fulfill()
        }))

        runner.close(closeAction(), passcodeProvider: { nil }, onSlippage: { XCTFail("slippage") })

        await fulfillment(of: [reported], timeout: 2)
    }

    func testAWaitInterruptedByTheBackgroundOrAPasscodeIsNotReported() async {
        for asksPasscode in [false, true] {
            let reported = expectation(description: "wait reported")
            reported.isInverted = true
            var finished = false
            let runner = makeRunner(StubTradingService(
                submit: .submitted(pending(.close)),
                asksPasscode: asksPasscode,
                onWait: { _ in reported.fulfill() }
            ))

            runner.close(closeAction(), passcodeProvider: { "1111" }, onSlippage: { XCTFail("slippage") }, onFinish: { finished = true })
            if !asksPasscode {
                NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
            }
            await waitUntil { finished }

            XCTAssertTrue(finished)
            await fulfillment(of: [reported], timeout: 0)
        }
    }

    func testAnOpenBackgroundedBeforeItBeganOpeningIsNotReported() async {
        let flow = PerpsOpenPositionFlow()
        let reported = expectation(description: "wait reported")
        reported.isInverted = true
        let runner = makeRunner(
            StubTradingService(submit: .submitted(pending(.open(limitPrice: nil))), onWait: { _ in reported.fulfill() }),
            flow: flow
        )
        XCTAssertTrue(flow.begin(marketId: 1))

        runner.open(
            openContext(),
            ensureAccountReady: { _ in
                NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
                try? await Task.sleep(nanoseconds: 1_000_000)
                return true
            },
            passcodeProvider: { nil },
            onBeginOpening: {},
            onCanceled: { XCTFail("canceled") },
            onSlippage: { XCTFail("slippage") }
        )
        await waitUntil { flow.activeTrade(marketId: 1) == nil && flow.composingMarketId == nil }

        XCTAssertNil(flow.activeTrade(marketId: 1))
        await fulfillment(of: [reported], timeout: 0)
    }

    func testAPasscodeDirtiesOnlyItsOwnWaitAndTheBackgroundDirtiesEveryWait() async {
        let asked = PerpsWaitMeasurement()
        let other = PerpsWaitMeasurement()
        asked.begin()
        other.begin()

        let passcodeProvider = asked.dirtying { "1111" }
        _ = await passcodeProvider()

        XCTAssertNil(asked.cleanMilliseconds())
        XCTAssertNotNil(other.cleanMilliseconds())
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertNil(other.cleanMilliseconds())
    }

    func testOnlyAConfirmedMarketOpenReportsHowLongTheUserWaited() async {
        for limitPrice: Double? in [nil, 100] {
            let flow = PerpsOpenPositionFlow()
            let reported = expectation(description: "wait reported")
            reported.isInverted = limitPrice != nil
            let runner = makeRunner(
                StubTradingService(submit: .submitted(pending(.open(limitPrice: limitPrice))), onWait: { wait in
                    XCTAssertEqual(wait, .positionOpen)
                    reported.fulfill()
                }),
                flow: flow
            )
            XCTAssertTrue(flow.begin(marketId: 1))

            runner.open(
                openContext(),
                ensureAccountReady: { _ in true },
                passcodeProvider: { nil },
                onBeginOpening: {},
                onCanceled: { XCTFail("canceled") },
                onSlippage: { XCTFail("slippage") }
            )
            await waitUntil { flow.activeTrade(marketId: 1) == nil && flow.composingMarketId == nil }

            await fulfillment(of: [reported], timeout: 0)
        }
    }

    func testARefusedCloseShowsWhyAndRefreshes() async {
        let account = StubRootAccountStore()
        let runner = makeRunner(StubTradingService(submit: .failed(.insufficientBalance)), account: account)
        let page = runner.outcomes(marketId: 1)
        var finished = false

        runner.close(closeAction(), passcodeProvider: { nil }, onSlippage: {}, onFinish: { finished = true })
        await waitUntil { finished }

        let message = PerpsTradingErrorText.message(for: .insufficientBalance, fallback: TKLocales.Perps.Toast.closeFailed)
        let received = await drain(page, marketId: 1, runner: runner)
        XCTAssertTrue(finished)
        XCTAssertEqual(received, [.busy(false), .toast(.failure(message)), .reload])
        XCTAssertEqual(account.calls, [.refresh])
    }

    func testAnOutcomeTheVenueNeverStatesEndsUnknownAtTheCeiling() async {
        let account = StubRootAccountStore()
        let service = StubTradingService(submit: .submitUnknown(pending(.close)), reconciles: [.pending])
        let runner = makeRunner(service, account: account)
        let page = runner.outcomes(marketId: 1)
        var finished = false

        runner.close(closeAction(), passcodeProvider: { nil }, onSlippage: {}, onFinish: { finished = true })
        await waitUntil { finished }

        let received = await drain(page, marketId: 1, runner: runner)
        let polls = await service.reconciles.calls
        XCTAssertTrue(finished)
        XCTAssertEqual(received, [.busy(false), .reload, .toast(.unknown(TKLocales.Perps.Toast.statusUnknown))])
        XCTAssertEqual(account.calls, [.refresh])
        XCTAssertEqual(polls, PerpsTradeRunner.reconcileCeiling)
    }

    func testAFailureWithItsPageClosedWaitsForThatPage() async {
        let runner = makeRunner(StubTradingService())
        runner.publish(.toast(.failure("lost")), marketId: 1)
        runner.publish(.toast(.failure("superseded")), marketId: 2)
        runner.publish(.toast(.success("done")), marketId: 2)

        let returned = await drain(runner.outcomes(marketId: 1), marketId: 1, runner: runner)
        let shownOnce = await drain(runner.outcomes(marketId: 1), marketId: 1, runner: runner)
        let otherMarket = await drain(runner.outcomes(marketId: 2), marketId: 2, runner: runner)

        XCTAssertEqual(returned, [.toast(.failure("lost")), .busy(false)])
        XCTAssertEqual(shownOnce, [.busy(false)])
        XCTAssertEqual(otherMarket, [.busy(false)])
    }

    func testFirstReadsAreFastAndTheWaitStaysAboutAMinute() {
        let runner = PerpsTradeRunner(
            tradingService: StubTradingService(submit: .submitted(pending(.close)), reconciles: [.pending]),
            accountStore: StubRootAccountStore(),
            openPositionFlow: PerpsOpenPositionFlow(),
            format: .test,
            track: { _ in },
            reconcileIntervalNanos: 1_000_000_000
        )
        let delays = (0 ..< PerpsTradeRunner.reconcileCeiling - 1).map { runner.reconcileDelayNanos(afterRead: $0) }

        XCTAssertEqual(Array(delays.prefix(PerpsTradeRunner.fastReconcileReads)), Array(repeating: 250_000_000, count: PerpsTradeRunner.fastReconcileReads))
        XCTAssertEqual(delays.last, 1_000_000_000)
        XCTAssertEqual(delays.reduce(0, +), 60_000_000_000)
    }

    func testAChangeOtherThanAMarketFillGivesUpAfterAMinuteOfReads() async {
        let service = StubTradingService(
            submit: .submitUnknown(pending(.autoCloseChange(.init(target: nil, restingOrderIndexes: [7])))),
            reconciles: [.pending]
        )
        let runner = makeRunner(service)
        let prepared = PerpsPreparedAutoCloseChangeAction(
            operationId: "op",
            walletId: "wallet",
            marketId: 1,
            intent: PerpsAutoCloseChangeIntent(marketId: 1, target: PerpsAutoClose(takeProfit: nil, stopLoss: nil)),
            review: PerpsAutoCloseChangeReview(side: .long, new: nil)
        )

        let result = await runner.changeAutoClose(prepared, passcodeProvider: { nil }, onConfirmed: {})

        let polls = await service.reconciles.calls
        XCTAssertEqual(result.failureText, TKLocales.Perps.Toast.statusUnknown)
        XCTAssertEqual(polls, PerpsTradeRunner.fullIntervalReconcileCeiling)
    }

    func testAnAddRefusedForTheRegionAsksForTheSheetInsteadOfAToast() async {
        let account = StubRootAccountStore()
        let runner = makeRunner(StubTradingService(submit: .failed(.regionUnavailable)), account: account)
        let page = runner.outcomes(marketId: 1)
        var sheets = 0
        var finished = false
        runner.onRegionRestricted = { _ in sheets += 1 }

        runner.changeSize(sizeAction(.add), passcodeProvider: { nil }, onSlippage: { XCTFail("slippage") }, onFinish: { finished = true })
        await waitUntil { finished }

        let received = await drain(page, marketId: 1, runner: runner)
        XCTAssertEqual(sheets, 1)
        XCTAssertEqual(received, [.busy(false), .reload])
        XCTAssertEqual(account.calls, [.refresh])
    }

    func testALimitEditRefusedForTheRegionAsksForTheSheetAndACancelKeepsItsToast() async {
        let edit = PerpsLimitOrderChangeIntent.modify(marketId: 1, orderIndex: 7, limitPrice: 1950, baseAmount: 0.5, orderId: "lighter:7")
        let cancel = PerpsLimitOrderChangeIntent.cancel(marketId: 1, orderIndex: 7, orderId: "lighter:7")
        for intent in [edit, cancel] {
            let prepared = limitChange(intent)
            let runner = makeRunner(StubTradingService(prepareLimitOrder: { _ in .success(prepared) }, submit: .failed(.regionUnavailable)))
            let page = runner.outcomes(marketId: 1)
            var sheets: [Int64] = []
            runner.onRegionRestricted = { sheets.append($0) }

            runner.changeLimitOrder(intent, ensureAccountReady: { _ in true }, passcodeProvider: { nil }, confirm: { _, submit in submit() })
            await waitUntil { !runner.isBusy(1) }

            let progress = PerpsAssetPageTradeToast.progress(PerpsAssetPageViewModel.limitOrderChangeToastText(intent.kind, isDone: false))
            let shown = await drain(page, marketId: 1, runner: runner).filter { if case .busy = $0 { return false }; return true }
            switch intent.kind {
            case .modify:
                XCTAssertEqual(sheets, [1])
                XCTAssertEqual(shown, [.toast(progress), .dismissToast(progress)])
            case .cancel:
                XCTAssertEqual(sheets, [])
                XCTAssertEqual(shown, [.toast(progress), .toast(.failure(PerpsTradingErrorText.message(for: .regionUnavailable)))])
            }
        }
    }

    func testAnExitRefusedForTheRegionKeepsItsToast() async {
        let message = PerpsTradingErrorText.message(for: .regionUnavailable)
        let exits: [(String, (PerpsTradeRunner, @escaping @MainActor () -> Void) -> Void)] = [
            ("close", { $0.close(self.closeAction(), passcodeProvider: { nil }, onSlippage: {}, onFinish: $1) }),
            ("reduce", { $0.changeSize(self.sizeAction(.reduce), passcodeProvider: { nil }, onSlippage: {}, onFinish: $1) }),
        ]
        for (name, exit) in exits {
            let runner = makeRunner(StubTradingService(submit: .failed(.regionUnavailable)))
            let page = runner.outcomes(marketId: 1)
            var finished = false
            runner.onRegionRestricted = { _ in XCTFail("sheet on \(name)") }

            exit(runner) { finished = true }
            await waitUntil { finished }

            let received = await drain(page, marketId: 1, runner: runner)
            XCTAssertEqual(received, [.busy(false), .toast(.failure(message)), .reload], name)
        }
    }

    func testSlippageAsksForTheAlertInsteadOfAToast() async {
        let account = StubRootAccountStore()
        let runner = makeRunner(
            StubTradingService(submit: .submitted(pending(.close)), reconciles: [.failed(.slippageExceeded)]),
            account: account
        )
        let page = runner.outcomes(marketId: 1)
        var slippages = 0
        var finished = false

        runner.close(closeAction(), passcodeProvider: { nil }, onSlippage: { slippages += 1 }, onFinish: { finished = true })
        await waitUntil { finished }

        let received = await drain(page, marketId: 1, runner: runner)
        XCTAssertEqual(slippages, 1)
        XCTAssertEqual(received, [.busy(false), .reload])
        XCTAssertEqual(account.calls, [.refresh])
    }

    func testAnOutcomeReachesOnlyThePageOfItsMarket() async {
        let runner = makeRunner(StubTradingService(submit: .submitted(pending(.close)), reconciles: [.confirmed]))
        let otherPage = runner.outcomes(marketId: 2)
        let page = runner.outcomes(marketId: 1)
        var finished = false

        runner.close(closeAction(), passcodeProvider: { nil }, onSlippage: {}, onFinish: { finished = true })
        await waitUntil { finished }

        let otherReceived = await drain(otherPage, marketId: 2, runner: runner)
        let received = await drain(page, marketId: 1, runner: runner)
        XCTAssertEqual(otherReceived, [.busy(false)])
        XCTAssertEqual(received.count, 3)
    }

    func testOpeningDismissesTheFormAndSettlesOnThePage() async {
        let account = StubRootAccountStore()
        let flow = PerpsOpenPositionFlow()
        let context = openContext()
        let prepared = PerpsPreparedTradingAction(
            operationId: "op", walletId: "wallet", marketId: 1, intent: context.intent, review: context.review
        )
        let runner = makeRunner(
            StubTradingService(prepareOpen: .success(prepared), submit: .submitted(pending(.open(limitPrice: nil)))),
            account: account,
            flow: flow
        )
        let page = runner.outcomes(marketId: 1)
        var callsWhenDismissed: [StubRootAccountStore.Call]?
        XCTAssertTrue(flow.begin(marketId: 1))

        runner.open(
            context,
            ensureAccountReady: { _ in true },
            passcodeProvider: { nil },
            onBeginOpening: { callsWhenDismissed = account.calls },
            onCanceled: { XCTFail("canceled") },
            onSlippage: { XCTFail("slippage") }
        )
        XCTAssertEqual(flow.activeTrade(marketId: 1)?.marginUsd, 9.8)
        await waitUntil { flow.activeTrade(marketId: 1) == nil && flow.composingMarketId == nil }

        let format = PerpsFormatting.test
        let opened = "\(TKLocales.Perps.Toast.opened) \(TKLocales.Perps.Toast.long("BTC")): "
            + "\(format.balance(9.8)) · \(format.leverage(5))"
        let received = await drain(page, marketId: 1, runner: runner)
        XCTAssertNil(flow.activeTrade(marketId: 1))
        XCTAssertNil(flow.composingMarketId)
        XCTAssertEqual(callsWhenDismissed, [])
        XCTAssertEqual(account.calls, [.refresh])
        XCTAssertEqual(received, [.busy(false), .toast(.success(opened)), .reload])
    }

    func testOpeningSubmitsTheReviewedOpenWithoutPlanningItFirst() async {
        let flow = PerpsOpenPositionFlow()
        let runner = makeRunner(
            StubTradingService(prepareOpen: .failure(.offline), submit: .submitted(pending(.open(limitPrice: nil)))),
            flow: flow
        )
        let page = runner.outcomes(marketId: 1)
        XCTAssertTrue(flow.begin(marketId: 1))

        runner.open(
            openContext(),
            ensureAccountReady: { _ in true },
            passcodeProvider: { nil },
            onBeginOpening: {},
            onCanceled: { XCTFail("canceled") },
            onSlippage: { XCTFail("slippage") }
        )
        await waitUntil { flow.activeTrade(marketId: 1) == nil && flow.composingMarketId == nil }

        let received = await drain(page, marketId: 1, runner: runner)
        XCTAssertEqual(received.last, .reload)
        XCTAssertTrue(received.contains { if case .toast(.success) = $0 { return true }; return false })
    }

    func testOnlyAnOpeningWithASentStepCountsAsSubmitted() async {
        for state in [PerpsPendingStepState.signed, .sending] {
            let flow = PerpsOpenPositionFlow()
            let context = openContext()
            let prepared = PerpsPreparedTradingAction(
                operationId: "op", walletId: "wallet", marketId: 1, intent: context.intent, review: context.review
            )
            let opening = PerpsPendingTradingAction(
                operationId: "op", walletId: "wallet", marketId: 1, side: .long, payload: .open(limitPrice: nil),
                orderRefs: [PerpsPendingOrderRef(role: .parent, clientOrderIndex: 42)],
                signedSteps: [PerpsPendingSignedStep(
                    stepId: "order", attemptId: "attempt", nonce: 1, transactionExpiryUnixMs: 1, txType: 14,
                    txInfo: "payload", txHash: "hash", state: state
                )]
            )
            var submitted: [PerpsOpeningDescriptor] = []
            var clientOrderIndexes: [Int64] = []
            let runner = makeRunner(
                StubTradingService(prepareOpen: .success(prepared), submit: .submitUnknown(opening)),
                flow: flow,
                track: {
                    if case let .orderSubmitted(order, clientOrderIndex) = $0 {
                        submitted.append(order)
                        clientOrderIndexes.append(clientOrderIndex)
                    }
                }
            )
            XCTAssertTrue(flow.begin(marketId: 1))

            runner.open(
                context,
                ensureAccountReady: { _ in true },
                passcodeProvider: { nil },
                onBeginOpening: {},
                onCanceled: { XCTFail("canceled") },
                onSlippage: { XCTFail("slippage") }
            )
            await waitUntil { flow.activeTrade(marketId: 1) == nil && flow.composingMarketId == nil }

            let order = PerpsOpeningDescriptor(marketId: 1, symbol: "BTC", side: .long, marginUsd: 9.8, leverage: 5, isLimit: false)
            XCTAssertEqual(submitted, state == .signed ? [] : [order])
            XCTAssertEqual(clientOrderIndexes, state == .signed ? [] : [42])
        }
    }

    func testACanceledActivationGivesTheConfirmationBack() async {
        let account = StubRootAccountStore()
        let flow = PerpsOpenPositionFlow()
        let runner = makeRunner(StubTradingService(), account: account, flow: flow)
        var canceled = false
        XCTAssertTrue(flow.begin(marketId: 1))

        runner.open(
            openContext(),
            ensureAccountReady: { _ in false },
            passcodeProvider: { nil },
            onBeginOpening: { XCTFail("opened") },
            onCanceled: { canceled = true },
            onSlippage: {}
        )
        await waitUntil { canceled }

        XCTAssertTrue(canceled)
        XCTAssertEqual(flow.composingMarketId, 1)
        XCTAssertEqual(account.calls, [])
    }

    func testALimitOrderChangeKeepsItsMarketBusyUntilItSettles() async {
        let runner = makeRunner(StubTradingService(prepareLimitOrder: { _ in .failure(.orderNotFound) }))
        let page = runner.outcomes(marketId: 1)

        runner.changeLimitOrder(
            .cancel(marketId: 1, orderIndex: 7, orderId: "lighter:7"),
            ensureAccountReady: { _ in true },
            passcodeProvider: { nil },
            confirm: { _, submit in submit() }
        )
        let pageOpenedMeanwhile = runner.outcomes(marketId: 1)
        XCTAssertTrue(runner.isBusy(1))
        await waitUntil { !runner.isBusy(1) }

        let failure = PerpsTradeRunner.Outcome.toast(.failure(PerpsTradingErrorText.message(for: .orderNotFound)))
        let received = await drain(page, marketId: 1, runner: runner)
        let receivedMeanwhile = await drain(pageOpenedMeanwhile, marketId: 1, runner: runner)
        XCTAssertFalse(runner.isBusy(1))
        XCTAssertEqual(received, [.busy(false), .busy(true), failure, .busy(false)])
        XCTAssertEqual(receivedMeanwhile, [.busy(true), failure, .busy(false)])
    }

    func testALegPastTheNewPriceIsCancelledOnlyOnceTheEditIsConfirmedAndBeforeItIsSigned() async {
        let prepares = LimitIntentLog()
        let submits = LimitIntentLog()
        let edit = PerpsLimitOrderChangeIntent.modify(marketId: 1, orderIndex: 7, limitPrice: 2200, baseAmount: 0.5, orderId: "lighter:7")
        let legCancel = PerpsLimitOrderChangeIntent.cancel(marketId: 1, orderIndex: 70, orderId: "")
        let preparedEdit = limitChange(edit)
        let preparedLegCancel = limitChange(legCancel)
        let account = StubRootAccountStore()
        let runner = makeRunner(StubTradingService(
            prepareLimitOrder: { intent in
                prepares.append(intent)
                return .success(intent == legCancel ? preparedLegCancel : preparedEdit)
            },
            submit: .submitted(pending(.close)),
            limitSubmits: submits
        ), account: account)
        let page = runner.outcomes(marketId: 1)
        var confirm: (@MainActor () -> Void)?

        runner.changeLimitOrder(edit, cancellingFirst: [70], ensureAccountReady: { _ in true }, passcodeProvider: { nil }) { _, submit in
            confirm = submit
        }
        await waitUntil { confirm != nil }
        let beforeConfirming = await drain(page, marketId: 1, runner: runner)

        XCTAssertEqual(prepares.intents, [edit])
        XCTAssertEqual(submits.intents, [])
        XCTAssertEqual(beforeConfirming, [.busy(false), .busy(true), .busy(false)])

        confirm?()
        await waitUntil { !runner.isBusy(1) }

        XCTAssertEqual(prepares.intents, [edit, legCancel])
        XCTAssertEqual(submits.intents, [legCancel, edit])
        XCTAssertEqual(account.calls, [.loadMarketExtras(1)])
    }

    func testAnExitThatReloadsItselfAfterALegIsCancelledReloadsOnce() async {
        let account = StubRootAccountStore()
        let edit = PerpsLimitOrderChangeIntent.modify(marketId: 1, orderIndex: 7, limitPrice: 2200, baseAmount: 0.5, orderId: "lighter:7")
        let preparedEdit = limitChange(edit)
        let runner = makeRunner(StubTradingService(
            prepareLimitOrder: { intent in intent.kind == .cancel ? .failure(.nothingToChange) : .success(preparedEdit) },
            submit: .failed(.orderNotFound)
        ), account: account)

        runner.changeLimitOrder(
            edit,
            cancellingFirst: [70],
            ensureAccountReady: { _ in true },
            passcodeProvider: { nil },
            confirm: { _, submit in submit() }
        )
        await waitUntil { !runner.isBusy(1) }

        XCTAssertEqual(account.calls, [.loadMarketExtras(1)])
    }

    func testALegThatCouldNotBeCancelledLeavesTheLimitWhereItIs() async {
        let prepares = LimitIntentLog()
        let submits = LimitIntentLog()
        let edit = PerpsLimitOrderChangeIntent.modify(marketId: 1, orderIndex: 7, limitPrice: 2200, baseAmount: 0.5, orderId: "lighter:7")
        let preparedEdit = limitChange(edit)
        let runner = makeRunner(StubTradingService(
            prepareLimitOrder: { intent in
                prepares.append(intent)
                return intent.kind == .cancel ? .failure(.offline) : .success(preparedEdit)
            },
            limitSubmits: submits
        ))

        runner.changeLimitOrder(
            edit,
            cancellingFirst: [70],
            ensureAccountReady: { _ in true },
            passcodeProvider: { nil },
            confirm: { _, submit in submit() }
        )
        await waitUntil { !runner.isBusy(1) }

        XCTAssertEqual(prepares.intents, [edit, .cancel(marketId: 1, orderIndex: 70, orderId: "")])
        XCTAssertEqual(submits.intents, [])
    }

    func testAnEditedLimitOrderIsSubmittedOnlyOnceItsReviewIsConfirmed() async {
        let edit = PerpsLimitOrderChangeIntent.modify(marketId: 1, orderIndex: 7, limitPrice: 1950, baseAmount: 0.5, orderId: "lighter:7")
        let prepared = PerpsPreparedLimitOrderChangeAction(
            operationId: "op",
            walletId: "wallet",
            marketId: 1,
            intent: edit,
            review: PerpsLimitOrderChangeReview(
                order: PerpsLimitOrderSummary(orderIndex: 7, clientOrderIndex: 7, side: .long, limitPrice: 1900, remainingBaseAmount: 0.5),
                kind: .modify,
                limitPrice: 1950,
                baseAmount: 0.5
            )
        )
        let runner = makeRunner(StubTradingService(prepareLimitOrder: { _ in .success(prepared) }, submit: .failed(.offline)))
        let page = runner.outcomes(marketId: 1)
        var reviewed: PerpsPreparedLimitOrderChangeAction?
        var confirm: (@MainActor () -> Void)?

        runner.changeLimitOrder(edit, ensureAccountReady: { _ in true }, passcodeProvider: { nil }) { prepared, submit in
            reviewed = prepared
            confirm = submit
        }
        await waitUntil { confirm != nil }
        let beforeConfirming = await drain(page, marketId: 1, runner: runner)
        confirm?()
        await waitUntil { !runner.isBusy(1) }

        XCTAssertEqual(reviewed?.review.baseAmount, 0.5)
        XCTAssertEqual(beforeConfirming, [.busy(false), .busy(true), .busy(false)])
        let submitted = await drain(page, marketId: 1, runner: runner)
        XCTAssertEqual(submitted.first, .busy(true))
        XCTAssertTrue(submitted.contains(.toast(.failure(PerpsTradingErrorText.message(for: .offline)))))
    }

    func testAConfirmedAutoCloseChangeRefreshesTheAccountItself() async {
        let account = StubRootAccountStore()
        let runner = makeRunner(StubTradingService(submit: .submitted(pending(.close))), account: account)
        let prepared = PerpsPreparedAutoCloseChangeAction(
            operationId: "op",
            walletId: "wallet",
            marketId: 1,
            intent: PerpsAutoCloseChangeIntent(marketId: 1, target: PerpsAutoClose(takeProfit: nil, stopLoss: nil)),
            review: PerpsAutoCloseChangeReview(side: .long, new: nil)
        )
        var confirmed = false

        let result = await runner.changeAutoClose(prepared, passcodeProvider: { nil }, onConfirmed: { confirmed = true })

        guard case .finished = result else { return XCTFail("expected the change to finish, got \(result)") }
        XCTAssertTrue(confirmed)
        XCTAssertEqual(account.calls, [.refresh, .loadMarketExtras(1)])
    }

    func testAReloadFromTheRunnerLeavesTheAccountRefreshToTheRunner() async {
        let runnerAccount = StubRootAccountStore()
        let pageAccount = StubRootAccountStore()
        let runner = makeRunner(StubTradingService(), account: runnerAccount)
        let page = PerpsAssetPageViewModel(
            marketId: 1,
            store: StubRootMarketsStore(),
            marketDetailsStore: NoMarketDetails(),
            accountStore: pageAccount,
            openPositionFlow: PerpsOpenPositionFlow(),
            tradeOutcomes: { runner.outcomes(marketId: 1) },
            format: .test,
            loyalty: nil
        )
        page.onWillAppear()

        runner.refreshAfterTrade(marketId: 1)
        await waitUntil { runnerAccount.calls == [.refresh] }
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(runnerAccount.calls, [.refresh])
        XCTAssertEqual(pageAccount.calls, [], "the page refreshed the account or its extras a second time")
        _ = page
    }

    func testThePageSubscriptionGoesAwayWithThePage() async {
        let runner = makeRunner(StubTradingService())
        weak var page: PerpsAssetPageViewModel?

        autoreleasepool {
            let viewModel = PerpsAssetPageViewModel(
                marketId: 1,
                store: StubRootMarketsStore(),
                marketDetailsStore: NoMarketDetails(),
                accountStore: StubRootAccountStore(),
                openPositionFlow: PerpsOpenPositionFlow(),
                tradeOutcomes: { runner.outcomes(marketId: 1) },
                format: .test,
                loyalty: nil
            )
            page = viewModel
            viewModel.onWillAppear()
            XCTAssertEqual(subscriberCount(runner), 1)
        }
        await waitUntil { subscriberCount(runner) == 0 }

        XCTAssertNil(page)
        XCTAssertEqual(subscriberCount(runner), 0)
    }

    func testAFailureWhileThePageIsCoveredWaitsForItToComeBack() async {
        let runner = makeRunner(StubTradingService())
        let page = PerpsAssetPageViewModel(
            marketId: 1,
            store: StubRootMarketsStore(),
            marketDetailsStore: NoMarketDetails(),
            accountStore: StubRootAccountStore(),
            openPositionFlow: PerpsOpenPositionFlow(),
            tradeOutcomes: { runner.outcomes(marketId: 1) },
            format: .test,
            loyalty: nil
        )
        page.onWillAppear()
        page.onAppear()
        page.onDisappear()
        await waitUntil { subscriberCount(runner) == 0 }
        XCTAssertEqual(subscriberCount(runner), 0, "a covered page still takes outcomes")

        runner.publish(.toast(.failure("lost")), marketId: 1)
        page.onWillAppear()
        await waitUntil { page.tradeToast != nil }

        XCTAssertEqual(page.tradeToast, .failure("lost"))
    }

    private func makeRunner(
        _ service: StubTradingService,
        account: StubRootAccountStore = StubRootAccountStore(),
        flow: PerpsOpenPositionFlow? = nil,
        track: @escaping (PerpsAnalyticsEvent) -> Void = { _ in }
    ) -> PerpsTradeRunner {
        PerpsTradeRunner(
            tradingService: service,
            accountStore: account,
            openPositionFlow: flow ?? PerpsOpenPositionFlow(),
            format: .test,
            track: track,
            reconcileIntervalNanos: 0
        )
    }

    private func drain(
        _ outcomes: AsyncStream<PerpsTradeRunner.Outcome>,
        marketId: Int64,
        runner: PerpsTradeRunner
    ) async -> [PerpsTradeRunner.Outcome] {
        let end = PerpsTradeRunner.Outcome.dismissToast(.progress("end"))
        runner.publish(end, marketId: marketId)
        var received: [PerpsTradeRunner.Outcome] = []
        for await outcome in outcomes {
            if outcome == end { break }
            received.append(outcome)
        }
        return received
    }

    private func waitUntil(_ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(2)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    private func subscriberCount(_ runner: PerpsTradeRunner) -> Int {
        (Mirror(reflecting: runner).descendant("subscribers") as? [UUID: Any])?.count ?? -1
    }

    private func pending(_ payload: PerpsPendingPayload) -> PerpsPendingTradingAction {
        PerpsPendingTradingAction(operationId: "op", walletId: "wallet", marketId: 1, side: .long, payload: payload)
    }

    private func limitChange(_ intent: PerpsLimitOrderChangeIntent) -> PerpsPreparedLimitOrderChangeAction {
        PerpsPreparedLimitOrderChangeAction(
            operationId: "op",
            walletId: "wallet",
            marketId: intent.marketId,
            intent: intent,
            review: PerpsLimitOrderChangeReview(
                order: PerpsLimitOrderSummary(orderIndex: intent.orderIndex, clientOrderIndex: intent.orderIndex, side: .long, limitPrice: 1900, remainingBaseAmount: 0.5),
                kind: intent.kind,
                limitPrice: nil,
                baseAmount: 0.5
            )
        )
    }

    private func sizeAction(_ direction: PerpsSizeChangeDirection) -> PerpsPreparedSizeChangeAction {
        PerpsPreparedSizeChangeAction(
            operationId: "op",
            walletId: "wallet",
            marketId: 1,
            intent: PerpsSizeChangeIntent(marketId: 1, direction: direction, marginDeltaUsd: "10"),
            review: PerpsSizeChangeReviewFixture.make(direction: direction),
            normalizedAutoClose: nil
        )
    }

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

    private func openContext() -> PerpsConfirmContext {
        PerpsConfirmContext(
            intent: PerpsOpenMarketIntent(
                marketId: 1, side: .long, marginUsd: "10", leverage: 5, maxSlippage: 0.01, autoClose: nil
            ),
            sizeDecimals: 2,
            priceDecimals: 2,
            review: PerpsOpenOrderReview(
                symbol: "BTC", marginUsd: 9.8, entryPrice: 100, liquidationPrice: nil, notionalUsd: 49, baseSize: 0.49,
                estimatedFeeUsd: nil, feeRatePercent: nil, liquidationUnavailableReason: nil
            )
        )
    }
}

actor ReconcileScript {
    private var results: [PerpsReconcileResult]
    private(set) var calls = 0

    init(_ results: [PerpsReconcileResult]) {
        self.results = results
    }

    func next() -> PerpsReconcileResult {
        calls += 1
        return results.count > 1 ? results.removeFirst() : results[0]
    }
}

final class LimitIntentLog: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [PerpsLimitOrderChangeIntent] = []

    var intents: [PerpsLimitOrderChangeIntent] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func append(_ intent: PerpsLimitOrderChangeIntent) {
        lock.lock()
        defer { lock.unlock() }
        recorded.append(intent)
    }
}

final class StubTradingService: PerpsTradingService {
    let reconciles: ReconcileScript
    private let prepareOpenResult: Result<PerpsPreparedTradingAction, PerpsTradingError>
    private let prepareLimitOrderResult: @Sendable (PerpsLimitOrderChangeIntent) -> Result<PerpsPreparedLimitOrderChangeAction, PerpsTradingError>
    private let prepareCloseResult: Result<PerpsPreparedCloseAction, PerpsTradingError>
    private let prepareMarginResult: Result<PerpsPreparedMarginChangeAction, PerpsTradingError>
    private let previewCloseResult: Result<PerpsCloseReview, PerpsTradingError>
    private let previewMarginResult: Result<PerpsMarginChangeReview, PerpsTradingError>
    private let onCloseSubmit: @Sendable (PerpsPreparedCloseAction) -> Void
    private let onMarginSubmit: @Sendable (PerpsPreparedMarginChangeAction) -> Void
    private let prepareSizeResult: @Sendable (PerpsSizeChangeIntent) -> Result<PerpsPreparedSizeChangeAction, PerpsTradingError>
    private let blockedMarkets: Set<Int64>
    private let submitResult: PerpsSubmitResult
    private let limitSubmits: LimitIntentLog?
    private let openContext: PerpsOpenMarketContext?
    private let asksPasscode: Bool
    private let onWait: @Sendable (PerpsTradeWait) -> Void

    init(
        openContext: PerpsOpenMarketContext? = nil,
        prepareOpen: Result<PerpsPreparedTradingAction, PerpsTradingError> = .failure(.offline),
        prepareLimitOrder: @escaping @Sendable (PerpsLimitOrderChangeIntent) -> Result<PerpsPreparedLimitOrderChangeAction, PerpsTradingError> = { _ in .failure(.offline) },
        prepareClose: Result<PerpsPreparedCloseAction, PerpsTradingError> = .failure(.offline),
        prepareMargin: Result<PerpsPreparedMarginChangeAction, PerpsTradingError> = .failure(.offline),
        previewClose: Result<PerpsCloseReview, PerpsTradingError> = .failure(.offline),
        previewMargin: Result<PerpsMarginChangeReview, PerpsTradingError> = .failure(.offline),
        onCloseSubmit: @escaping @Sendable (PerpsPreparedCloseAction) -> Void = { _ in },
        onMarginSubmit: @escaping @Sendable (PerpsPreparedMarginChangeAction) -> Void = { _ in },
        prepareSize: @escaping @Sendable (PerpsSizeChangeIntent) -> Result<PerpsPreparedSizeChangeAction, PerpsTradingError> = { _ in .failure(.offline) },
        blockedMarkets: Set<Int64> = [],
        submit: PerpsSubmitResult = .failed(.offline),
        reconciles: [PerpsReconcileResult] = [.confirmed],
        limitSubmits: LimitIntentLog? = nil,
        asksPasscode: Bool = false,
        onWait: @escaping @Sendable (PerpsTradeWait) -> Void = { _ in }
    ) {
        prepareOpenResult = prepareOpen
        prepareLimitOrderResult = prepareLimitOrder
        prepareCloseResult = prepareClose
        prepareMarginResult = prepareMargin
        previewCloseResult = previewClose
        previewMarginResult = previewMargin
        self.onCloseSubmit = onCloseSubmit
        self.onMarginSubmit = onMarginSubmit
        prepareSizeResult = prepareSize
        self.blockedMarkets = blockedMarkets
        submitResult = submit
        self.reconciles = ReconcileScript(reconciles)
        self.limitSubmits = limitSubmits
        self.openContext = openContext
        self.asksPasscode = asksPasscode
        self.onWait = onWait
    }

    func openMarketContext(marketId _: Int64, side _: PerpsTradeSide) async -> PerpsOpenMarketContext? {
        openContext
    }

    func previewOpenMarket(_: PerpsOpenMarketIntent) async -> Result<PerpsOpenOrderReview, PerpsTradingError> {
        .failure(.offline)
    }

    func openSubmission(_ intent: PerpsOpenMarketIntent, review: PerpsOpenOrderReview) -> PerpsPreparedTradingAction {
        (try? prepareOpenResult.get())
            ?? PerpsPreparedTradingAction(operationId: "op", walletId: "wallet", marketId: intent.marketId, intent: intent, review: review)
    }

    func submit(_: PerpsPreparedTradingAction, passcodeProvider _: () async -> String?) async -> PerpsSubmitResult {
        submitResult
    }

    func reconcile(_: PerpsPendingTradingAction) async -> PerpsReconcileResult {
        await reconciles.next()
    }

    func changes(marketId _: Int64) async -> any PerpsChanges {
        IntervalChanges()
    }

    func previewClose(_: PerpsCloseIntent) async -> Result<PerpsCloseReview, PerpsTradingError> {
        previewCloseResult
    }

    func prepareClose(_: PerpsCloseIntent) async -> Result<PerpsPreparedCloseAction, PerpsTradingError> {
        prepareCloseResult
    }

    func submit(_ prepared: PerpsPreparedCloseAction, passcodeProvider: () async -> String?) async -> PerpsSubmitResult {
        onCloseSubmit(prepared)
        if asksPasscode { _ = await passcodeProvider() }
        return submitResult
    }

    func previewSizeChange(_: PerpsSizeChangeIntent) async -> Result<PerpsSizeChangeReview, PerpsTradingError> {
        .failure(.offline)
    }

    func prepareSizeChange(_ intent: PerpsSizeChangeIntent) async -> Result<PerpsPreparedSizeChangeAction, PerpsTradingError> {
        prepareSizeResult(intent)
    }

    func submit(_: PerpsPreparedSizeChangeAction, passcodeProvider _: () async -> String?) async -> PerpsSubmitResult {
        submitResult
    }

    func previewMarginChange(_: PerpsMarginChangeIntent) async -> Result<PerpsMarginChangeReview, PerpsTradingError> {
        previewMarginResult
    }

    func prepareMarginChange(_: PerpsMarginChangeIntent) async -> Result<PerpsPreparedMarginChangeAction, PerpsTradingError> {
        prepareMarginResult
    }

    func submit(_ prepared: PerpsPreparedMarginChangeAction, passcodeProvider _: () async -> String?) async -> PerpsSubmitResult {
        onMarginSubmit(prepared)
        return submitResult
    }

    func prepareAutoCloseChange(_: PerpsAutoCloseChangeIntent) async -> Result<PerpsPreparedAutoCloseChangeAction, PerpsTradingError> {
        .failure(.offline)
    }

    func submit(_: PerpsPreparedAutoCloseChangeAction, passcodeProvider _: () async -> String?) async -> PerpsSubmitResult {
        submitResult
    }

    func prepareLimitOrderChange(_ intent: PerpsLimitOrderChangeIntent) async -> Result<PerpsPreparedLimitOrderChangeAction, PerpsTradingError> {
        prepareLimitOrderResult(intent)
    }

    func submit(_ prepared: PerpsPreparedLimitOrderChangeAction, passcodeProvider _: () async -> String?) async -> PerpsSubmitResult {
        limitSubmits?.append(prepared.intent)
        return submitResult
    }

    func marketsBlockedByPending() async -> Set<Int64> {
        blockedMarkets
    }

    func loadReviewer(for _: PerpsOpenMarketIntent) async -> Result<any PerpetualReviewer, PerpsTradingError> {
        .failure(.offline)
    }

    func loadReviewer(for _: PerpsMarginChangeIntent) async -> Result<any PerpetualReviewer, PerpsTradingError> {
        .failure(.offline)
    }

    func marginChangeLimits(marketId _: Int64) async -> Result<PerpsMarginChangeLimits, PerpsTradingError> {
        .failure(.offline)
    }

    func sizeChangeLimits(marketId _: Int64) async -> Result<PerpsSizeChangeLimits, PerpsTradingError> {
        .failure(.offline)
    }

    func reportWait(_ wait: PerpsTradeWait, milliseconds _: Int64) {
        onWait(wait)
    }
}

private struct IntervalChanges: PerpsChanges {
    func next(orAfter interval: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
    }
}
