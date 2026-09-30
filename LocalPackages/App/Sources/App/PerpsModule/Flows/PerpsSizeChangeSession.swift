import Combine
import Foundation
import KeeperCore

@MainActor
final class PerpsSizeChangeSession: ObservableObject {
    enum Phase: Equatable {
        case editing
        case preparing
        case reviewing
        case repreparing
        case submitting
        case finished
    }

    struct ConfirmationState {
        let prepared: PerpsPreparedSizeChangeAction
        let autoClose: PerpsAutoClose?
        let isInteractionEnabled: Bool
    }

    struct PreparationRequest {
        fileprivate let id: UInt
        fileprivate let restingAutoCloseSnapshot: PerpsAutoClose?
        let intent: PerpsSizeChangeIntent
    }

    private enum AutoCloseSelection {
        case followingResting
        case selected(PerpsAutoClose?)
    }

    private struct ReviewSnapshot {
        let confirmation: ConfirmationState
        let selection: AutoCloseSelection
    }

    @Published private(set) var phase: Phase = .editing
    @Published private(set) var amountText = ""
    @Published private(set) var restingTriggerOrders: [PerpsTriggerOrderSummary]
    @Published private(set) var reviewWarningText: String?
    @Published private(set) var confirmationState: ConfirmationState?

    let marketId: Int64
    let direction: PerpsSizeChangeDirection
    let priceDecimals: Int

    @Published private var autoCloseSelection: AutoCloseSelection = .followingResting
    private var requestId: UInt = 0
    private var activeRequestId: UInt?
    private var previousReview: ReviewSnapshot?

    init(
        marketId: Int64,
        direction: PerpsSizeChangeDirection,
        priceDecimals: Int,
        restingTriggerOrders: [PerpsTriggerOrderSummary]
    ) {
        self.marketId = marketId
        self.direction = direction
        self.priceDecimals = priceDecimals
        self.restingTriggerOrders = restingTriggerOrders
    }

    var desiredAutoClose: PerpsAutoClose? {
        switch autoCloseSelection {
        case .followingResting:
            restingAutoClose
        case let .selected(value):
            value
        }
    }

    var preparedAutoClose: PerpsAutoClose? {
        confirmationState?.autoClose
    }

    var prepared: PerpsPreparedSizeChangeAction? {
        confirmationState?.prepared
    }

    var autoCloseForConfirmValidation: PerpsAutoClose? {
        guard let prepared,
              case .replace = prepared.intent.autoCloseUpdate
        else { return nil }
        return preparedAutoClose
    }

    var autoCloseUpdate: PerpsAutoCloseUpdate {
        switch autoCloseSelection {
        case .followingResting:
            .unchanged
        case let .selected(value):
            PerpsAutoCloseUpdate(desired: value, resting: restingAutoClose)
        }
    }

    var intent: PerpsSizeChangeIntent {
        makeIntent()
    }

    func setAmount(_ text: String) {
        guard phase == .editing else { return }
        amountText = PerpsDecimalInput.sanitize(text, decimals: 2)
        reviewWarningText = nil
    }

    func updateRestingTriggerOrders(_ orders: [PerpsTriggerOrderSummary]) {
        guard orders != restingTriggerOrders else { return }
        restingTriggerOrders = orders
    }

    func selectAutoClose(_ value: PerpsAutoClose?) {
        guard phase == .editing else { return }
        setAutoCloseSelection(.selected(Self.normalized(value)))
    }

    func beginPreparation() -> PreparationRequest? {
        guard phase == .editing else { return nil }
        let request = makeRequest(intent: intent)
        phase = .preparing
        confirmationState = nil
        reviewWarningText = nil
        return request
    }

    func beginRepreparation(desiredAutoClose: PerpsAutoClose?) -> PreparationRequest? {
        guard phase == .reviewing, let confirmationState else { return nil }
        previousReview = ReviewSnapshot(
            confirmation: confirmationState,
            selection: autoCloseSelection
        )
        setAutoCloseSelection(.selected(Self.normalized(desiredAutoClose)))
        let request = makeRequest(intent: makeIntent(
            marginDeltaUsd: confirmationState.prepared.intent.marginDeltaUsd
        ))
        self.confirmationState = ConfirmationState(
            prepared: confirmationState.prepared,
            autoClose: confirmationState.autoClose,
            isInteractionEnabled: false
        )
        phase = .repreparing
        reviewWarningText = nil
        return request
    }

    @discardableResult
    func acceptPreparation(
        _ prepared: PerpsPreparedSizeChangeAction,
        for request: PreparationRequest
    ) -> Bool {
        guard activeRequestId == request.id,
              prepared.intent == request.intent,
              phase == .preparing || phase == .repreparing
        else { return false }
        activeRequestId = nil
        previousReview = nil
        if case .replace = prepared.intent.autoCloseUpdate,
           let normalizedAutoClose = prepared.normalizedAutoClose
        {
            setAutoCloseSelection(.selected(Self.normalized(normalizedAutoClose)))
        }
        confirmationState = ConfirmationState(
            prepared: prepared,
            autoClose: Self.preparedAutoClose(
                prepared: prepared,
                restingSnapshot: request.restingAutoCloseSnapshot
            ),
            isInteractionEnabled: true
        )
        phase = .reviewing
        return true
    }

    @discardableResult
    func cancelPreparation(_ request: PreparationRequest) -> Bool {
        guard activeRequestId == request.id else { return false }
        activeRequestId = nil
        switch phase {
        case .preparing:
            confirmationState = nil
            phase = .editing
        case .repreparing:
            guard let previousReview else { return false }
            self.previousReview = nil
            confirmationState = previousReview.confirmation
            setAutoCloseSelection(previousReview.selection)
            phase = .reviewing
        case .editing, .reviewing, .submitting, .finished:
            return false
        }
        return true
    }

    @discardableResult
    func failPreparation(_ request: PreparationRequest, warning: String?) -> Bool {
        guard activeRequestId == request.id,
              phase == .preparing || phase == .repreparing
        else { return false }
        activeRequestId = nil
        previousReview = nil
        confirmationState = nil
        reviewWarningText = warning
        phase = .editing
        return true
    }

    func backToEditing() {
        switch phase {
        case .reviewing:
            break
        case .repreparing:
            activeRequestId = nil
            previousReview = nil
        case .editing, .preparing, .submitting, .finished:
            return
        }
        confirmationState = nil
        phase = .editing
    }

    func beginSubmitting() -> PerpsPreparedSizeChangeAction? {
        guard phase == .reviewing, let confirmationState else { return nil }
        self.confirmationState = ConfirmationState(
            prepared: confirmationState.prepared,
            autoClose: confirmationState.autoClose,
            isInteractionEnabled: false
        )
        phase = .submitting
        return confirmationState.prepared
    }

    func finish() {
        activeRequestId = nil
        previousReview = nil
        confirmationState = nil
        phase = .finished
    }

    private var restingAutoClose: PerpsAutoClose? {
        Self.autoClose(from: restingTriggerOrders)
    }

    private func makeIntent(marginDeltaUsd: String? = nil) -> PerpsSizeChangeIntent {
        PerpsSizeChangeIntent(
            marketId: marketId,
            direction: direction,
            marginDeltaUsd: marginDeltaUsd ?? PerpsDecimalInput.normalized(amountText),
            autoCloseUpdate: autoCloseUpdate
        )
    }

    private func makeRequest(intent: PerpsSizeChangeIntent) -> PreparationRequest {
        requestId &+= 1
        activeRequestId = requestId
        return PreparationRequest(
            id: requestId,
            restingAutoCloseSnapshot: restingAutoClose,
            intent: intent
        )
    }

    private func setAutoCloseSelection(_ selection: AutoCloseSelection) {
        autoCloseSelection = selection
        reviewWarningText = nil
    }

    private static func autoClose(from triggerOrders: [PerpsTriggerOrderSummary]) -> PerpsAutoClose? {
        normalized(PerpsAutoClose(triggerOrders: triggerOrders))
    }

    private static func preparedAutoClose(
        prepared: PerpsPreparedSizeChangeAction,
        restingSnapshot: PerpsAutoClose?
    ) -> PerpsAutoClose? {
        switch prepared.intent.autoCloseUpdate {
        case .unchanged:
            restingSnapshot
        case .clear:
            nil
        case let .replace(requested):
            normalized(prepared.normalizedAutoClose) ?? normalized(requested)
        }
    }

    private static func normalized(_ value: PerpsAutoClose?) -> PerpsAutoClose? {
        value.flatMap { $0.isEmpty ? nil : $0 }
    }
}
