import Foundation
import PerpsModels
import TKLocalize
import TKLogging

@MainActor
final class PerpsTradePreparation {
    enum CloseOutcome {
        case prepared(PerpsPreparedCloseAction)
        case slippage
    }

    enum MarginChangeOutcome {
        case prepared(PerpsPreparedMarginChangeAction)
        case closeTrade
        case failed(warning: String?)
    }

    enum SizeChangeOutcome {
        case prepared
        case canceled
        case closeTrade
        case failed(PerpsTradingError)
    }

    enum AutoCloseCheck {
        case valid
        case stale(PerpsAutoCloseValidation.ConfirmStaleKind, remaining: PerpsAutoClose?)
    }

    /// A position action in flight. The attempt is the identity: an answer that
    /// arrives after the user closed the screen — or closed and reopened it — belongs
    /// to an attempt that is no longer current, and is dropped.
    private enum PositionActionFlow<Prepared> {
        final class Attempt {}

        case idle
        case preparing(Attempt)
        case confirming(Attempt, Prepared)

        func isCurrent(_ attempt: Attempt) -> Bool {
            switch self {
            case let .preparing(current), let .confirming(current, _): current === attempt
            case .idle: false
            }
        }
    }

    private struct ChangePrepareFailure {
        let warning: String?
        let shouldCloseTrade: Bool
    }

    var activateAccount: @MainActor (_ onPasscodeEntered: @escaping @MainActor () -> Void) async -> PerpsAccountActivationResult = { _ in .canceled }

    private let tradingService: any PerpsTradingService
    private let accountStore: any PerpsAccountStoring
    private let marketsStore: any PerpsMarketsStoring
    private let tradeRunner: PerpsTradeRunner
    private let format: PerpsFormatting
    private let passcodeProvider: @Sendable () async -> String?
    private let accountActivation = PerpsAccountActivation()

    private var cashOutFlow: PositionActionFlow<PerpsPreparedCloseAction> = .idle
    private var marginChangeFlow: PositionActionFlow<PerpsPreparedMarginChangeAction> = .idle
    private var sizeChangeSession: PerpsSizeChangeSession?
    private var sizeChangePrepareTask: Task<Void, Never>?

    init(context: PerpsFlowContext, passcodeProvider: @escaping @Sendable () async -> String?) {
        tradingService = context.wallet.tradingService
        accountStore = context.wallet.accountStore
        marketsStore = context.dependencies.marketsStore
        tradeRunner = context.tradeRunner
        format = context.format
        self.passcodeProvider = passcodeProvider
        accountStore.addChangeObserver(self) { observer in
            Task { @MainActor in observer.accountDidChange() }
        }
    }

    func ensureAccountReady(onPasscodeEntered: @escaping @MainActor () -> Void) async -> Bool {
        let needsActivation = if case let .active(account) = accountStore.currentWalletState() {
            account.needsActivation
        } else {
            false
        }
        return await accountActivation.ensureReady(needsActivation: needsActivation) { [weak self, accountStore] in
            guard let self else { return false }
            switch await activateAccount(onPasscodeEntered) {
            case .activated:
                accountStore.refresh()
                return true
            case .canceled, .failed:
                return false
            }
        }
    }

    func refreshed(_ screen: PerpsMarketScreenContext) -> PerpsMarketScreenContext {
        screen.with(accountStore.lifecycle(marketId: screen.marketId))
    }

    func prepareOpening(marketId: Int64, onReady: @escaping @MainActor () -> Void) {
        Task { [weak self] in
            guard let self else { return }
            guard await !tradingService.marketsBlockedByPending().contains(marketId) else {
                Log.perps.w("open position refused, unresolved pending on market=\(marketId)")
                tradeRunner.publish(
                    .toast(.failure(PerpsTradingErrorText.message(for: .operationInProgress))),
                    marketId: marketId
                )
                return
            }
            onReady()
        }
    }

    /// Nil for a limit open: its figures are not read again.
    func openReview(for context: PerpsConfirmContext) async -> Result<PerpsOpenOrderReview, PerpsTradingError>? {
        guard context.intent.limitPrice == nil else { return nil }
        return await tradingService.previewOpenMarket(context.replacingAutoClose(nil).intent)
    }

    func checkAutoClose(of context: PerpsConfirmContext, onCheck: @escaping @MainActor (AutoCloseCheck) -> Void) {
        guard let autoClose = context.intent.autoClose, !autoClose.isEmpty else {
            onCheck(.valid)
            return
        }
        Task { [weak self] in
            guard let self else { return }
            let marketPrice = await marketsStore.price(marketId: context.intent.marketId)
            let referencePrice = context.intent.limitPrice
                ?? marketPrice
                ?? context.review.entryPrice
                ?? 0
            var invalid = PerpsAutoCloseValidation.invalidLegs(
                side: context.intent.side,
                referencePrice: referencePrice,
                liquidationPrice: context.review.liquidationPrice,
                autoClose: autoClose
            )
            if invalid.confirmStaleKind == nil,
               case let .failure(.invalidAutoClose(leg?)) = await tradingService.previewOpenMarket(context.intent)
            {
                invalid = await PerpsAutoCloseValidation.refusedLegs(autoClose, refused: leg) { [tradingService] rest in
                    await tradingService.previewOpenMarket(context.replacingAutoClose(rest).intent)
                }
            }
            onCheck(Self.check(autoClose, invalid: invalid))
        }
    }

    func beginSizeChange(
        marketId: Int64,
        direction: PerpsSizeChangeDirection,
        priceDecimals: Int
    ) -> PerpsSizeChangeSession {
        sizeChangePrepareTask?.cancel()
        sizeChangeSession?.finish()
        let session = PerpsSizeChangeSession(
            marketId: marketId,
            direction: direction,
            priceDecimals: priceDecimals,
            restingTriggerOrders: accountStore.marketExtras(marketId: marketId)?.triggerOrders ?? []
        )
        sizeChangeSession = session
        return session
    }

    func isCurrent(_ session: PerpsSizeChangeSession) -> Bool {
        sizeChangeSession === session
    }

    func finishSizeChange(_ session: PerpsSizeChangeSession) {
        guard sizeChangeSession === session else {
            session.finish()
            return
        }
        sizeChangePrepareTask?.cancel()
        sizeChangePrepareTask = nil
        session.finish()
        sizeChangeSession = nil
    }

    func backToEditing(_ session: PerpsSizeChangeSession) -> Bool {
        guard sizeChangeSession === session else { return false }
        sizeChangePrepareTask?.cancel()
        sizeChangePrepareTask = nil
        session.backToEditing()
        return true
    }

    /// One preparation loop for both the first review and a re-review from the confirm
    /// screen: the session owns the state transitions, and this owns cancelling the
    /// previous attempt and refusing an answer that no longer belongs to the screen
    /// the user is looking at.
    func prepareSizeChange(
        _ session: PerpsSizeChangeSession,
        request: PerpsSizeChangeSession.PreparationRequest,
        isOnScreen: @escaping @MainActor () -> Bool,
        onOutcome: @escaping @MainActor (SizeChangeOutcome) -> Void
    ) {
        sizeChangePrepareTask?.cancel()
        sizeChangePrepareTask = Task { [weak self, weak session] in
            guard let self, let session else { return }
            defer {
                if sizeChangeSession === session {
                    sizeChangePrepareTask = nil
                }
            }
            let result = await prepareSigned { await self.tradingService.prepareSizeChange(request.intent) }
            guard !Task.isCancelled, sizeChangeSession === session, isOnScreen() else {
                session.cancelPreparation(request)
                return
            }
            switch result {
            case let .success(prepared):
                guard session.acceptPreparation(prepared, for: request) else { return }
                onOutcome(.prepared)
            case .failure(.activationCanceled):
                if session.cancelPreparation(request), session.phase == .editing {
                    onOutcome(.canceled)
                }
            case let .failure(error):
                let failure = Self.changePrepareFailure(error)
                guard session.failPreparation(request, warning: failure.warning) else { return }
                if failure.shouldCloseTrade {
                    finishSizeChange(session)
                    onOutcome(.closeTrade)
                    tradeRunner.refreshAfterTrade(marketId: request.intent.marketId)
                    if let warning = failure.warning {
                        tradeRunner.publish(.toast(.failure(warning)), marketId: request.intent.marketId)
                    }
                } else {
                    onOutcome(.failed(error))
                }
            }
        }
    }

    func checkRefusedAutoClose(
        of request: PerpsSizeChangeSession.PreparationRequest,
        refused leg: PerpsTriggerOrderSummary.Kind,
        session: PerpsSizeChangeSession,
        onStale: @escaping @MainActor (PerpsAutoCloseValidation.ConfirmStaleKind, PerpsAutoClose?) -> Void
    ) {
        guard case let .replace(autoClose) = request.intent.autoCloseUpdate else { return }
        Task { [weak self] in
            guard let self else { return }
            let invalid = await PerpsAutoCloseValidation.refusedLegs(autoClose, refused: leg) { [tradingService] rest in
                await tradingService.previewSizeChange(request.intent.replacingAutoCloseUpdate(.replace(rest)))
            }
            guard sizeChangeSession === session,
                  case let .stale(kind, remaining) = Self.check(autoClose, invalid: invalid)
            else { return }
            onStale(kind, remaining)
        }
    }

    func checkAutoClose(
        of session: PerpsSizeChangeSession,
        prepared: PerpsPreparedSizeChangeAction,
        onCheck: @escaping @MainActor (AutoCloseCheck) -> Void
    ) {
        guard let autoClose = session.autoCloseForConfirmValidation else {
            onCheck(.valid)
            return
        }
        Task { [weak self] in
            guard let self else { return }
            let referencePrice = await marketsStore.price(marketId: prepared.marketId)
                ?? prepared.review.entryPrice.new
            guard isCurrent(session, operationId: prepared.operationId) else { return }
            var invalid = PerpsAutoCloseValidation.invalidLegs(
                side: prepared.review.side,
                referencePrice: referencePrice,
                liquidationPrice: prepared.review.liquidationPrice?.new,
                autoClose: autoClose
            )
            if invalid.confirmStaleKind == nil,
               case let .failure(.invalidAutoClose(leg?)) = await tradingService.previewSizeChange(prepared.intent)
            {
                invalid = await PerpsAutoCloseValidation.refusedLegs(autoClose, refused: leg) { [tradingService] rest in
                    await tradingService.previewSizeChange(prepared.intent.replacingAutoCloseUpdate(.replace(rest)))
                }
            }
            guard isCurrent(session, operationId: prepared.operationId) else { return }
            onCheck(Self.check(autoClose, invalid: invalid))
        }
    }

    func refreshReview(of session: PerpsSizeChangeSession) async {
        guard sizeChangeSession === session,
              let prepared = session.prepared,
              case let .success(review) = await tradingService.previewSizeChange(
                  prepared.intent.replacingAutoCloseUpdate(.unchanged)
              )
        else { return }
        session.refreshReview(review, operationId: prepared.operationId)
    }

    func submitSizeChange(_ session: PerpsSizeChangeSession, onSlippage: @escaping @MainActor () -> Void) -> Bool {
        guard sizeChangeSession === session,
              let prepared = session.beginSubmitting()
        else { return false }
        tradeRunner.changeSize(
            prepared,
            passcodeProvider: passcodeProvider,
            onSlippage: onSlippage,
            onFinish: { [weak self] in
                session.finish()
                if self?.sizeChangeSession === session {
                    self?.sizeChangeSession = nil
                }
            }
        )
        return true
    }

    /// Returns the inline error text for the sheet; nil closes it (confirmed).
    func changeAutoClose(
        _ screen: PerpsMarketScreenContext,
        target: PerpsAutoClose?,
        isSheetOnScreen: () -> Bool,
        dismissSheet: () -> Void
    ) async -> PerpsAutoCloseSheetViewModel.ApplyResult {
        let marketId = screen.marketId
        let target = target ?? PerpsAutoClose(takeProfit: nil, stopLoss: nil)
        if let summary = refreshed(screen).position,
           let mark = await marketsStore.price(marketId: marketId),
           let warning = PerpsAutoCloseValidation.warning(
               side: summary.side,
               referencePrice: mark,
               liquidationPrice: nil,
               autoClose: target,
               format: format
           )
        {
            return .failed(warning.message)
        }
        let intent = PerpsAutoCloseChangeIntent(marketId: marketId, target: target)
        let prepared: PerpsPreparedAutoCloseChangeAction
        switch await prepareSigned({ await tradingService.prepareAutoCloseChange(intent) }) {
        case let .success(value):
            prepared = value
        case .failure(.activationCanceled):
            return .finished
        case .failure(.nothingToChange):
            accountStore.loadMarketExtras(marketId: marketId)
            dismissSheet()
            return .finished
        case .failure(.positionNotFound), .failure(.orderNotFound):
            dismissSheet()
            tradeRunner.refreshAfterTrade(marketId: marketId)
            return .finished
        case let .failure(error):
            return .failed(PerpsTradingErrorText.message(for: error))
        }

        // Nothing is submitted yet, so a sheet dismissed during prepare is a cancel.
        guard isSheetOnScreen() else { return .finished }
        return await tradeRunner.changeAutoClose(prepared, passcodeProvider: passcodeProvider, onConfirmed: dismissSheet)
    }

    func resetMarginChange() {
        marginChangeFlow = .idle
    }

    func prepareMarginChange(
        _ intent: PerpsMarginChangeIntent,
        isOnScreen: @escaping @MainActor () -> Bool,
        onOutcome: @escaping @MainActor (MarginChangeOutcome) -> Void
    ) {
        guard case .idle = marginChangeFlow else { return }
        let attempt = PositionActionFlow<PerpsPreparedMarginChangeAction>.Attempt()
        marginChangeFlow = .preparing(attempt)
        Task { [weak self] in
            guard let self else { return }
            let result = await prepareSigned { await self.tradingService.prepareMarginChange(intent) }
            guard marginChangeFlow.isCurrent(attempt) else { return }
            switch result {
            case let .success(prepared):
                guard isOnScreen() else {
                    marginChangeFlow = .idle
                    return
                }
                marginChangeFlow = .confirming(attempt, prepared)
                onOutcome(.prepared(prepared))
            case let .failure(error):
                marginChangeFlow = .idle
                let failure = Self.changePrepareFailure(error)
                if failure.shouldCloseTrade {
                    onOutcome(.closeTrade)
                    tradeRunner.refreshAfterTrade(marketId: intent.marketId)
                    if let warning = failure.warning {
                        tradeRunner.publish(.toast(.failure(warning)), marketId: intent.marketId)
                    }
                } else {
                    onOutcome(.failed(warning: failure.warning))
                }
            }
        }
    }

    /// The refreshed figures are also what the submit compares its own plan against.
    func marginChangeReview() async -> PerpsMarginChangeReview? {
        guard case let .confirming(attempt, current) = marginChangeFlow,
              case let .success(review) = await tradingService.previewMarginChange(current.intent),
              marginChangeFlow.isCurrent(attempt),
              case var .confirming(_, prepared) = marginChangeFlow
        else { return nil }
        prepared.review = review
        marginChangeFlow = .confirming(attempt, prepared)
        return review
    }

    func submitMarginChange() -> Bool {
        guard case let .confirming(_, prepared) = marginChangeFlow else { return false }
        marginChangeFlow = .idle
        tradeRunner.changeMargin(prepared, passcodeProvider: passcodeProvider)
        return true
    }

    func prepareClose(
        marketId: Int64,
        isOnScreen: @escaping @MainActor () -> Bool,
        onOutcome: @escaping @MainActor (CloseOutcome) -> Void
    ) {
        guard case .idle = cashOutFlow else { return }
        let attempt = PositionActionFlow<PerpsPreparedCloseAction>.Attempt()
        cashOutFlow = .preparing(attempt)
        Task { [weak self] in
            guard let self else { return }
            let intent = PerpsCloseIntent(marketId: marketId)
            switch await prepareSigned({ await self.tradingService.prepareClose(intent) }) {
            case let .success(prepared):
                // Nothing is submitted yet, so if the user left the asset page while
                // prepare ran, abort instead of presenting the confirm out of context.
                guard cashOutFlow.isCurrent(attempt), isOnScreen() else {
                    cashOutFlow = .idle
                    return
                }
                cashOutFlow = .confirming(attempt, prepared)
                onOutcome(.prepared(prepared))
            case let .failure(error):
                cashOutFlow = .idle
                if case .slippageExceeded = error {
                    onOutcome(.slippage)
                    return
                }
                let message = PerpsTradingErrorText.message(for: error)
                if !message.isEmpty {
                    tradeRunner.publish(.toast(.failure(message)), marketId: marketId)
                }
                if error == .positionNotFound || error == .orderNotFound {
                    tradeRunner.refreshAfterTrade(marketId: marketId)
                }
            }
        }
    }

    /// The refreshed figures are also what the submit compares its own plan against.
    func closeReview() async -> PerpsCloseReview? {
        guard case let .confirming(attempt, current) = cashOutFlow,
              case let .success(review) = await tradingService.previewClose(PerpsCloseIntent(marketId: current.marketId)),
              cashOutFlow.isCurrent(attempt),
              case var .confirming(_, prepared) = cashOutFlow
        else { return nil }
        prepared.review = review
        cashOutFlow = .confirming(attempt, prepared)
        return review
    }

    func cancelClose() -> Bool {
        guard case .confirming = cashOutFlow else { return false }
        cashOutFlow = .idle
        return true
    }

    func submitClose(onSlippage: @escaping @MainActor () -> Void) -> Bool {
        guard case let .confirming(_, prepared) = cashOutFlow else { return false }
        cashOutFlow = .idle
        tradeRunner.close(prepared, passcodeProvider: passcodeProvider, onSlippage: onSlippage)
        return true
    }
}

private extension PerpsTradePreparation {
    func accountDidChange() {
        if case let .active(account) = accountStore.currentWalletState(), !account.needsActivation {
            accountActivation.accountConfirmed()
        }
    }

    func prepareSigned<Prepared>(
        _ prepare: () async -> Result<Prepared, PerpsTradingError>
    ) async -> Result<Prepared, PerpsTradingError> {
        guard await ensureAccountReady(onPasscodeEntered: {}) else { return .failure(.activationCanceled) }
        return await prepare()
    }

    func isCurrent(_ session: PerpsSizeChangeSession, operationId: String) -> Bool {
        sizeChangeSession === session && session.prepared?.operationId == operationId
    }

    static func check(_ autoClose: PerpsAutoClose, invalid: PerpsAutoCloseValidation.InvalidLegs) -> AutoCloseCheck {
        guard let kind = invalid.confirmStaleKind else { return .valid }
        let stripped = PerpsAutoCloseValidation.stripping(autoClose, removing: invalid)
        return .stale(kind, remaining: stripped.isEmpty ? nil : stripped)
    }

    private static func changePrepareFailure(_ error: PerpsTradingError) -> ChangePrepareFailure {
        if case .activationCanceled = error {
            return ChangePrepareFailure(warning: nil, shouldCloseTrade: false)
        }
        let shouldCloseTrade = error == .positionNotFound || error == .orderNotFound
        return ChangePrepareFailure(
            warning: PerpsTradingErrorText.message(for: error, fallback: TKLocales.Perps.Toast.adjustFailed),
            shouldCloseTrade: shouldCloseTrade
        )
    }
}

private extension PerpsSizeChangeIntent {
    func replacingAutoCloseUpdate(_ autoCloseUpdate: PerpsAutoCloseUpdate) -> PerpsSizeChangeIntent {
        PerpsSizeChangeIntent(
            marketId: marketId,
            direction: direction,
            marginDeltaUsd: marginDeltaUsd,
            autoCloseUpdate: autoCloseUpdate,
            takeProfitROIPercent: takeProfitROIPercent,
            stopLossROIPercent: stopLossROIPercent
        )
    }
}
