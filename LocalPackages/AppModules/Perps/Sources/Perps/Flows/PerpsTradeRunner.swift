import Foundation
import PerpsModels
import TKLocalize
import TKLogging

@MainActor
final class PerpsTradeRunner {
    enum Outcome: Equatable {
        case toast(PerpsAssetPageTradeToast)
        case dismissToast(PerpsAssetPageTradeToast)
        case reload
        case busy(Bool)
    }

    /// Only a stop for a pending nothing can answer — a send that failed before
    /// its first step was signed journals no order key, and that state would
    /// otherwise poll for the life of the process. About a minute of waiting in all.
    static let reconcileCeiling = 67

    /// A market fill usually lands within a second of the send, so the first
    /// reads come at a quarter of the interval instead of making the user wait
    /// for the next full one.
    static let fastReconcileReads = 8

    static let fullIntervalReconcileCeiling = 61

    private let tradingService: any PerpsTradingService
    private let accountStore: any PerpsAccountStoring
    private let openPositionFlow: PerpsOpenPositionFlow
    private let format: PerpsFormatting
    private let track: (PerpsAnalyticsEvent) -> Void
    private let reconcileIntervalNanos: UInt64
    private var subscribers: [UUID: (marketId: Int64, continuation: AsyncStream<Outcome>.Continuation)] = [:]
    private var unseenToasts: [Int64: PerpsAssetPageTradeToast] = [:]
    var onRegionRestricted: ((_ marketId: Int64) -> Void)?

    /// Auto close and resting-order edits have no designed pending state, so unlike
    /// the other flows they leave the store lifecycle `.open` while their submit
    /// reconciles — this is what keeps one of them from being started twice. Leaving
    /// a position is not held behind it: the service serializes signed actions, and
    /// a refusal there is a toast rather than a button that does nothing.
    private var marketsInFlight: Set<Int64> = [] {
        didSet {
            for marketId in marketsInFlight.symmetricDifference(oldValue) {
                publish(.busy(isBusy(marketId)), marketId: marketId)
            }
        }
    }

    init(
        tradingService: any PerpsTradingService,
        accountStore: any PerpsAccountStoring,
        openPositionFlow: PerpsOpenPositionFlow,
        format: PerpsFormatting,
        track: @escaping (PerpsAnalyticsEvent) -> Void,
        reconcileIntervalNanos: UInt64 = 1_000_000_000
    ) {
        self.tradingService = tradingService
        self.accountStore = accountStore
        self.openPositionFlow = openPositionFlow
        self.format = format
        self.track = track
        self.reconcileIntervalNanos = reconcileIntervalNanos
    }

    func outcomes(marketId: Int64) -> AsyncStream<Outcome> {
        let (stream, continuation) = AsyncStream.makeStream(of: Outcome.self)
        let id = UUID()
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.subscribers[id] = nil
            }
        }
        subscribers[id] = (marketId, continuation)
        if let toast = unseenToasts.removeValue(forKey: marketId) {
            continuation.yield(.toast(toast))
        }
        continuation.yield(.busy(isBusy(marketId)))
        return stream
    }

    func publish(_ outcome: Outcome, marketId: Int64) {
        var delivered = false
        for subscriber in subscribers.values where subscriber.marketId == marketId {
            if case .enqueued = subscriber.continuation.yield(outcome) { delivered = true }
        }
        guard case let .toast(toast) = outcome else { return }
        switch toast {
        case .failure, .unknown: unseenToasts[marketId] = delivered ? nil : toast
        case .progress, .success: unseenToasts[marketId] = nil
        }
    }

    func isBusy(_ marketId: Int64) -> Bool {
        marketsInFlight.contains(marketId)
    }

    func refreshAfterTrade(marketId: Int64) {
        publish(.reload, marketId: marketId)
        accountStore.refresh()
    }

    func open(
        _ context: PerpsConfirmContext,
        ensureAccountReady: @escaping @MainActor (_ onPasscodeEntered: @escaping @MainActor () -> Void) async -> Bool,
        passcodeProvider: @escaping @Sendable () async -> String?,
        onBeginOpening: @escaping @MainActor () -> Void,
        onCanceled: @escaping @MainActor () -> Void,
        onSlippage: @escaping @MainActor () -> Void
    ) {
        let descriptor = openingDescriptor(context: context)
        guard openPositionFlow.beginSubmitting(descriptor) else {
            PerpsOperationLog.event("ui_submit", outcome: "blocked", fields: ["flow": "trade", "action": "open", "market_id": String(context.intent.marketId), "reason": "operation_in_progress"])
            onCanceled()
            return
        }
        let measurement = PerpsWaitMeasurement()
        Task {
            var didBeginOpening = false
            let isReady = await ensureAccountReady {
                didBeginOpening = true
                measurement.begin()
                onBeginOpening()
            }
            guard isReady else {
                PerpsOperationLog.event("ui_submit", outcome: "blocked", source: "wallet", fields: ["flow": "trade", "action": "open", "market_id": String(context.intent.marketId), "reason": "account_not_ready"])
                if didBeginOpening {
                    openPositionFlow.finishSubmitting(marketId: context.intent.marketId)
                } else {
                    openPositionFlow.cancelSubmitting(marketId: context.intent.marketId)
                    onCanceled()
                }
                return
            }
            if !didBeginOpening {
                measurement.begin()
                onBeginOpening()
            }
            defer { openPositionFlow.finishSubmitting(marketId: context.intent.marketId) }
            // The confirm screen already reviewed this open; `submit` plans it once more in the
            // account's lane, so planning here as well only repeated the same reads.
            let prepared = tradingService.openSubmission(context.intent, review: context.review)

            let result = await tradingService.submit(prepared, passcodeProvider: measurement.dirtying(passcodeProvider))
            switch result {
            case let .submitted(pending), let .submitUnknown(pending):
                if pending.hasSentSteps, let order = pending.positionOrderRef {
                    track(.orderSubmitted(descriptor, clientOrderIndex: order.clientOrderIndex))
                }
                await resolveOpeningOverlay(
                    pending: pending,
                    successToast: toastText(verb: toastSuccessVerb(prepared: prepared), prepared: prepared),
                    measurement: measurement,
                    onSlippage: onSlippage
                )
            case let .failed(error):
                showOpenFailure(
                    error,
                    marketId: context.intent.marketId,
                    fallback: TKLocales.Perps.Toast.openFailed,
                    onSlippage: onSlippage
                )
            }
        }
    }

    func close(
        _ prepared: PerpsPreparedCloseAction,
        passcodeProvider: @escaping @Sendable () async -> String?,
        onSlippage: @escaping @MainActor () -> Void,
        onFinish: @escaping @MainActor () -> Void = {}
    ) {
        let measurement = PerpsWaitMeasurement()
        measurement.begin()
        Task {
            defer { onFinish() }
            await settleSubmit(
                marketId: prepared.marketId,
                submitFallback: TKLocales.Perps.Toast.closeFailed,
                reloadExtras: false,
                successToast: closedToastText(review: prepared.review),
                measurement: measurement,
                onSlippage: onSlippage,
                submit: { await self.tradingService.submit(prepared, passcodeProvider: measurement.dirtying(passcodeProvider)) }
            )
        }
    }

    func changeSize(
        _ prepared: PerpsPreparedSizeChangeAction,
        passcodeProvider: @escaping @Sendable () async -> String?,
        onSlippage: @escaping @MainActor () -> Void,
        onFinish: @escaping @MainActor () -> Void
    ) {
        Task {
            defer { onFinish() }
            await settleSubmit(
                marketId: prepared.marketId,
                submitFallback: TKLocales.Perps.Toast.adjustFailed,
                reloadExtras: true,
                successToast: adjustedToastText(review: prepared.review),
                onSlippage: onSlippage,
                showsRegionSheet: prepared.intent.direction == .add,
                submit: { await self.tradingService.submit(prepared, passcodeProvider: passcodeProvider) }
            )
        }
    }

    func changeMargin(
        _ prepared: PerpsPreparedMarginChangeAction,
        passcodeProvider: @escaping @Sendable () async -> String?,
        onFinish: @escaping @MainActor () -> Void = {}
    ) {
        Task {
            defer { onFinish() }
            await settleSubmit(
                marketId: prepared.marketId,
                submitFallback: TKLocales.Perps.Toast.adjustFailed,
                reloadExtras: false,
                successToast: PerpsAssetPageViewModel.marginToastText(
                    direction: prepared.review.direction,
                    amountUsd: prepared.review.amountUsd,
                    isDone: true,
                    format: format
                ),
                submit: { await self.tradingService.submit(prepared, passcodeProvider: passcodeProvider) }
            )
        }
    }

    /// Prepares the change and hands it to `confirm`, which calls `submit` to sign it or drops it.
    /// The `cancellingFirst` legs are cancelled only by `submit`, right before the change is signed.
    func changeLimitOrder(
        _ intent: PerpsLimitOrderChangeIntent,
        cancellingFirst legKeys: [Int64] = [],
        ensureAccountReady: @escaping @MainActor (_ onPasscodeEntered: @escaping @MainActor () -> Void) async -> Bool,
        passcodeProvider: @escaping @Sendable () async -> String?,
        confirm: @escaping @MainActor (_ prepared: PerpsPreparedLimitOrderChangeAction, _ submit: @escaping @MainActor () -> Void) -> Void
    ) {
        let marketId = intent.marketId
        guard marketsInFlight.insert(marketId).inserted else {
            PerpsOperationLog.event("ui_submit", outcome: "blocked", fields: ["flow": "trade", "action": "limit_order_change", "market_id": String(marketId), "reason": "operation_in_progress"])
            return
        }
        Task {
            let prepared = await prepareLimitOrderChange(intent, ensureAccountReady: ensureAccountReady)
            marketsInFlight.remove(marketId)
            guard let prepared else { return }
            confirm(prepared) {
                self.submitLimitOrderChange(prepared, cancellingFirst: legKeys, passcodeProvider: passcodeProvider)
            }
        }
    }

    private func prepareLimitOrderChange(
        _ intent: PerpsLimitOrderChangeIntent,
        ensureAccountReady: @MainActor (_ onPasscodeEntered: @escaping @MainActor () -> Void) async -> Bool
    ) async -> PerpsPreparedLimitOrderChangeAction? {
        let marketId = intent.marketId
        guard await ensureAccountReady({}) else {
            PerpsOperationLog.event("ui_submit", outcome: "blocked", source: "wallet", fields: ["flow": "trade", "action": "limit_order_change", "market_id": String(marketId), "reason": "account_not_ready"])
            return nil
        }
        var reloadExtras = false
        defer {
            if reloadExtras { accountStore.loadMarketExtras(marketId: marketId) }
        }
        switch await tradingService.prepareLimitOrderChange(intent) {
        case let .success(prepared):
            return prepared
        case .failure(.activationCanceled):
            return nil
        case .failure(.nothingToChange):
            reloadExtras = true
            publish(.toast(.success(TKLocales.Actions.done)), marketId: marketId)
            return nil
        case let .failure(error):
            if error == .orderNotFound || error == .orderFilledBeforeCancel {
                reloadExtras = true
            }
            publish(.toast(.failure(PerpsTradingErrorText.message(for: error))), marketId: marketId)
            return nil
        }
    }

    private func submitLimitOrderChange(
        _ prepared: PerpsPreparedLimitOrderChangeAction,
        cancellingFirst legKeys: [Int64],
        passcodeProvider: @escaping @Sendable () async -> String?
    ) {
        let marketId = prepared.marketId
        let intent = prepared.intent
        guard marketsInFlight.insert(marketId).inserted else {
            PerpsOperationLog.event("ui_submit", outcome: "blocked", fields: ["flow": "trade", "action": "limit_order_change", "market_id": String(marketId), "reason": "operation_in_progress"])
            return
        }
        Task {
            defer { marketsInFlight.remove(marketId) }
            var reloadExtras = !legKeys.isEmpty
            defer {
                if reloadExtras { accountStore.loadMarketExtras(marketId: marketId) }
            }
            let progress = PerpsAssetPageTradeToast.progress(
                PerpsAssetPageViewModel.limitOrderChangeToastText(intent.kind, isDone: false)
            )
            for legKey in legKeys {
                guard await cancelLeg(marketId: marketId, legKey: legKey, progress: progress, passcodeProvider: passcodeProvider) else {
                    return
                }
            }
            publish(.toast(progress), marketId: marketId)
            let submit = await tradingService.submit(prepared, passcodeProvider: passcodeProvider)
            let pending: PerpsPendingTradingAction
            switch submit {
            case let .submitted(value), let .submitUnknown(value):
                pending = value
            case .failed(.activationCanceled):
                // The approval passcode was dismissed: nothing is in flight any more.
                publish(.dismissToast(progress), marketId: marketId)
                return
            case let .failed(error):
                reloadExtras = true
                if error == .regionUnavailable, intent.kind == .modify, let onRegionRestricted {
                    publish(.dismissToast(progress), marketId: marketId)
                    onRegionRestricted(marketId)
                } else {
                    publish(.toast(.failure(PerpsTradingErrorText.message(for: error))), marketId: marketId)
                }
                return
            }

            let result = await awaitReconciled(pending)
            reloadExtras = true
            switch result {
            case .confirmed, .partiallyFilled:
                publish(.toast(.success(
                    PerpsAssetPageViewModel.limitOrderChangeToastText(intent.kind, isDone: true)
                )), marketId: marketId)
            case let .failed(error):
                publish(.toast(.failure(PerpsTradingErrorText.message(for: error))), marketId: marketId)
            case .pending:
                publish(.toast(.unknown(TKLocales.Perps.Toast.statusUnknown)), marketId: marketId)
            }
        }
    }

    private func cancelLeg(
        marketId: Int64,
        legKey: Int64,
        progress: PerpsAssetPageTradeToast,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) async -> Bool {
        let prepared: PerpsPreparedLimitOrderChangeAction
        switch await tradingService.prepareLimitOrderChange(.cancel(marketId: marketId, orderIndex: legKey, orderId: "")) {
        case let .success(value):
            prepared = value
        case .failure(.nothingToChange):
            return true
        case .failure(.activationCanceled):
            return false
        case let .failure(error):
            publish(.toast(.failure(PerpsTradingErrorText.message(for: error))), marketId: marketId)
            return false
        }
        publish(.toast(progress), marketId: marketId)
        let pending: PerpsPendingTradingAction
        switch await tradingService.submit(prepared, passcodeProvider: passcodeProvider) {
        case let .submitted(value), let .submitUnknown(value):
            pending = value
        case .failed(.activationCanceled):
            publish(.dismissToast(progress), marketId: marketId)
            return false
        case let .failed(error):
            publish(.toast(.failure(PerpsTradingErrorText.message(for: error))), marketId: marketId)
            return false
        }
        switch await awaitReconciled(pending) {
        case .confirmed, .partiallyFilled:
            return true
        case let .failed(error):
            publish(.toast(.failure(PerpsTradingErrorText.message(for: error))), marketId: marketId)
            return false
        case .pending:
            publish(.toast(.unknown(TKLocales.Perps.Toast.statusUnknown)), marketId: marketId)
            return false
        }
    }

    func changeAutoClose(
        _ prepared: PerpsPreparedAutoCloseChangeAction,
        passcodeProvider: @Sendable () async -> String?,
        onConfirmed: () -> Void
    ) async -> PerpsAutoCloseSheetViewModel.ApplyResult {
        let marketId = prepared.marketId
        guard marketsInFlight.insert(marketId).inserted else {
            PerpsOperationLog.event("ui_submit", outcome: "blocked", fields: ["flow": "trade", "action": "auto_close_change", "market_id": String(marketId), "reason": "operation_in_progress"])
            return .failed(TKLocales.Perps.Toast.adjustFailed)
        }
        defer { marketsInFlight.remove(marketId) }

        switch await tradingService.submit(prepared, passcodeProvider: passcodeProvider) {
        case .failed(.activationCanceled):
            return .finished
        case let .failed(error):
            // A single tx either landed or it didn't, but the venue may have
            // rejected for a reason the page should reflect — reload the orders.
            accountStore.loadMarketExtras(marketId: marketId)
            return .failed(PerpsTradingErrorText.message(for: error, fallback: TKLocales.Perps.Toast.adjustFailed))
        case let .submitted(pending), let .submitUnknown(pending):
            switch await awaitReconciled(pending) {
            case .confirmed, .partiallyFilled:
                accountStore.refresh()
                accountStore.loadMarketExtras(marketId: marketId)
                onConfirmed()
                publish(.reload, marketId: marketId)
                return .finished
            case let .failed(error):
                accountStore.loadMarketExtras(marketId: marketId)
                return .failed(PerpsTradingErrorText.message(for: error, fallback: TKLocales.Perps.Toast.adjustFailed))
            case .pending:
                accountStore.loadMarketExtras(marketId: marketId)
                return .failed(TKLocales.Perps.Toast.statusUnknown)
            }
        }
    }

    func reconcileDelayNanos(afterRead attempt: Int) -> UInt64 {
        attempt < Self.fastReconcileReads ? reconcileIntervalNanos / 4 : reconcileIntervalNanos
    }
}

private extension PerpsTradeRunner {
    func showOpenFailure(
        _ error: PerpsTradingError,
        marketId: Int64,
        fallback: String? = nil,
        onSlippage: @MainActor () -> Void
    ) {
        if case .activationCanceled = error { return }
        if case .slippageExceeded = error {
            onSlippage()
            return
        }
        if error == .regionUnavailable, let onRegionRestricted {
            onRegionRestricted(marketId)
            return
        }
        let message = fallback.map { PerpsTradingErrorText.message(for: error, fallback: $0) }
            ?? PerpsTradingErrorText.message(for: error)
        guard !message.isEmpty else { return }
        publish(.toast(.failure(message)), marketId: marketId)
    }

    func resolveOpeningOverlay(
        pending: PerpsPendingTradingAction,
        successToast: String,
        measurement: PerpsWaitMeasurement,
        onSlippage: (@MainActor () -> Void)? = nil
    ) async {
        // Keep actions hidden until the position or refreshed resting orders arrive.
        let isLimit: Bool
        if case .open(nil) = pending.payload {
            isLimit = false
        } else {
            isLimit = true
        }
        await settleOnPage(
            pending: pending,
            successToast: successToast,
            failureFallback: TKLocales.Perps.Toast.openFailed,
            reloadExtras: isLimit,
            measurement: measurement,
            onSlippage: onSlippage
        )
    }

    /// Polls until tk-perps states an outcome: an order it has not heard about
    /// yet is not a failure, and giving up after a second or two is what used to
    /// report a filled trade as unknown. A cancelled task leaves the pending
    /// journalled for the next launch to finish.
    func awaitReconciled(_ pending: PerpsPendingTradingAction) async -> PerpsReconcileResult {
        let fields = ["flow": "trade", "trace_id": pending.operationId, "operation_id": pending.operationId, "wallet_id": pending.walletId, "market_id": String(pending.marketId)]
        let fillsAtMarket = Self.fillsAtMarket(pending.payload)
        let ceiling = fillsAtMarket ? Self.reconcileCeiling : Self.fullIntervalReconcileCeiling
        let changes = await tradingService.changes(marketId: pending.marketId)
        for attempt in 0 ..< ceiling {
            guard !Task.isCancelled else { break }
            let result = await tradingService.reconcile(pending)
            if case .pending = result {
                if attempt < ceiling - 1 {
                    let delay = fillsAtMarket ? reconcileDelayNanos(afterRead: attempt) : reconcileIntervalNanos
                    await changes.next(orAfter: TimeInterval(delay) / 1_000_000_000)
                }
            } else {
                let outcome: String
                let error: Error?
                switch result {
                case .confirmed: (outcome, error) = ("confirmed", nil)
                case .partiallyFilled: (outcome, error) = ("partially_filled", nil)
                case let .failed(failure): (outcome, error) = ("failed", failure)
                case .pending: (outcome, error) = ("pending", nil)
                }
                PerpsOperationLog.event("ui_settle", outcome: outcome, error: error, fields: fields.merging(["read": String(attempt + 1)]) { _, new in new })
                return result
            }
        }
        PerpsOperationLog.event("ui_settle", outcome: Task.isCancelled ? "cancelled" : "unknown", source: Task.isCancelled ? "user_or_lifecycle" : "unknown", fields: fields.merging(["reason": Task.isCancelled ? "task_cancelled" : "poll_limit_reached"]) { _, new in new })
        return .pending
    }

    static func fillsAtMarket(_ payload: PerpsPendingPayload) -> Bool {
        switch payload {
        case .open(nil), .close: true
        default: false
        }
    }

    static func wait(_ payload: PerpsPendingPayload) -> PerpsTradeWait? {
        switch payload {
        case .open(nil): .positionOpen
        case .close: .positionClose
        default: nil
        }
    }

    /// Submit, then let the page follow the outcome. A refused submission is the
    /// only case that never reaches polling, so it carries its own wording.
    func settleSubmit(
        marketId: Int64,
        submitFallback: String,
        reloadExtras: Bool,
        successToast: String,
        measurement: PerpsWaitMeasurement? = nil,
        onSlippage: (@MainActor () -> Void)? = nil,
        showsRegionSheet: Bool = false,
        submit: () async -> PerpsSubmitResult
    ) async {
        let result = await submit()
        let pending: PerpsPendingTradingAction
        switch result {
        case let .submitted(value), let .submitUnknown(value):
            pending = value
        case let .failed(error):
            if showsRegionSheet, error == .regionUnavailable, let onRegionRestricted {
                onRegionRestricted(marketId)
            } else {
                showSettleFailure(error, marketId: marketId, fallback: submitFallback, onSlippage: onSlippage)
            }
            refreshAfterTrade(marketId: marketId)
            return
        }
        await settleOnPage(
            pending: pending,
            successToast: successToast,
            failureFallback: TKLocales.Perps.Toast.statusUnknown,
            reloadExtras: reloadExtras,
            measurement: measurement,
            onSlippage: onSlippage
        )
    }

    func showSettleFailure(
        _ error: PerpsTradingError,
        marketId: Int64,
        fallback: String,
        onSlippage: (@MainActor () -> Void)?
    ) {
        if case .activationCanceled = error { return }
        if case .slippageExceeded = error, let onSlippage {
            onSlippage()
        } else {
            publish(.toast(.failure(PerpsTradingErrorText.message(for: error, fallback: fallback))), marketId: marketId)
        }
    }

    /// The tail every signed action shares: poll until tk-perps states an outcome,
    /// then put that outcome on the page. Anything but a confirmation drops the
    /// optimistic overlay, since the market is no longer mid-change.
    func settleOnPage(
        pending: PerpsPendingTradingAction,
        successToast: String,
        failureFallback: String,
        reloadExtras: Bool,
        measurement: PerpsWaitMeasurement? = nil,
        onSlippage: (@MainActor () -> Void)? = nil
    ) async {
        let outcome = await awaitReconciled(pending)
        switch outcome {
        case .confirmed, .partiallyFilled:
            let refreshedByTheStore = outcome == .confirmed && Self.wait(pending.payload) == .positionClose
            if !refreshedByTheStore {
                accountStore.refresh()
            }
            if reloadExtras {
                accountStore.loadMarketExtras(marketId: pending.marketId)
            }
            if outcome == .confirmed {
                publish(.toast(.success(successToast)), marketId: pending.marketId)
                if let wait = Self.wait(pending.payload), let milliseconds = measurement?.cleanMilliseconds() {
                    tradingService.reportWait(wait, milliseconds: milliseconds)
                }
            }
            publish(.reload, marketId: pending.marketId)
        case let .failed(error):
            refreshAfterTrade(marketId: pending.marketId)
            showSettleFailure(error, marketId: pending.marketId, fallback: failureFallback, onSlippage: onSlippage)
        case .pending:
            refreshAfterTrade(marketId: pending.marketId)
            publish(.toast(.unknown(TKLocales.Perps.Toast.statusUnknown)), marketId: pending.marketId)
        }
    }

    func toastText(verb: String, prepared: PerpsPreparedTradingAction) -> String {
        let position = PerpsAssetPageViewModel.toastPosition(symbol: prepared.review.symbol, side: prepared.intent.side)
        let margin = format.balance(prepared.review.marginUsd)
        let leverage = format.leverage(prepared.intent.leverage)
        return "\(verb) \(position): \(margin) · \(leverage)"
    }

    func openingDescriptor(context: PerpsConfirmContext) -> PerpsOpeningDescriptor {
        PerpsOpeningDescriptor(
            marketId: context.intent.marketId,
            symbol: context.review.symbol,
            side: context.intent.side,
            marginUsd: context.review.marginUsd,
            leverage: context.intent.leverage,
            isLimit: context.intent.limitPrice != nil,
            liquidationPrice: context.review.liquidationPrice
        )
    }

    func toastSuccessVerb(prepared: PerpsPreparedTradingAction) -> String {
        prepared.intent.limitPrice == nil ? TKLocales.Perps.Toast.opened : TKLocales.Perps.Toast.orderPlaced
    }

    func closedToastText(review: PerpsCloseReview) -> String {
        PerpsAssetPageViewModel.closeToastText(
            verb: TKLocales.Perps.Toast.closed,
            symbol: review.symbol,
            side: review.side,
            leverage: review.leverage,
            format: format
        )
    }

    func adjustedToastText(review: PerpsSizeChangeReview) -> String {
        PerpsAssetPageViewModel.closeToastText(
            verb: review.direction == .add ? TKLocales.Perps.Toast.increased : TKLocales.Perps.Toast.reduced,
            symbol: review.symbol,
            side: review.side,
            leverage: review.leverage,
            format: format
        )
    }
}
