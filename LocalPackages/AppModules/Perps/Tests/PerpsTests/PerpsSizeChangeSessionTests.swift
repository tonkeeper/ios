@testable import Perps
import PerpsModels
import XCTest

@MainActor
final class PerpsSizeChangeSessionTests: XCTestCase {
    private let resting = PerpsAutoClose(
        takeProfit: PerpsAutoCloseTrigger(triggerPrice: 68000),
        stopLoss: PerpsAutoCloseTrigger(triggerPrice: 64000)
    )
    private let edited = PerpsAutoClose(
        takeProfit: PerpsAutoCloseTrigger(triggerPrice: 70000),
        stopLoss: nil
    )

    func test_followingRestingUpdatesUntilUserSelectsAbsoluteTarget() {
        let session = makeSession(resting: resting)
        session.setAmount("10")

        XCTAssertEqual(session.desiredAutoClose, resting)
        XCTAssertEqual(session.intent.autoCloseUpdate, .unchanged)

        let refreshed = PerpsAutoClose(
            takeProfit: PerpsAutoCloseTrigger(triggerPrice: 69000),
            stopLoss: nil
        )
        session.updateRestingTriggerOrders(triggerOrders(from: refreshed))
        XCTAssertEqual(session.desiredAutoClose, refreshed)
        XCTAssertEqual(session.intent.autoCloseUpdate, .unchanged)

        session.selectAutoClose(nil)
        XCTAssertNil(session.desiredAutoClose)
        XCTAssertEqual(session.intent.autoCloseUpdate, .clear)

        session.updateRestingTriggerOrders(triggerOrders(from: resting))
        XCTAssertNil(session.desiredAutoClose)
        XCTAssertEqual(session.intent.autoCloseUpdate, .clear)
    }

    func test_unchangedPreparationKeepsRestingSnapshotForConfirm() throws {
        let session = makeSession(resting: resting)
        session.setAmount("10")
        let request = try XCTUnwrap(session.beginPreparation())

        let refreshed = PerpsAutoClose(
            takeProfit: PerpsAutoCloseTrigger(triggerPrice: 69000),
            stopLoss: nil
        )
        session.updateRestingTriggerOrders(triggerOrders(from: refreshed))
        XCTAssertTrue(session.acceptPreparation(makePrepared(request: request), for: request))

        XCTAssertEqual(session.prepared?.intent.autoCloseUpdate, .unchanged)
        XCTAssertEqual(session.preparedAutoClose, resting)
        XCTAssertNil(session.autoCloseForConfirmValidation)
        XCTAssertEqual(session.desiredAutoClose, refreshed)
    }

    func test_addSheet_keepsTypedROIAfterMarkAndAmountChange_andPreparesResolvedPrices() throws {
        let session = PerpsSizeChangeSession(
            marketId: 1, direction: .add, priceDecimals: 2, restingTriggerOrders: []
        )
        let initialForm = makeForm(session: session, price: 100)
        initialForm.setAmount("10")
        var context: PerpsAutoCloseSheetContext?
        initialForm.onOpenAutoClose = { context = $0 }
        initialForm.openAutoClose()
        let sheet = try PerpsAutoCloseSheetViewModel(context: XCTUnwrap(context), format: .test)
        sheet.setTakeProfitPercent("10.12")
        sheet.setStopLossPrice("95")
        sheet.onApply = .draft { initialForm.applyAutoClose($0, roiInput: $1) }
        sheet.apply()
        let input = session.autoCloseROIInput
        XCTAssertEqual(input.takeProfit?.text, "10.12")
        let originalPrice = session.desiredAutoClose?.takeProfit?.triggerPrice

        let movedForm = makeForm(session: session, price: 101)
        movedForm.setAmount("20")
        movedForm.onOpenAutoClose = { context = $0 }
        movedForm.openAutoClose()
        let movedContext = try XCTUnwrap(context)
        let reopened = PerpsAutoCloseSheetViewModel(context: movedContext, format: .test)
        XCTAssertEqual(reopened.takeProfitPercentText, "10.12")
        XCTAssertEqual(reopened.stopLossPrice, 95)
        XCTAssertNotEqual(reopened.takeProfitPrice, originalPrice)

        movedForm.resolveAutoClose()
        let request = try XCTUnwrap(session.beginPreparation())
        XCTAssertEqual(request.intent.autoCloseUpdate, try .replace(XCTUnwrap(movedContext.draft)))
        XCTAssertTrue(session.acceptPreparation(makePrepared(request: request), for: request))
        session.backToEditing()
        XCTAssertEqual(session.autoCloseROIInput, input)
    }

    func test_cancelRepreparation_restoresTypedROI_andRemovingALegPrunesItsInput() throws {
        let session = makeSession(resting: nil)
        session.setAmount("10")
        let input = PerpsAutoCloseROIInput(
            takeProfit: PerpsAutoCloseROI(sign: .plus, text: "10"),
            stopLoss: PerpsAutoCloseROI(sign: .minus, text: "20")
        )
        session.selectAutoClose(resting, roiInput: input)
        let initial = try XCTUnwrap(session.beginPreparation())
        XCTAssertTrue(session.acceptPreparation(makePrepared(request: initial), for: initial))
        let replacement = PerpsAutoCloseROIInput(takeProfit: PerpsAutoCloseROI(sign: .plus, text: "30"))
        let request = try XCTUnwrap(session.beginRepreparation(desiredAutoClose: edited, roiInput: replacement))
        XCTAssertEqual(session.autoCloseROIInput, replacement)
        XCTAssertTrue(session.cancelPreparation(request))
        XCTAssertEqual(session.autoCloseROIInput, input)

        session.backToEditing()
        session.selectAutoClose(edited)
        XCTAssertEqual(session.autoCloseROIInput, PerpsAutoCloseROIInput(takeProfit: input.takeProfit))
        session.selectAutoClose(nil)
        XCTAssertEqual(session.autoCloseROIInput, .none)
    }

    func test_initialPreparationAndSubmitAreSingleTransitions() throws {
        let session = makeSession(resting: nil)
        session.setAmount("10")

        let request = try XCTUnwrap(session.beginPreparation())
        XCTAssertEqual(session.phase, .preparing)
        XCTAssertNil(session.beginPreparation())

        let prepared = makePrepared(request: request, operationId: "first")
        XCTAssertTrue(session.acceptPreparation(prepared, for: request))
        XCTAssertEqual(session.phase, .reviewing)
        XCTAssertEqual(session.confirmationState?.isInteractionEnabled, true)

        XCTAssertEqual(session.beginSubmitting()?.operationId, "first")
        XCTAssertEqual(session.phase, .submitting)
        XCTAssertEqual(session.confirmationState?.isInteractionEnabled, false)
        XCTAssertNil(session.beginSubmitting())
    }

    func test_reprepareCancelRestoresPreviousPreparedAndDraft() throws {
        let session = try reviewingSession(resting: resting)
        let previousOperationId = try XCTUnwrap(session.prepared?.operationId)

        let request = try XCTUnwrap(session.beginRepreparation(desiredAutoClose: edited))
        XCTAssertEqual(session.phase, .repreparing)
        XCTAssertEqual(session.confirmationState?.isInteractionEnabled, false)
        XCTAssertEqual(session.desiredAutoClose, edited)
        XCTAssertEqual(session.preparedAutoClose, resting)
        XCTAssertEqual(request.intent.autoCloseUpdate, .replace(edited))

        let refreshed = PerpsAutoClose(
            takeProfit: nil,
            stopLoss: PerpsAutoCloseTrigger(triggerPrice: 63000)
        )
        session.updateRestingTriggerOrders(triggerOrders(from: refreshed))
        XCTAssertTrue(session.cancelPreparation(request))
        XCTAssertEqual(session.phase, .reviewing)
        XCTAssertEqual(session.confirmationState?.isInteractionEnabled, true)
        XCTAssertEqual(session.prepared?.operationId, previousOperationId)
        XCTAssertEqual(session.desiredAutoClose, refreshed)
        XCTAssertEqual(session.preparedAutoClose, resting)
        XCTAssertEqual(session.intent.autoCloseUpdate, .unchanged)
    }

    func test_reprepareFailureReturnsToFormWithCandidateAndWarning() throws {
        let session = try reviewingSession(resting: resting)
        let request = try XCTUnwrap(session.beginRepreparation(desiredAutoClose: edited))

        XCTAssertTrue(session.failPreparation(request, warning: "retry"))
        XCTAssertEqual(session.phase, .editing)
        XCTAssertNil(session.prepared)
        XCTAssertEqual(session.desiredAutoClose, edited)
        XCTAssertEqual(session.intent.autoCloseUpdate, .replace(edited))
        XCTAssertEqual(session.reviewWarningText, "retry")
    }

    func test_backToEditingAbandonsReprepareAndKeepsCandidate() throws {
        let session = try reviewingSession(resting: resting)
        XCTAssertNotNil(session.beginRepreparation(desiredAutoClose: edited))

        session.backToEditing()

        XCTAssertEqual(session.phase, .editing)
        XCTAssertNil(session.prepared)
        XCTAssertNil(session.preparedAutoClose)
        XCTAssertEqual(session.desiredAutoClose, edited)

        let request = try XCTUnwrap(session.beginPreparation())
        XCTAssertEqual(request.intent.autoCloseUpdate, .replace(edited))
    }

    func test_stalePreparationCompletionCannotReplaceCurrentRequest() throws {
        let session = makeSession(resting: nil)
        session.setAmount("10")
        let first = try XCTUnwrap(session.beginPreparation())
        XCTAssertTrue(session.failPreparation(first, warning: nil))

        session.setAmount("11")
        let second = try XCTUnwrap(session.beginPreparation())
        let stalePrepared = makePrepared(request: first, operationId: "stale")
        XCTAssertFalse(session.acceptPreparation(stalePrepared, for: first))
        XCTAssertEqual(session.phase, .preparing)
        XCTAssertNil(session.prepared)

        let currentPrepared = makePrepared(request: second, operationId: "current")
        XCTAssertTrue(session.acceptPreparation(currentPrepared, for: second))
        XCTAssertEqual(session.prepared?.operationId, "current")
    }

    func test_acceptPreparationUsesNormalizedAutoCloseAsAbsoluteTarget() throws {
        let session = makeSession(resting: nil)
        session.setAmount("10")
        session.selectAutoClose(edited)
        let request = try XCTUnwrap(session.beginPreparation())
        let normalized = PerpsAutoClose(
            takeProfit: PerpsAutoCloseTrigger(triggerPrice: 70001),
            stopLoss: nil
        )
        let prepared = PerpsPreparedSizeChangeAction(
            operationId: "normalized",
            walletId: "wallet",
            marketId: 1,
            intent: request.intent,
            review: PerpsSizeChangeReviewFixture.make(direction: .reduce),
            normalizedAutoClose: normalized
        )

        XCTAssertTrue(session.acceptPreparation(prepared, for: request))
        XCTAssertEqual(session.desiredAutoClose, normalized)
        XCTAssertEqual(session.preparedAutoClose, normalized)
        XCTAssertEqual(session.intent.autoCloseUpdate, .replace(normalized))
    }

    func test_currentRequestRejectsPreparedForDifferentIntent() throws {
        let session = makeSession(resting: nil)
        session.setAmount("10")
        let request = try XCTUnwrap(session.beginPreparation())
        let mismatched = PerpsPreparedSizeChangeAction(
            operationId: "mismatched",
            walletId: "wallet",
            marketId: 1,
            intent: PerpsSizeChangeIntent(
                marketId: 1,
                direction: .reduce,
                marginDeltaUsd: "11"
            ),
            review: PerpsSizeChangeReviewFixture.make(direction: .reduce),
            normalizedAutoClose: nil
        )

        XCTAssertFalse(session.acceptPreparation(mismatched, for: request))
        XCTAssertEqual(session.phase, .preparing)
        XCTAssertNil(session.prepared)
    }

    func test_confirmValidationOnlyUsesReplacementFromPreparedIntent() throws {
        let unchanged = try reviewingSession(resting: resting)
        XCTAssertNil(unchanged.autoCloseForConfirmValidation)

        let clearing = makeSession(resting: resting)
        clearing.setAmount("10")
        clearing.selectAutoClose(nil)
        let clearRequest = try XCTUnwrap(clearing.beginPreparation())
        XCTAssertTrue(clearing.acceptPreparation(makePrepared(request: clearRequest), for: clearRequest))
        XCTAssertEqual(clearing.prepared?.intent.autoCloseUpdate, .clear)
        XCTAssertNil(clearing.autoCloseForConfirmValidation)

        let replacing = makeSession(resting: resting)
        replacing.setAmount("10")
        replacing.selectAutoClose(edited)
        let replaceRequest = try XCTUnwrap(replacing.beginPreparation())
        XCTAssertTrue(replacing.acceptPreparation(makePrepared(request: replaceRequest), for: replaceRequest))
        XCTAssertEqual(replacing.prepared?.intent.autoCloseUpdate, .replace(edited))
        XCTAssertEqual(replacing.autoCloseForConfirmValidation, edited)
    }

    func test_refreshReviewSwapsTheFiguresOfTheCurrentOperationOnly() throws {
        let session = try reviewingSession(resting: resting)
        let prepared = try XCTUnwrap(session.prepared)
        let refreshed = PerpsSizeChangeReviewFixture.make(
            direction: .reduce,
            entryPrice: PerpsValueChange(old: 66541.70, new: 67000)
        )

        XCTAssertFalse(session.refreshReview(refreshed, operationId: "other"))
        XCTAssertEqual(session.prepared?.review, prepared.review)

        XCTAssertTrue(session.refreshReview(refreshed, operationId: prepared.operationId))
        XCTAssertEqual(session.phase, .reviewing)
        XCTAssertEqual(session.prepared?.review, refreshed)
        XCTAssertEqual(session.prepared?.operationId, prepared.operationId)
        XCTAssertEqual(session.prepared?.intent, prepared.intent)
        XCTAssertEqual(session.preparedAutoClose, resting)
        XCTAssertEqual(session.confirmationState?.isInteractionEnabled, true)

        XCTAssertNotNil(session.beginRepreparation(desiredAutoClose: edited))
        XCTAssertFalse(session.refreshReview(prepared.review, operationId: prepared.operationId))
        XCTAssertEqual(session.phase, .repreparing)
    }

    func test_confirmingLocksTheReviewUntilCancelled() throws {
        let session = try reviewingSession(resting: resting)
        let viewModel = try XCTUnwrap(PerpsTradeConfirmViewModel(
            sizeChangeSession: session,
            sizeDecimals: 5,
            format: .test
        ))
        viewModel.onConfirm = { _ = session.beginConfirming() }
        viewModel.confirm()
        let prepared = try XCTUnwrap(session.prepared)
        let refreshed = PerpsSizeChangeReviewFixture.make(
            direction: .reduce,
            entryPrice: PerpsValueChange(old: 66541.70, new: 67000)
        )

        XCTAssertEqual(session.phase, .confirming)
        XCTAssertTrue(viewModel.isProcessing)
        XCTAssertEqual(session.confirmationState?.isInteractionEnabled, false)
        XCTAssertNil(session.beginConfirming())
        XCTAssertNil(session.beginRepreparation(desiredAutoClose: edited))
        XCTAssertFalse(session.refreshReview(refreshed, operationId: prepared.operationId))
        XCTAssertEqual(session.prepared?.review, prepared.review)

        session.cancelConfirming()

        XCTAssertEqual(session.phase, .reviewing)
        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertEqual(session.confirmationState?.isInteractionEnabled, true)
        XCTAssertTrue(session.refreshReview(refreshed, operationId: prepared.operationId))
    }

    func test_confirmingEndsInSubmittingOrBackInEditing() throws {
        let submitting = try reviewingSession(resting: resting)
        let prepared = try XCTUnwrap(submitting.beginConfirming())
        XCTAssertEqual(submitting.beginSubmitting()?.operationId, prepared.operationId)
        XCTAssertEqual(submitting.phase, .submitting)
        submitting.cancelConfirming()
        XCTAssertEqual(submitting.phase, .submitting)

        let returning = try reviewingSession(resting: resting)
        XCTAssertNotNil(returning.beginConfirming())
        returning.backToEditing()
        XCTAssertEqual(returning.phase, .editing)
        XCTAssertNil(returning.confirmationState)
    }

    private func reviewingSession(resting: PerpsAutoClose?) throws -> PerpsSizeChangeSession {
        let session = makeSession(resting: resting)
        session.setAmount("10")
        let request = try XCTUnwrap(session.beginPreparation())
        XCTAssertTrue(session.acceptPreparation(makePrepared(request: request), for: request))
        return session
    }

    private func makeSession(resting: PerpsAutoClose?) -> PerpsSizeChangeSession {
        PerpsSizeChangeSession(
            marketId: 1,
            direction: .reduce,
            priceDecimals: 2,
            restingTriggerOrders: triggerOrders(from: resting)
        )
    }

    private func makeForm(session: PerpsSizeChangeSession, price: Double) -> PerpsSizeChangeViewModel {
        PerpsSizeChangeViewModel(
            session: session,
            summary: PerpsPositionSummary(
                positionId: "lighter:1", marketId: 1, symbol: "BTC", side: .long,
                baseSize: 1, notionalUsd: 100, marginUsd: 10, equityUsd: 10,
                leverage: 10, roiPercent: 0, entryPrice: 100, liquidationPrice: 90,
                unrealizedPnlUsd: 0, realizedPnlUsd: 0, fundingPaidUsd: 0,
                liquidationDistancePercent: -10
            ),
            displayPrice: price, sizeDecimals: 6,
            accountStore: StubRootAccountStore(), marketsStore: StubRootMarketsStore(), format: .test
        )
    }

    private func makePrepared(
        request: PerpsSizeChangeSession.PreparationRequest,
        operationId: String = "prepared"
    ) -> PerpsPreparedSizeChangeAction {
        PerpsPreparedSizeChangeAction(
            operationId: operationId,
            walletId: "wallet",
            marketId: 1,
            intent: request.intent,
            review: PerpsSizeChangeReviewFixture.make(direction: .reduce),
            normalizedAutoClose: request.intent.autoCloseUpdate.applying(to: nil)
        )
    }

    private func triggerOrders(from autoClose: PerpsAutoClose?) -> [PerpsTriggerOrderSummary] {
        var orders: [PerpsTriggerOrderSummary] = []
        if let takeProfit = autoClose?.takeProfit {
            orders.append(PerpsTriggerOrderSummary(
                orderIndex: 1,
                kind: .takeProfit,
                side: .short,
                triggerPrice: takeProfit.triggerPrice,
                baseAmount: 0.008
            ))
        }
        if let stopLoss = autoClose?.stopLoss {
            orders.append(PerpsTriggerOrderSummary(
                orderIndex: 2,
                kind: .stopLoss,
                side: .short,
                triggerPrice: stopLoss.triggerPrice,
                baseAmount: 0.008
            ))
        }
        return orders
    }
}
