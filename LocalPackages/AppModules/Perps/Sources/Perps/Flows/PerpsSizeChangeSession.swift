import Combine
import Foundation
import PerpsModels

@MainActor
public final class PerpsSizeChangeSession: ObservableObject {
    public enum Phase: Equatable {
        case editing
        case preparing
        case reviewing
        case confirming
        case repreparing
        case submitting
        case finished
    }

    public struct ConfirmationState {
        public let prepared: PerpsPreparedSizeChangeAction
        public let autoClose: PerpsAutoClose?
        public let isInteractionEnabled: Bool
    }

    public struct PreparationRequest {
        fileprivate let id: UInt
        fileprivate let restingAutoCloseSnapshot: PerpsAutoClose?
        public let intent: PerpsSizeChangeIntent
    }

    private enum AutoCloseSelection {
        case followingResting
        case selected(PerpsAutoClose?, PerpsAutoCloseROIInput)
    }

    private struct ReviewSnapshot {
        let confirmation: ConfirmationState
        let selection: AutoCloseSelection
    }

    @Published public private(set) var phase: Phase = .editing
    @Published public private(set) var amountText = ""
    @Published public private(set) var restingTriggerOrders: [PerpsTriggerOrderSummary]
    @Published public private(set) var reviewWarningText: String?
    @Published public private(set) var confirmationState: ConfirmationState?

    public let marketId: Int64
    public let direction: PerpsSizeChangeDirection
    public let priceDecimals: Int

    @Published private var autoCloseSelection: AutoCloseSelection = .followingResting
    private var requestId: UInt = 0
    private var activeRequestId: UInt?
    private var previousReview: ReviewSnapshot?

    public init(
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

    public var desiredAutoClose: PerpsAutoClose? {
        switch autoCloseSelection {
        case .followingResting:
            restingAutoClose
        case let .selected(value, _):
            value
        }
    }

    public var autoCloseROIInput: PerpsAutoCloseROIInput {
        switch autoCloseSelection {
        case .followingResting:
            .none
        case let .selected(_, input):
            input
        }
    }

    public var preparedAutoClose: PerpsAutoClose? {
        confirmationState?.autoClose
    }

    public var prepared: PerpsPreparedSizeChangeAction? {
        confirmationState?.prepared
    }

    public var autoCloseForConfirmValidation: PerpsAutoClose? {
        guard let prepared,
              case .replace = prepared.intent.autoCloseUpdate
        else { return nil }
        return preparedAutoClose
    }

    public var autoCloseUpdate: PerpsAutoCloseUpdate {
        switch autoCloseSelection {
        case .followingResting:
            .unchanged
        case let .selected(value, _):
            PerpsAutoCloseUpdate(desired: value, resting: restingAutoClose)
        }
    }

    public var intent: PerpsSizeChangeIntent {
        makeIntent()
    }

    public func setAmount(_ text: String) {
        guard phase == .editing else { return }
        amountText = PerpsDecimalInput.sanitize(text, decimals: 2)
        reviewWarningText = nil
    }

    public func updateRestingTriggerOrders(_ orders: [PerpsTriggerOrderSummary]) {
        guard orders != restingTriggerOrders else { return }
        restingTriggerOrders = orders
    }

    public func selectAutoClose(_ value: PerpsAutoClose?, roiInput: PerpsAutoCloseROIInput? = nil) {
        guard phase == .editing else { return }
        selectAutoCloseKeepingROI(value, roiInput: roiInput)
    }

    func resolveAutoClose(on base: PerpsAutoCloseBase) {
        guard phase == .editing, case let .selected(value, input) = autoCloseSelection else { return }
        let resolved = input.resolving(value, on: base)
        guard resolved != value else { return }
        selectAutoCloseKeepingROI(resolved)
    }

    public func beginPreparation() -> PreparationRequest? {
        guard phase == .editing else { return nil }
        let request = makeRequest(intent: intent)
        phase = .preparing
        confirmationState = nil
        reviewWarningText = nil
        return request
    }

    public func beginRepreparation(
        desiredAutoClose: PerpsAutoClose?,
        roiInput: PerpsAutoCloseROIInput? = nil
    ) -> PreparationRequest? {
        guard phase == .reviewing, let confirmationState else { return nil }
        previousReview = ReviewSnapshot(
            confirmation: confirmationState,
            selection: autoCloseSelection
        )
        selectAutoCloseKeepingROI(desiredAutoClose, roiInput: roiInput)
        let request = makeRequest(intent: makeIntent(
            marginDeltaUsd: confirmationState.prepared.intent.marginDeltaUsd
        ))
        setInteractionEnabled(false, on: confirmationState)
        phase = .repreparing
        reviewWarningText = nil
        return request
    }

    @discardableResult
    public func acceptPreparation(
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
            selectAutoCloseKeepingROI(normalizedAutoClose)
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
    public func refreshReview(_ review: PerpsSizeChangeReview, operationId: String) -> Bool {
        guard phase == .reviewing,
              let confirmationState,
              confirmationState.prepared.operationId == operationId
        else { return false }
        let prepared = confirmationState.prepared
        self.confirmationState = ConfirmationState(
            prepared: PerpsPreparedSizeChangeAction(
                operationId: prepared.operationId,
                walletId: prepared.walletId,
                marketId: prepared.marketId,
                intent: prepared.intent,
                review: review,
                normalizedAutoClose: prepared.normalizedAutoClose
            ),
            autoClose: confirmationState.autoClose,
            isInteractionEnabled: confirmationState.isInteractionEnabled
        )
        return true
    }

    public func beginConfirming() -> PerpsPreparedSizeChangeAction? {
        guard phase == .reviewing, let confirmationState else { return nil }
        setInteractionEnabled(false, on: confirmationState)
        phase = .confirming
        return confirmationState.prepared
    }

    public func cancelConfirming() {
        guard phase == .confirming, let confirmationState else { return }
        setInteractionEnabled(true, on: confirmationState)
        phase = .reviewing
    }

    @discardableResult
    public func cancelPreparation(_ request: PreparationRequest) -> Bool {
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
        case .editing, .reviewing, .confirming, .submitting, .finished:
            return false
        }
        return true
    }

    @discardableResult
    public func failPreparation(_ request: PreparationRequest, warning: String?) -> Bool {
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

    public func backToEditing() {
        switch phase {
        case .reviewing, .confirming:
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

    public func beginSubmitting() -> PerpsPreparedSizeChangeAction? {
        guard phase == .reviewing || phase == .confirming, let confirmationState else { return nil }
        setInteractionEnabled(false, on: confirmationState)
        phase = .submitting
        return confirmationState.prepared
    }

    public func finish() {
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

    private func setInteractionEnabled(_ isEnabled: Bool, on confirmationState: ConfirmationState) {
        self.confirmationState = ConfirmationState(
            prepared: confirmationState.prepared,
            autoClose: confirmationState.autoClose,
            isInteractionEnabled: isEnabled
        )
    }

    private func setAutoCloseSelection(_ selection: AutoCloseSelection) {
        autoCloseSelection = selection
        reviewWarningText = nil
    }

    private func selectAutoCloseKeepingROI(_ value: PerpsAutoClose?, roiInput: PerpsAutoCloseROIInput? = nil) {
        let value = Self.normalized(value)
        let input = (roiInput ?? autoCloseROIInput).keeping(legsOf: value)
        setAutoCloseSelection(.selected(value, input))
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
