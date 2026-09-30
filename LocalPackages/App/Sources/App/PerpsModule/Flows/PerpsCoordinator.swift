import KeeperCore
import SwiftUI
import TKCoordinator
import TKCore
import TKLocalize
import TKLogging
import TKUIKit
import UIKit

final class PerpsCoordinator: RouterCoordinator<NavigationControllerRouter> {
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let walletScope: PerpsWalletScope
    private let analyticsProvider: AnalyticsProvider?

    init(
        router: NavigationControllerRouter,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        walletScope: PerpsWalletScope,
        analyticsProvider: AnalyticsProvider? = nil
    ) {
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.walletScope = walletScope
        self.analyticsProvider = analyticsProvider
        super.init(router: router)
    }

    private var perpsAssembly: PerpsAssembly {
        keeperCoreMainAssembly.perpsAssembly
    }

    private var tradingService: PerpsTradingService {
        walletScope.tradingService
    }

    private static let fallbackPriceDecimals = 2

    private weak var assetPageViewModel: PerpsAssetPageViewModel?
    private weak var assetPageViewController: UIViewController?
    private var didPushFlowRoot = false
    private var didAttemptAccountBinding = false
    private weak var tradeNavigationController: UINavigationController?
    private weak var shareBottomSheet: TKBottomSheetViewController?
    private var shareRenderTask: Task<Void, Never>?
    private var autoClosePrepareTask: Task<Void, Never>?
    private var autoClosePrepareGeneration: UUID?

    private let openPositionFlow = PerpsOpenPositionFlow()

    /// A position action in flight. The attempt is the identity: an answer that
    /// arrives after the user closed the screen — or closed and reopened it — belongs
    /// to an attempt that is no longer current, and is dropped.
    private enum PositionActionFlow<Prepared> {
        final class Attempt {}

        case idle
        case preparing(Attempt)
        case confirming(Attempt, Prepared)
        case submitting

        func isCurrent(_ attempt: Attempt) -> Bool {
            switch self {
            case let .preparing(current), let .confirming(current, _): current === attempt
            case .idle, .submitting: false
            }
        }
    }

    private var cashOutFlow: PositionActionFlow<PerpsPreparedCloseAction> = .idle
    private var marginChangeFlow: PositionActionFlow<PerpsPreparedMarginChangeAction> = .idle
    private var sizeChangeSession: PerpsSizeChangeSession?
    private var sizeChangePrepareTask: Task<Void, Never>?

    /// Auto close and resting-order edits have no designed pending state, so unlike
    /// the other flows they leave the store lifecycle `.open` while their submit
    /// reconciles — this is what serializes a market's signed actions for that window.
    private var marketsInFlight: Set<Int64> = []

    private func openPositionSummary(marketId: Int64) -> PerpsPositionSummary? {
        guard case let .open(summary) = walletScope.accountStore.lifecycle(marketId: marketId),
              !isMarketBusy(marketId) else { return nil }
        return summary
    }

    private func isMarketBusy(_ marketId: Int64) -> Bool {
        marketsInFlight.contains(marketId)
    }

    override func start() {
        start(marketID: nil)
    }

    func start(marketID: Int64?) {
        observeAccountBinding()
        if let marketID {
            openAssetPage(marketId: marketID)
            return
        }

        let viewModel = PerpsViewModel(
            marketsStore: perpsAssembly.marketsStore,
            accountStore: walletScope.accountStore
        )
        let viewController = PerpsViewController(viewModel: viewModel)

        viewModel.onBack = { [weak viewController] in
            viewController?.navigationController?.popViewController(animated: true)
        }
        viewModel.onLearnBasics = { [weak self] in
            self?.openPlaceholder(title: TKLocales.Perps.learnBasics)
        }
        viewModel.onSearch = { [weak self] in
            self?.openSearch()
        }
        viewModel.onHistory = { [weak self] in
            self?.openPlaceholder(title: TKLocales.Perps.history)
        }
        viewModel.onDeposit = { [weak self] in
            self?.openPlaceholder(title: TKLocales.Perps.deposit)
        }
        viewModel.onWithdraw = { [weak self] in
            self?.openPlaceholder(title: TKLocales.Perps.withdraw)
        }
        viewModel.onSelectMarket = { [weak self] marketId in
            self?.openAssetPage(marketId: marketId)
        }

        pushFlowViewController(viewController)
    }
}

private extension PerpsCoordinator {
    func observeAccountBinding() {
        let accountStore = walletScope.accountStore
        accountStore.addObserver(self) { observer, _ in
            Task { @MainActor in observer.bindAccountIfNeeded() }
        }
        accountStore.resolveIfNeeded()
        Task { @MainActor [weak self] in self?.bindAccountIfNeeded() }
    }

    @MainActor
    func bindAccountIfNeeded() {
        guard !didAttemptAccountBinding,
              case .unbound = walletScope.accountStore.currentWalletState()
        else {
            return
        }
        didAttemptAccountBinding = true
        let accountStore = walletScope.accountStore
        let service = walletScope.accountService
        Task { [weak self] in
            guard let self else { return }
            guard let passcode = await PasscodeInputCoordinator.getPasscode(
                parentCoordinator: self,
                parentRouter: self.router,
                mnemonicAccess: self.keeperCoreMainAssembly.mnemonicAccess,
                securityStore: self.keeperCoreMainAssembly.storesAssembly.securityStore,
                analyticsProvider: self.analyticsProvider
            ) else {
                Log.i("🪵 Perps bind: passcode canceled")
                self.didAttemptAccountBinding = false
                return
            }
            switch await service.bind(wallet: self.walletScope.wallet, passcode: passcode) {
            case let .bound(accountIndex):
                Log.i("🪵 Perps bind: done account=\(String(describing: accountIndex))")
                accountStore.refresh()
            case let .addressMismatch(expected, bound):
                Log.w("🪵 Perps bind: bound to a different address expected=\(expected) bound=\(bound)")
                self.showBindFailureToast()
            case let .takenByAnotherWallet(reason):
                Log.w("🪵 Perps bind: address or account already held elsewhere reason=\(reason)")
                self.showBindFailureToast()
            case let .failed(error):
                Log.w("🪵 Perps bind: failed \(error)")
                self.showBindFailureToast()
            }
        }
    }

    func showBindFailureToast() {
        ToastPresenter.showToast(configuration: .init(title: TKLocales.Perps.Error.generic))
    }

    func openPlaceholder(title: String) {
        let viewController = PerpsPlaceholderViewController(featureTitle: title)
        router.push(viewController: viewController, animated: true)
    }

    func pushFlowViewController(_ viewController: UIViewController) {
        let isRoot = !didPushFlowRoot
        didPushFlowRoot = true
        router.push(
            viewController: viewController,
            animated: true,
            onPopClosures: isRoot ? { [weak self] in
                guard let self else { return }
                self.didFinish?(self)
            } : nil
        )
    }

    func openSearch() {
        let viewModel = PerpsSearchViewModel(
            repository: perpsAssembly.marketsRepository,
            marketsStore: perpsAssembly.marketsStore
        )
        let viewController = PerpsSearchViewController(viewModel: viewModel)
        viewModel.onBack = { [weak viewController] in
            viewController?.navigationController?.popViewController(animated: true)
        }
        viewModel.onSelectMarket = { [weak self] marketId in
            self?.openAssetPage(marketId: marketId)
        }
        router.push(viewController: viewController, animated: true)
    }

    func openTradePlaceholder(title: String) {
        let viewController = PerpsPlaceholderViewController(featureTitle: title)
        tradeNavigationController?.pushViewController(viewController, animated: true)
    }

    func openAssetPage(marketId: Int64) {
        let viewModel = PerpsAssetPageViewModel(
            marketId: marketId,
            store: perpsAssembly.marketsStore,
            marketDetailsStore: perpsAssembly.makeMarketDetailsStore(),
            accountStore: walletScope.accountStore,
            openPositionFlow: openPositionFlow
        )
        let chartViewModel = PerpsChartViewModel(
            marketId: marketId,
            service: keeperCoreMainAssembly.perpsChartService
        )
        let viewController = PerpsAssetPageViewController(viewModel: viewModel, chartViewModel: chartViewModel)

        viewModel.onBack = { [weak viewController] in
            viewController?.navigationController?.popViewController(animated: true)
        }
        viewModel.onMore = { [weak self] in
            self?.openPlaceholder(title: TKLocales.Actions.more)
        }
        viewModel.onPerpetualInfo = { [weak self] in
            self?.openPlaceholder(title: TKLocales.Perps.learnBasics)
        }
        viewModel.onTrade = { [weak self] marketId, side in
            self?.openOpenPosition(marketId: marketId, side: side)
        }
        viewModel.onEdit = { [weak self] marketId, directions in
            self?.openEditPositionSheet(marketId: marketId, directions: directions)
        }
        viewModel.onCashOut = { [weak self] marketId in
            self?.openCashOut(marketId: marketId)
        }
        viewModel.onAdjustMargin = { [weak self] marketId in
            self?.openAdjustMarginSheet(marketId: marketId)
        }
        viewModel.onAutoClose = { [weak self] marketId in
            self?.openPositionAutoClose(marketId: marketId)
        }
        viewModel.onLimitOrder = { [weak self, weak viewController] marketId, order in
            guard let viewController else { return }
            self?.openLimitOrderActions(marketId: marketId, order: order, presenter: viewController)
        }
        viewModel.onShare = { [weak self] snapshot in
            self?.openShareSheet(snapshot)
        }
        viewModel.onSeeAllHistory = { [weak self] _ in
            self?.openPlaceholder(title: TKLocales.Perps.history)
        }

        assetPageViewModel = viewModel
        assetPageViewController = viewController
        pushFlowViewController(viewController)
    }

    // MARK: - Open Position (TK-1572)

    func openOpenPosition(marketId: Int64, side: PerpsTradeSide) {
        if case .composing = openPositionFlow.phase, tradeNavigationController?.presentingViewController == nil {
            Log.w("🪵 Perps: open position flow lost its screen, resetting market=\(marketId)")
            openPositionFlow.close()
        }
        guard openPositionFlow.begin(marketId: marketId) else {
            Log.i("🪵 Perps: open position ignored market=\(marketId) phase=\(openPositionFlow.phase)")
            return
        }
        let viewModel = PerpsOpenPositionViewModel(
            marketId: marketId,
            side: side,
            service: tradingService,
            accountStore: walletScope.accountStore,
            initialLeverage: Self.defaultInitialLeverage
        )
        let navigationController = makeTradeNavigationController(
            rootViewController: PerpsAmountFormViewController(viewModel: viewModel)
        )

        viewModel.onClose = { [weak self] in
            self?.closeOpenPositionFlow()
        }
        viewModel.onLoadFailed = { [weak self, weak navigationController] in
            guard let self, let navigationController, navigationController === tradeNavigationController else { return }
            closeOpenPositionFlow { [weak self] in
                self?.assetPageViewModel?.showTradeResult(.failure(TKLocales.Toast.serviceUnavailable))
            }
        }
        viewModel.onDeposit = { [weak self] in
            self?.openTradePlaceholder(title: TKLocales.Perps.deposit)
        }
        viewModel.onOpenOrderType = { [weak self, weak viewModel] selected in
            self?.openOrderTypeSheet(
                selected: selected,
                onWillPresent: { viewModel?.suppressAmountFocus() },
                onClose: { viewModel?.requestAmountFocus() }
            ) { type in
                switch type {
                case .market:
                    viewModel?.applyOrderType(.market)
                    viewModel?.requestAmountFocus()
                case .limit:
                    viewModel?.openSetLimitPrice()
                }
            }
        }
        viewModel.onOpenSetLimitPrice = { [weak self, weak viewModel] context in
            self?.openSetLimitPrice(context) { price in viewModel?.applyLimitPrice(price) }
        }
        viewModel.onOpenLeverage = { [weak self, weak viewModel] context in
            self?.openLeverageSheet(
                context,
                reviewLiquidation: { leverage in
                    viewModel?.reviewedLiquidation(forLeverage: leverage) ?? nil
                },
                onWillPresent: { viewModel?.suppressAmountFocus() },
                onDismiss: { viewModel?.requestAmountFocus() },
                onApply: { viewModel?.applyLeverage($0) }
            )
        }
        viewModel.onOpenAutoClose = { [weak self, weak viewModel] context in
            self?.openAutoCloseSheet(
                context,
                onWillPresent: { viewModel?.suppressAmountFocus() },
                onDismiss: { viewModel?.requestAmountFocus() },
                onApply: { viewModel?.applyAutoClose($0) }
            )
        }
        viewModel.onReview = { [weak self, weak viewModel] context in
            self?.openConfirm(context: context, openFormViewModel: viewModel)
        }

        present(navigationController)
    }

    func openOrderTypeSheet(
        selected: PerpsOrderType,
        onWillPresent: @escaping () -> Void,
        onClose: @escaping () -> Void,
        onSelect: @escaping (PerpsOrderType) -> Void
    ) {
        let viewModel = PerpsOrderTypeSheetViewModel(selected: selected)
        let bottomSheet = makeSheet(title: TKLocales.Perps.OrderType.title) {
            PerpsOrderTypeSheetView(viewModel: viewModel)
        }
        viewModel.onSelect = { [weak bottomSheet] type in
            guard let bottomSheet else {
                onSelect(type)
                return
            }
            Self.dismissSheet(bottomSheet) { onSelect(type) }
        }
        viewModel.onClose = { [weak bottomSheet] in
            Self.dismissSheet(bottomSheet, completion: onClose)
        }
        bottomSheet.didClose = { _ in onClose() }
        presentSheet(bottomSheet, onWillPresent: onWillPresent)
    }

    func openSetLimitPrice(_ context: PerpsSetLimitPriceContext, onSet: @escaping (Double) -> Void) {
        let viewModel = PerpsSetLimitPriceViewModel(context: context, marketsStore: perpsAssembly.marketsStore)
        let viewController = PerpsSetLimitPriceViewController(viewModel: viewModel)
        viewModel.onBack = { [weak self] in
            self?.tradeNavigationController?.popViewController(animated: true)
        }
        viewModel.onClose = { [weak self] in
            self?.dismissTrade()
        }
        viewModel.onSet = { [weak self] price in
            onSet(price)
            self?.tradeNavigationController?.popViewController(animated: true)
        }
        tradeNavigationController?.pushViewController(viewController, animated: true)
    }

    func openLeverageSheet(
        _ context: PerpsLeverageSheetContext,
        reviewLiquidation: @escaping (Double) -> Double?,
        onWillPresent: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
        onApply: @escaping (Double) -> Void
    ) {
        let viewModel = PerpsLeverageSheetViewModel(context: context, reviewLiquidation: reviewLiquidation)
        let bottomSheet = makeSheet(title: TKLocales.Perps.OpenPosition.leverage) {
            PerpsLeverageSheetView(viewModel: viewModel)
        }
        bottomSheet.didClose = { _ in onDismiss() }
        viewModel.onApply = { [weak bottomSheet] leverage in
            guard let bottomSheet else {
                onApply(leverage)
                onDismiss()
                return
            }
            Self.dismissSheet(bottomSheet) {
                onApply(leverage)
                onDismiss()
            }
        }
        viewModel.onClose = { [weak bottomSheet] in
            Self.dismissSheet(bottomSheet, completion: onDismiss)
        }
        presentSheet(bottomSheet, onWillPresent: onWillPresent)
    }

    func openAutoCloseSheet(
        _ context: PerpsAutoCloseSheetContext,
        onWillPresent: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
        onApply: @escaping (PerpsAutoClose?) -> Void
    ) {
        let viewModel = PerpsAutoCloseSheetViewModel(context: context)
        let subtitle = "\(TKLocales.Perps.OpenPosition.price) \(PerpsFormatting.usd(context.referencePrice))"
        let bottomSheet = makeSheet(title: TKLocales.Perps.OpenPosition.autoCloseTitle, subtitle: subtitle) {
            PerpsAutoCloseSheetView(viewModel: viewModel)
        }
        bottomSheet.keyboardObserver = TKBottomSheetKeyboardObserver(bottomSheet: bottomSheet)
        bottomSheet.didClose = { _ in onDismiss() }
        viewModel.onApply = .draft { [weak bottomSheet] autoClose in
            guard let bottomSheet else {
                onApply(autoClose)
                onDismiss()
                return
            }
            Self.dismissSheet(bottomSheet) {
                onApply(autoClose)
                onDismiss()
            }
        }
        viewModel.onClose = { [weak bottomSheet] in
            Self.dismissSheet(bottomSheet, completion: onDismiss)
        }
        presentSheet(bottomSheet, onWillPresent: onWillPresent)
    }

    func openLiveAutoCloseSheet(
        _ context: PerpsAutoCloseSheetContext,
        marketId: Int64,
        onWillPresent: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
        onApply: @escaping (PerpsAutoClose?) -> Void
    ) {
        guard let session = sizeChangeSession else { return }
        autoClosePrepareTask?.cancel()
        let generation = UUID()
        autoClosePrepareGeneration = generation
        autoClosePrepareTask = Task { @MainActor [weak self, weak session] in
            defer {
                if let self, self.autoClosePrepareGeneration == generation {
                    self.autoClosePrepareTask = nil
                    self.autoClosePrepareGeneration = nil
                }
            }
            guard let self else { return }
            let mark = await perpsAssembly.marketsStore.price(marketId: marketId)
            guard !Task.isCancelled, self.sizeChangeSession === session else { return }
            openAutoCloseSheet(
                mark.map(context.replacingReferencePrice) ?? context,
                onWillPresent: onWillPresent,
                onDismiss: onDismiss,
                onApply: onApply
            )
        }
    }

    // MARK: - Edit Position (TK-1578)

    func openEditPositionSheet(marketId: Int64, directions: Set<PerpsSizeChangeDirection>) {
        guard let summary = openPositionSummary(marketId: marketId) else { return }
        guard directions.count > 1 else {
            guard let direction = directions.first else { return }
            Task { @MainActor in
                await self.openSizeChange(marketId: marketId, direction: direction)
            }
            return
        }
        presentChoiceSheet(
            title: TKLocales.Perps.EditPosition.title,
            content: { choose in
                PerpsEditPositionSheetView(
                    side: summary.side,
                    onAdd: { choose(.add) },
                    onReduce: { choose(.reduce) }
                )
            },
            onChoice: { [weak self] (direction: PerpsSizeChangeDirection) in
                Task { @MainActor in
                    await self?.openSizeChange(marketId: marketId, direction: direction)
                }
            }
        )
    }

    @MainActor
    func openSizeChange(marketId: Int64, direction: PerpsSizeChangeDirection) async {
        let market = await perpsAssembly.marketsStore.snapshot(marketId: marketId)
        guard let summary = openPositionSummary(marketId: marketId) else { return }
        sizeChangePrepareTask?.cancel()
        sizeChangeSession?.finish()
        let lastTradePrice = market.map { $0.price > 0 ? $0.price : 0 } ?? 0
        let session = PerpsSizeChangeSession(
            marketId: marketId,
            direction: direction,
            priceDecimals: market.map(\.priceDecimals) ?? Self.fallbackPriceDecimals,
            restingTriggerOrders: walletScope.accountStore.marketExtras(marketId: marketId)?.triggerOrders ?? []
        )
        sizeChangeSession = session
        let viewModel = PerpsSizeChangeViewModel(
            session: session,
            summary: summary,
            displayPrice: market.flatMap { $0.hasPrice ? $0.price : nil } ?? lastTradePrice,
            sizeDecimals: market.map { Int($0.sizeDecimals) } ?? 2,
            accountStore: walletScope.accountStore
        )
        let navigationController = makeTradeNavigationController(
            rootViewController: PerpsAmountFormViewController(viewModel: viewModel)
        )

        viewModel.onClose = { [weak self] in
            guard let self, sizeChangeSession === session else { return }
            finishSizeChangeSession(session)
            dismissTrade()
        }
        viewModel.onDeposit = { [weak self] in
            self?.openTradePlaceholder(title: TKLocales.Perps.deposit)
        }
        viewModel.onOpenAutoClose = { [weak self, weak viewModel] context in
            self?.openLiveAutoCloseSheet(
                context,
                marketId: marketId,
                onWillPresent: { viewModel?.suppressAmountFocus() },
                onDismiss: { viewModel?.requestAmountFocus() },
                onApply: { viewModel?.applyAutoClose($0) }
            )
        }
        viewModel.onReview = { [weak self, weak viewModel] in
            guard let viewModel else { return }
            self?.reviewSizeChange(session: session, formViewModel: viewModel)
        }

        present(navigationController)
    }

    func reviewSizeChange(
        session: PerpsSizeChangeSession,
        formViewModel: PerpsSizeChangeViewModel
    ) {
        guard sizeChangeSession === session,
              let request = session.beginPreparation()
        else { return }
        prepareSizeChange(session: session, request: request) { [weak formViewModel] navigationController in
            guard let formViewModel else { return }
            await self.pushSizeChangeConfirm(
                session: session,
                in: navigationController,
                formViewModel: formViewModel
            )
        }
    }

    private func reprepareSizeChangeFromConfirm(
        session: PerpsSizeChangeSession,
        desiredAutoClose: PerpsAutoClose?,
        onPrepared: @escaping () -> Void
    ) {
        guard sizeChangeSession === session,
              let request = session.beginRepreparation(desiredAutoClose: desiredAutoClose)
        else { return }
        prepareSizeChange(
            session: session,
            request: request,
            onPrepared: { _ in onPrepared() },
            onFailureKeepingTrade: { navigationController in
                navigationController.popViewController(animated: true)
            }
        )
    }

    /// One preparation loop for both the first review and a re-review from the confirm
    /// screen: the session owns the state transitions, and this owns cancelling the
    /// previous attempt and refusing an answer that no longer belongs to the screen
    /// the user is looking at.
    private func prepareSizeChange(
        session: PerpsSizeChangeSession,
        request: PerpsSizeChangeSession.PreparationRequest,
        onPrepared: @escaping @MainActor (UINavigationController) async -> Void,
        onFailureKeepingTrade: @escaping @MainActor (UINavigationController) -> Void = { _ in }
    ) {
        sizeChangePrepareTask?.cancel()
        sizeChangePrepareTask = Task { @MainActor [weak self, weak session] in
            guard let self, let session else { return }
            defer {
                if sizeChangeSession === session {
                    sizeChangePrepareTask = nil
                }
            }
            let result = await tradingService.prepareSizeChange(request.intent, passcodeProvider: makePasscodeProvider())
            guard !Task.isCancelled,
                  sizeChangeSession === session,
                  let navigationController = tradeNavigationController,
                  navigationController.presentingViewController != nil
            else {
                session.cancelPreparation(request)
                return
            }
            switch result {
            case let .success(prepared):
                guard session.acceptPreparation(prepared, for: request) else { return }
                await onPrepared(navigationController)
            case .failure(.activationCanceled):
                session.cancelPreparation(request)
            case let .failure(error):
                let failure = changePrepareFailure(error)
                guard session.failPreparation(request, warning: failure.warning) else { return }
                if failure.shouldCloseTrade {
                    finishSizeChangeSession(session)
                    dismissTrade()
                    refreshAfterTrade()
                } else {
                    onFailureKeepingTrade(navigationController)
                }
            }
        }
    }

    @MainActor
    func pushSizeChangeConfirm(
        session: PerpsSizeChangeSession,
        in navigationController: UINavigationController,
        formViewModel: PerpsSizeChangeViewModel
    ) async {
        guard let prepared = session.prepared else { return }
        let market = await perpsAssembly.marketsStore.snapshot(marketId: prepared.marketId)
        guard sizeChangeSession === session, session.prepared?.operationId == prepared.operationId else { return }
        guard let viewModel = PerpsTradeConfirmViewModel(
            sizeChangeSession: session,
            sizeDecimals: market.map(\.sizeDecimals) ?? 2,
            iconURL: assetPageViewModel?.state.ready?.iconURL,
            marketsStore: perpsAssembly.marketsStore
        ) else {
            session.backToEditing()
            return
        }
        let viewController = PerpsTradeConfirmViewController(viewModel: viewModel)

        viewModel.onBack = { [weak self] in
            guard let self, sizeChangeSession === session else { return }
            sizeChangePrepareTask?.cancel()
            sizeChangePrepareTask = nil
            session.backToEditing()
            tradeNavigationController?.popViewController(animated: true)
        }
        viewModel.onClose = { [weak self] in
            guard let self, sizeChangeSession === session else { return }
            finishSizeChangeSession(session)
            dismissTrade()
        }
        viewModel.onConfirm = { [weak self, weak formViewModel] in
            Task { @MainActor in
                await self?.handleSizeChangeConfirm(session: session, formViewModel: formViewModel)
            }
        }
        viewModel.onEditAutoClose = { [weak self] in
            Task { @MainActor in
                await self?.editAutoCloseFromSizeChangeConfirm(session: session)
            }
        }
        resignTradeKeyboard()
        navigationController.pushViewController(viewController, animated: true)
    }

    @MainActor
    func editAutoCloseFromSizeChangeConfirm(session: PerpsSizeChangeSession) async {
        guard let prepared = session.prepared,
              session.phase == .reviewing,
              sizeChangeSession === session
        else { return }
        let referencePrice = await perpsAssembly.marketsStore.price(marketId: prepared.marketId)
            ?? prepared.review.entryPrice.new
        guard sizeChangeSession === session, session.prepared?.operationId == prepared.operationId else { return }
        let sheetContext = PerpsAutoCloseSheetContext(
            side: prepared.review.side,
            entryPrice: referencePrice,
            referencePrice: referencePrice,
            leverage: prepared.review.leverage
                ?? openPositionSummary(marketId: prepared.marketId)?.effectiveLeverage
                ?? 0,
            liquidationPrice: prepared.review.liquidationPrice,
            priceDecimals: session.priceDecimals,
            draft: session.preparedAutoClose
        )
        openAutoCloseSheet(
            sheetContext,
            onWillPresent: {},
            onDismiss: {},
            onApply: { [weak self] autoClose in
                guard let self else { return }
                reprepareSizeChangeFromConfirm(
                    session: session,
                    desiredAutoClose: autoClose
                ) {}
            }
        )
    }

    func submitSizeChange(session: PerpsSizeChangeSession) {
        guard sizeChangeSession === session,
              let prepared = session.beginSubmitting()
        else { return }
        walletScope.accountStore.beginAdjusting(
            marketId: prepared.marketId,
            direction: prepared.intent.direction,
            baseSizeBefore: prepared.review.baseSize.old
        )
        dismissTrade()
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                session.finish()
                if self.sizeChangeSession === session {
                    self.sizeChangeSession = nil
                }
            }
            await settleSubmit(
                marketId: prepared.marketId,
                submitFallback: TKLocales.Perps.Toast.adjustFailed,
                reloadExtras: true,
                successToast: adjustedToastText(review: prepared.review),
                submit: { await self.tradingService.submit(prepared) }
            )
        }
    }

    func adjustedToastText(review: PerpsSizeChangeReview) -> String {
        PerpsAssetPageViewModel.closeToastText(
            verb: review.direction == .add ? TKLocales.Perps.Toast.increased : TKLocales.Perps.Toast.reduced,
            symbol: review.symbol,
            side: review.side,
            leverage: review.leverage
        )
    }

    // MARK: - Auto Close on a live position (TK-1580)

    /// The sheet's Set is the confirmation (no confirm screen in design): it
    /// prepares and submits in one go, shows the designed loading state, and
    /// the sheet closes only on a confirmed trigger-order delta.
    func openPositionAutoClose(marketId: Int64) {
        guard openPositionSummary(marketId: marketId) != nil,
              let page = assetPageViewController
        else { return }
        autoClosePrepareTask?.cancel()
        let generation = UUID()
        autoClosePrepareGeneration = generation
        autoClosePrepareTask = Task { @MainActor [weak self, weak page] in
            defer {
                if let self, self.autoClosePrepareGeneration == generation {
                    self.autoClosePrepareTask = nil
                    self.autoClosePrepareGeneration = nil
                }
            }
            guard let self else { return }
            let mark = await perpsAssembly.marketsStore.price(marketId: marketId)
            guard !Task.isCancelled,
                  self.assetPageViewController === page,
                  openPositionSummary(marketId: marketId) != nil
            else { return }
            guard let summary = openPositionSummary(marketId: marketId) else { return }
            // The asset page holds the extras subscription open, so the resting legs
            // behind the prefill are the warm cache the row itself was drawn from.
            let resting = walletScope.accountStore.marketExtras(marketId: marketId)?.triggerOrders ?? []
            let context = PerpsAutoCloseSheetContext(
                side: summary.side,
                entryPrice: summary.entryPrice,
                referencePrice: mark ?? summary.entryPrice,
                leverage: summary.effectiveLeverage ?? 0,
                liquidationPrice: summary.liquidationPrice > 0 ? summary.liquidationPrice : nil,
                priceDecimals: assetPageViewModel?.priceDecimals ?? Self.fallbackPriceDecimals,
                draft: PerpsAutoClose(triggerOrders: resting)
            )
            let viewModel = PerpsAutoCloseSheetViewModel(context: context)
            let subtitle = "\(TKLocales.Perps.OpenPosition.price) \(PerpsFormatting.usd(context.referencePrice))"
            let bottomSheet = makeSheet(title: TKLocales.Perps.OpenPosition.autoCloseTitle, subtitle: subtitle) {
                PerpsAutoCloseSheetView(viewModel: viewModel)
            }
            bottomSheet.keyboardObserver = TKBottomSheetKeyboardObserver(bottomSheet: bottomSheet)
            viewModel.onApply = .submit { [weak self, weak bottomSheet] target in
                guard let self else { return .finished }
                return await submitAutoCloseChange(marketId: marketId, target: target, bottomSheet: bottomSheet)
            }
            viewModel.onClose = { [weak bottomSheet] in
                Self.dismissSheet(bottomSheet, completion: {})
            }
            presentSheet(bottomSheet, onWillPresent: {})
        }
    }

    // MARK: - Resting limit orders

    func openLimitOrderActions(
        marketId: Int64,
        order: PerpsLimitOrderSummary,
        presenter: UIViewController
    ) {
        guard !isMarketBusy(marketId) else { return }
        let alert = UIAlertController(
            title: TKLocales.Perps.OrderType.limit,
            message: "\(TKLocales.Perps.OpenPosition.price) \(PerpsFormatting.usd(order.limitPrice))",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: TKLocales.Actions.edit, style: .default) { [weak self] _ in
            Task { @MainActor in
                await self?.openLimitOrderEditor(marketId: marketId, order: order)
            }
        })
        alert.addAction(UIAlertAction(title: TKLocales.Actions.cancel, style: .destructive) { [weak self] _ in
            self?.submitLimitOrderChange(
                order: order,
                intent: .cancel(marketId: marketId, orderIndex: order.orderIndex)
            )
        })
        alert.addAction(UIAlertAction(title: TKLocales.Actions.done, style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        presenter.present(alert, animated: true)
    }

    @MainActor
    func openLimitOrderEditor(marketId: Int64, order: PerpsLimitOrderSummary) async {
        let market = await perpsAssembly.marketsStore.snapshot(marketId: marketId)
        guard !isMarketBusy(marketId) else { return }
        let referencePrice = market.flatMap { $0.hasPrice ? $0.price : nil } ?? order.limitPrice
        let priceDecimals = market.map(\.priceDecimals) ?? Self.fallbackPriceDecimals
        let side: PerpsTradeSide = order.side == .long ? .long : .short
        let context = PerpsSetLimitPriceContext(
            marketId: marketId,
            side: side,
            priceDecimals: priceDecimals,
            referencePrice: referencePrice,
            initialLimitPrice: order.limitPrice
        )
        let viewModel = PerpsSetLimitPriceViewModel(context: context, marketsStore: perpsAssembly.marketsStore)
        let viewController = PerpsSetLimitPriceViewController(viewModel: viewModel)
        let navigationController = UINavigationController(rootViewController: viewController)
        viewModel.onBack = { [weak navigationController] in
            navigationController?.dismiss(animated: true)
        }
        viewModel.onClose = { [weak navigationController] in
            navigationController?.dismiss(animated: true)
        }
        viewModel.onSet = { [weak self, weak navigationController] price in
            navigationController?.dismiss(animated: true) {
                self?.submitLimitOrderChange(
                    order: order,
                    intent: .modify(
                        marketId: marketId,
                        orderIndex: order.orderIndex,
                        limitPrice: price
                    )
                )
            }
        }
        sheetPresenter.present(navigationController, animated: true)
    }

    func submitLimitOrderChange(
        order: PerpsLimitOrderSummary,
        intent: PerpsLimitOrderChangeIntent
    ) {
        let marketId = intent.marketId
        guard marketsInFlight.insert(marketId).inserted else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.marketsInFlight.remove(marketId) }
            let prepared: PerpsPreparedLimitOrderChangeAction
            switch await tradingService.prepareLimitOrderChange(intent, passcodeProvider: makePasscodeProvider()) {
            case let .success(value):
                prepared = value
            case .failure(.activationCanceled):
                return
            case .failure(.nothingToChange):
                walletScope.accountStore.loadMarketExtras(marketId: marketId)
                assetPageViewModel?.showTradeResult(.success(TKLocales.Actions.done))
                return
            case let .failure(error):
                assetPageViewModel?.showTradeResult(.failure(PerpsTradingErrorText.message(for: error)))
                return
            }

            assetPageViewModel?.showTradeResult(.progress(TKLocales.Perps.Toast.placing))
            let submit = await tradingService.submit(prepared)
            let pending: PerpsPendingTradingAction
            switch submit {
            case let .submitted(value), let .submitUnknown(value):
                pending = value
            case let .failed(error):
                walletScope.accountStore.loadMarketExtras(marketId: marketId)
                assetPageViewModel?.showTradeResult(.failure(PerpsTradingErrorText.message(for: error)))
                return
            }

            let result = await awaitReconciled(pending)
            walletScope.accountStore.loadMarketExtras(marketId: marketId)
            switch result {
            case .confirmed:
                assetPageViewModel?.showTradeResult(.success(TKLocales.Actions.done))
            case let .failed(error):
                assetPageViewModel?.showTradeResult(.failure(PerpsTradingErrorText.message(for: error)))
            case .pending:
                assetPageViewModel?.showTradeResult(.failure(TKLocales.Perps.Toast.statusUnknown))
            }
        }
    }

    /// Returns the inline error text for the sheet; nil closes it (confirmed).
    func submitAutoCloseChange(
        marketId: Int64,
        target: PerpsAutoClose?,
        bottomSheet: TKBottomSheetViewController?
    ) async -> PerpsAutoCloseSheetViewModel.ApplyResult {
        let target = target ?? PerpsAutoClose(takeProfit: nil, stopLoss: nil)
        if let summary = openPositionSummary(marketId: marketId),
           let mark = await perpsAssembly.marketsStore.price(marketId: marketId),
           let warning = PerpsAutoCloseValidation.warning(
               side: summary.side,
               referencePrice: mark,
               liquidationPrice: summary.liquidationPrice > 0 ? summary.liquidationPrice : nil,
               autoClose: target
           )
        {
            return .failed(warning.message)
        }
        let intent = PerpsAutoCloseChangeIntent(marketId: marketId, target: target)
        let prepared: PerpsPreparedAutoCloseChangeAction
        switch await tradingService.prepareAutoCloseChange(intent, passcodeProvider: makePasscodeProvider()) {
        case let .success(value):
            prepared = value
        case .failure(.activationCanceled):
            return .finished
        case .failure(.nothingToChange):
            walletScope.accountStore.loadMarketExtras(marketId: marketId)
            Self.dismissSheet(bottomSheet, completion: {})
            return .finished
        case .failure(.positionNotFound):
            Self.dismissSheet(bottomSheet, completion: {})
            refreshAfterTrade()
            return .finished
        case let .failure(error):
            return .failed(PerpsTradingErrorText.message(for: error))
        }

        // Nothing is submitted yet, so a sheet dismissed during prepare is a cancel.
        guard let bottomSheet, bottomSheet.presentingViewController != nil else { return .finished }
        guard marketsInFlight.insert(marketId).inserted else {
            return .failed(TKLocales.Perps.Toast.adjustFailed)
        }
        defer { marketsInFlight.remove(marketId) }

        switch await tradingService.submit(prepared) {
        case let .failed(error):
            // A single tx either landed or it didn't, but the venue may have
            // rejected for a reason the page should reflect — reload the orders.
            walletScope.accountStore.loadMarketExtras(marketId: marketId)
            return .failed(PerpsTradingErrorText.message(for: error, fallback: TKLocales.Perps.Toast.adjustFailed))
        case let .submitted(pending), let .submitUnknown(pending):
            switch await awaitReconciled(pending) {
            case .confirmed:
                walletScope.accountStore.loadMarketExtras(marketId: marketId)
                Self.dismissSheet(bottomSheet, completion: {})
                assetPageViewModel?.retry()
                return .finished
            case let .failed(error):
                walletScope.accountStore.loadMarketExtras(marketId: marketId)
                return .failed(PerpsTradingErrorText.message(for: error, fallback: TKLocales.Perps.Toast.adjustFailed))
            case .pending:
                walletScope.accountStore.loadMarketExtras(marketId: marketId)
                return .failed(TKLocales.Perps.Toast.statusUnknown)
            }
        }
    }

    // MARK: - Adjust Margin (TK-1579)

    func openAdjustMarginSheet(marketId: Int64) {
        guard openPositionSummary(marketId: marketId) != nil else { return }
        let flags = walletScope.accountStore.marketExtras(marketId: marketId)?.flags
        let canAdd = flags?.addMarginEnabled ?? false
        let canReduce = flags?.removeMarginEnabled ?? false
        guard canAdd, canReduce else {
            guard canAdd || canReduce else { return }
            Task { @MainActor in
                await self.openMarginChange(marketId: marketId, direction: canAdd ? .add : .reduce)
            }
            return
        }
        presentChoiceSheet(
            title: TKLocales.Perps.AdjustMargin.title,
            content: { choose in
                PerpsAdjustMarginSheetView(
                    onAdd: { choose(.add) },
                    onReduce: { choose(.reduce) }
                )
            },
            onChoice: { [weak self] (direction: PerpsMarginChangeDirection) in
                Task { @MainActor in
                    await self?.openMarginChange(marketId: marketId, direction: direction)
                }
            }
        )
    }

    @MainActor
    func openMarginChange(marketId: Int64, direction: PerpsMarginChangeDirection) async {
        let market = await perpsAssembly.marketsStore.snapshot(marketId: marketId)
        guard let summary = openPositionSummary(marketId: marketId) else { return }
        marginChangeFlow = .idle
        let lastTradePrice = market.map { $0.price > 0 ? $0.price : 0 } ?? 0
        let viewModel = PerpsMarginChangeViewModel(
            direction: direction,
            summary: summary,
            displayPrice: market.flatMap { $0.hasPrice ? $0.price : nil } ?? lastTradePrice,
            accountStore: walletScope.accountStore,
            tradingService: tradingService
        )
        let navigationController = makeTradeNavigationController(
            rootViewController: PerpsAmountFormViewController(viewModel: viewModel)
        )

        viewModel.onClose = { [weak self] in
            self?.marginChangeFlow = .idle
            self?.dismissTrade()
        }
        viewModel.onDeposit = { [weak self] in
            self?.openTradePlaceholder(title: TKLocales.Perps.deposit)
        }
        viewModel.onReview = { [weak self, weak viewModel] intent in
            self?.reviewMarginChange(intent: intent, formViewModel: viewModel)
        }

        present(navigationController)
    }

    func reviewMarginChange(intent: PerpsMarginChangeIntent, formViewModel: PerpsMarginChangeViewModel?) {
        guard case .idle = marginChangeFlow else { return }
        let attempt = PositionActionFlow<PerpsPreparedMarginChangeAction>.Attempt()
        marginChangeFlow = .preparing(attempt)
        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await tradingService.prepareMarginChange(intent, passcodeProvider: makePasscodeProvider())
            guard marginChangeFlow.isCurrent(attempt) else { return }
            switch result {
            case let .success(prepared):
                guard let tradeNavigationController, tradeNavigationController.presentingViewController != nil else {
                    marginChangeFlow = .idle
                    return
                }
                marginChangeFlow = .confirming(attempt, prepared)
                pushMarginChangeConfirm(prepared, in: tradeNavigationController)
            case let .failure(error):
                marginChangeFlow = .idle
                let failure = changePrepareFailure(error)
                if let warning = failure.warning {
                    formViewModel?.setReviewWarning(warning)
                }
                if failure.shouldCloseTrade {
                    dismissTrade()
                    refreshAfterTrade()
                }
            }
        }
    }

    private struct ChangePrepareFailure {
        let warning: String?
        let shouldCloseTrade: Bool
    }

    private func changePrepareFailure(_ error: PerpsTradingError) -> ChangePrepareFailure {
        if case .activationCanceled = error {
            return ChangePrepareFailure(warning: nil, shouldCloseTrade: false)
        }
        let shouldCloseTrade: Bool
        if case .positionNotFound = error {
            shouldCloseTrade = true
        } else {
            shouldCloseTrade = false
        }
        return ChangePrepareFailure(
            warning: PerpsTradingErrorText.message(for: error, fallback: TKLocales.Perps.Toast.adjustFailed),
            shouldCloseTrade: shouldCloseTrade
        )
    }

    func pushMarginChangeConfirm(_ prepared: PerpsPreparedMarginChangeAction, in navigationController: UINavigationController) {
        let viewModel = PerpsTradeConfirmViewModel(
            marginChangeContext: PerpsMarginChangeConfirmContext(review: prepared.review),
            iconURL: assetPageViewModel?.state.ready?.iconURL
        )
        let viewController = PerpsTradeConfirmViewController(viewModel: viewModel)

        viewModel.onBack = { [weak self] in
            self?.marginChangeFlow = .idle
            self?.tradeNavigationController?.popViewController(animated: true)
        }
        viewModel.onClose = { [weak self] in
            self?.marginChangeFlow = .idle
            self?.dismissTrade()
        }
        viewModel.onConfirm = { [weak self] in
            self?.submitMarginChange()
        }
        resignTradeKeyboard()
        navigationController.pushViewController(viewController, animated: true)
    }

    func submitMarginChange() {
        guard case let .confirming(_, prepared) = marginChangeFlow else { return }
        marginChangeFlow = .submitting
        walletScope.accountStore.beginAdjustingMargin(
            marketId: prepared.marketId,
            direction: prepared.intent.direction,
            allocatedMarginBefore: prepared.review.allocatedMargin.old,
            amountUsd: prepared.review.amountUsd
        )
        dismissTrade()
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.marginChangeFlow = .idle }
            await settleSubmit(
                marketId: prepared.marketId,
                submitFallback: TKLocales.Perps.Toast.adjustFailed,
                reloadExtras: false,
                successToast: PerpsAssetPageViewModel.marginToastText(
                    direction: prepared.review.direction,
                    amountUsd: prepared.review.amountUsd,
                    isDone: true
                ),
                submit: { await self.tradingService.submit(prepared) }
            )
        }
    }

    // MARK: - Share Position

    func openShareSheet(_ snapshot: SharePositionSnapshot) {
        let presenter = sheetPresenter
        guard presenter.presentedViewController == nil else { return }
        let model = PerpsSharePositionPresenter.model(from: snapshot)
        let bottomSheet = makeSheet(title: TKLocales.Perps.Asset.sharePosition) {
            PerpsSharePositionView(model: model) { [weak self] in
                self?.presentSystemShare(model)
            }
        }
        shareBottomSheet = bottomSheet
        presentSheet(bottomSheet, onWillPresent: {})
    }

    private func presentSystemShare(_ model: PerpsSharePositionCardModel) {
        let presenter = shareBottomSheet ?? sheetPresenter
        guard presenter.presentedViewController == nil, shareRenderTask == nil else { return }
        shareRenderTask = Task { @MainActor [weak self, weak presenter] in
            defer { self?.shareRenderTask = nil }
            guard let presenter else { return }
            let image = await PerpsSharePositionRenderer.image(model: model, fittingIn: presenter.view)
            guard presenter.presentedViewController == nil, presenter.view.window != nil, !presenter.isBeingDismissed else { return }
            self?.presentSystemShare(image: image, from: presenter)
        }
    }

    private func presentSystemShare(image: UIImage?, from presenter: UIViewController) {
        guard let image else {
            ToastPresenter.showToast(configuration: .init(title: TKLocales.Perps.Toast.shareFailed))
            return
        }
        let activityViewController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        // Without a source rect UIKit raises on iPad.
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        presenter.present(activityViewController, animated: true)
    }

    /// A sheet whose choices each dismiss it and then act, so the dismissal and the
    /// weak reference it needs are written once.
    func presentChoiceSheet<Choice>(
        title: String,
        content: (_ choose: @escaping (Choice) -> Void) -> some View,
        onChoice: @escaping (Choice) -> Void
    ) {
        weak var sheet: TKBottomSheetViewController?
        let bottomSheet = makeSheet(title: title) {
            content { choice in
                Self.dismissSheet(sheet) { onChoice(choice) }
            }
        }
        sheet = bottomSheet
        presentSheet(bottomSheet, onWillPresent: {})
    }

    /// The full-screen container every trade form and confirm is presented in, and
    /// the one place `tradeNavigationController` is set.
    func makeTradeNavigationController(rootViewController: UIViewController) -> TKNavigationController {
        let navigationController = TKNavigationController(rootViewController: rootViewController)
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.modalPresentationStyle = .fullScreen
        tradeNavigationController = navigationController
        return navigationController
    }

    func makeSheet(title: String, subtitle: String? = nil, @ViewBuilder content: () -> some View) -> TKBottomSheetViewController {
        let contentViewController = PerpsBottomSheetScrollContentViewController(title: title, subtitle: subtitle, content: content)
        return TKBottomSheetViewController(contentViewController: contentViewController)
    }

    func openConfirm(context: PerpsConfirmContext, openFormViewModel: PerpsOpenPositionViewModel?) {
        resignTradeKeyboard()
        let viewModel = PerpsTradeConfirmViewModel(
            context: context,
            iconURL: assetPageViewModel?.state.ready?.iconURL,
            marketsStore: perpsAssembly.marketsStore
        )
        let viewController = PerpsTradeConfirmViewController(viewModel: viewModel)

        viewModel.onBack = { [weak self] in
            self?.tradeNavigationController?.popViewController(animated: true)
        }
        viewModel.onClose = { [weak self] in
            self?.closeOpenPositionFlow()
        }
        viewModel.onConfirm = { [weak self, weak viewModel, weak openFormViewModel] in
            guard let viewModel, let context = viewModel.openConfirmContext else { return }
            Task { @MainActor in
                await self?.handleOpenConfirm(context: context, openFormViewModel: openFormViewModel, viewModel: viewModel)
            }
        }
        viewModel.onEditAutoClose = { [weak self, weak viewModel, weak openFormViewModel] in
            Task { @MainActor in
                await self?.editAutoCloseFromOpenConfirm(
                    viewModel: viewModel,
                    openFormViewModel: openFormViewModel
                )
            }
        }
        tradeNavigationController?.pushViewController(viewController, animated: true)
    }

    @MainActor
    func editAutoCloseFromOpenConfirm(
        viewModel: PerpsTradeConfirmViewModel?,
        openFormViewModel: PerpsOpenPositionViewModel?
    ) async {
        guard let viewModel,
              let context = viewModel.openConfirmContext
        else { return }
        let marketPrice = await perpsAssembly.marketsStore.price(marketId: context.intent.marketId)
        let referencePrice = context.intent.limitPrice
            ?? marketPrice
            ?? context.review.entryPrice
            ?? 0
        let sheetContext = PerpsAutoCloseSheetContext(
            side: context.intent.side,
            entryPrice: referencePrice,
            referencePrice: referencePrice,
            leverage: context.intent.leverage,
            liquidationPrice: context.review.liquidationPrice,
            priceDecimals: context.priceDecimals,
            draft: context.intent.autoClose
        )
        openAutoCloseSheet(
            sheetContext,
            onWillPresent: {},
            onDismiss: {},
            onApply: { [weak viewModel, weak openFormViewModel] autoClose in
                openFormViewModel?.applyAutoClose(autoClose)
                viewModel?.updateOpenAutoClose(autoClose)
            }
        )
    }

    @MainActor
    func handleOpenConfirm(
        context: PerpsConfirmContext,
        openFormViewModel: PerpsOpenPositionViewModel?,
        viewModel: PerpsTradeConfirmViewModel
    ) async {
        guard let autoClose = context.intent.autoClose, !autoClose.isEmpty else {
            submit(context: context, confirmationViewModel: viewModel)
            return
        }
        let marketPrice = await perpsAssembly.marketsStore.price(marketId: context.intent.marketId)
        let referencePrice = context.intent.limitPrice
            ?? marketPrice
            ?? context.review.entryPrice
            ?? 0
        let invalid = PerpsAutoCloseValidation.invalidLegs(
            side: context.intent.side,
            referencePrice: referencePrice,
            liquidationPrice: context.review.liquidationPrice,
            autoClose: autoClose
        )
        guard let kind = invalid.confirmStaleKind else {
            submit(context: context, confirmationViewModel: viewModel)
            return
        }
        presentAutoCloseStaleAlert(
            kind: kind,
            onContinueWithout: { [weak self, weak openFormViewModel, weak viewModel] in
                let stripped = PerpsAutoCloseValidation.stripping(autoClose, removing: invalid)
                openFormViewModel?.applyAutoClose(stripped.isEmpty ? nil : stripped)
                self?.submit(
                    context: context.replacingAutoClose(stripped.isEmpty ? nil : stripped),
                    confirmationViewModel: viewModel
                )
            },
            onUpdate: { [weak self, weak openFormViewModel, weak viewModel] in
                viewModel?.restoreConfirmation()
                self?.tradeNavigationController?.popViewController(animated: true)
                openFormViewModel?.openAutoClose()
            },
            onClose: { [weak viewModel] in viewModel?.restoreConfirmation() }
        )
    }

    @MainActor
    func handleSizeChangeConfirm(
        session: PerpsSizeChangeSession,
        formViewModel: PerpsSizeChangeViewModel?
    ) async {
        guard sizeChangeSession === session,
              session.phase == .reviewing,
              let prepared = session.prepared
        else { return }
        guard let autoClose = session.autoCloseForConfirmValidation else {
            submitSizeChange(session: session)
            return
        }
        let referencePrice = await perpsAssembly.marketsStore.price(marketId: prepared.marketId)
            ?? prepared.review.entryPrice.new
        guard sizeChangeSession === session, session.prepared?.operationId == prepared.operationId else { return }
        let invalid = PerpsAutoCloseValidation.invalidLegs(
            side: prepared.review.side,
            referencePrice: referencePrice,
            liquidationPrice: prepared.review.liquidationPrice,
            autoClose: autoClose
        )
        guard let kind = invalid.confirmStaleKind else {
            submitSizeChange(session: session)
            return
        }
        presentAutoCloseStaleAlert(
            kind: kind,
            onContinueWithout: { [weak self] in
                guard let self else { return }
                let stripped = PerpsAutoCloseValidation.stripping(autoClose, removing: invalid)
                reprepareSizeChangeFromConfirm(
                    session: session,
                    desiredAutoClose: stripped
                ) { [weak self] in
                    self?.submitSizeChange(session: session)
                }
            },
            onUpdate: { [weak self, weak formViewModel] in
                guard let self, sizeChangeSession === session else { return }
                sizeChangePrepareTask?.cancel()
                sizeChangePrepareTask = nil
                session.backToEditing()
                tradeNavigationController?.popViewController(animated: true)
                formViewModel?.openAutoClose()
            }
        )
    }

    func finishSizeChangeSession(_ session: PerpsSizeChangeSession) {
        guard sizeChangeSession === session else {
            session.finish()
            return
        }
        sizeChangePrepareTask?.cancel()
        sizeChangePrepareTask = nil
        autoClosePrepareTask?.cancel()
        autoClosePrepareTask = nil
        autoClosePrepareGeneration = nil
        session.finish()
        sizeChangeSession = nil
    }

    func presentAutoCloseStaleAlert(
        kind: PerpsAutoCloseValidation.ConfirmStaleKind,
        onContinueWithout: @escaping () -> Void,
        onUpdate: @escaping () -> Void,
        onClose: (() -> Void)? = nil
    ) {
        let copy = Self.autoCloseStaleCopy(kind: kind)
        var continueButton = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
        continueButton.content = TKButton.Configuration.Content(title: .plainString(copy.continueTitle))
        var updateButton = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
        updateButton.content = TKButton.Configuration.Content(title: .plainString(copy.updateTitle))

        let viewController = InfoPopupBottomSheetViewController()
        let bottomSheet = TKBottomSheetViewController(contentViewController: viewController)
        var actionHandled = false
        bottomSheet.didClose = { _ in
            if !actionHandled { onClose?() }
        }
        continueButton.action = { [weak bottomSheet] in
            actionHandled = true
            bottomSheet?.dismiss {
                onContinueWithout()
            }
        }
        updateButton.action = { [weak bottomSheet] in
            actionHandled = true
            bottomSheet?.dismiss {
                onUpdate()
            }
        }
        viewController.configuration = InfoPopupBottomSheetViewController.Configuration(
            image: .TKUIKit.Icons.Size84.exclamationmarkCircle,
            imageTintColor: .Icon.secondary,
            title: copy.title,
            caption: copy.caption,
            bodyContent: nil,
            buttons: [continueButton, updateButton]
        )
        viewController.headerConfiguration = TKBottomSheetHeaderConfiguration(
            title: .empty,
            contentInsets: UIEdgeInsets(top: 16, left: 16, bottom: 0, right: 16)
        )
        bottomSheet.present(fromViewController: sheetPresenter)
    }

    static func autoCloseStaleCopy(kind: PerpsAutoCloseValidation.ConfirmStaleKind) -> (
        title: String,
        caption: String,
        continueTitle: String,
        updateTitle: String
    ) {
        switch kind {
        case .takeProfit:
            return (
                TKLocales.Perps.Confirm.takeProfitNeedsUpdateTitle,
                TKLocales.Perps.Confirm.takeProfitNeedsUpdateCaption,
                TKLocales.Perps.Confirm.continueWithoutTakeProfit,
                TKLocales.Perps.Confirm.updateTakeProfit
            )
        case .stopLoss:
            return (
                TKLocales.Perps.Confirm.stopLossNeedsUpdateTitle,
                TKLocales.Perps.Confirm.stopLossNeedsUpdateCaption,
                TKLocales.Perps.Confirm.continueWithoutStopLoss,
                TKLocales.Perps.Confirm.updateStopLoss
            )
        case .autoClose:
            return (
                TKLocales.Perps.Confirm.autoCloseNeedsUpdateTitle,
                TKLocales.Perps.Confirm.autoCloseNeedsUpdateCaption,
                TKLocales.Perps.Confirm.continueWithoutAutoClose,
                TKLocales.Perps.Confirm.updateAutoClose
            )
        }
    }

    static let reconcileIntervalNanos: UInt64 = 1_000_000_000
    /// Only a stop for a pending nothing can answer — a send that failed before
    /// its first step was signed journals no order key, and that state would
    /// otherwise poll for the life of the process.
    static let reconcileCeiling = 15

    func submit(context: PerpsConfirmContext, confirmationViewModel: PerpsTradeConfirmViewModel? = nil) {
        let descriptor = openingDescriptor(context: context)
        guard openPositionFlow.beginSubmitting(descriptor) else {
            confirmationViewModel?.restoreConfirmation()
            return
        }
        dismissTrade()
        walletScope.accountStore.beginOpening(descriptor)
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.openPositionFlow.finishSubmitting() }
            let prepared: PerpsPreparedTradingAction
            switch await tradingService.prepareOpenMarket(context.intent, passcodeProvider: makePasscodeProvider()) {
            case let .success(value):
                prepared = value
            case let .failure(error):
                walletScope.accountStore.clearPending(marketId: context.intent.marketId)
                let message = PerpsTradingErrorText.message(for: error)
                if !message.isEmpty {
                    assetPageViewModel?.showTradeResult(.failure(message))
                }
                return
            }

            let result = await tradingService.submit(prepared)
            switch result {
            case let .submitted(pending):
                await resolveOpeningOverlay(
                    pending: pending,
                    successToast: toastText(verb: toastSuccessVerb(prepared: prepared), prepared: prepared)
                )
            case let .submitUnknown(pending):
                assetPageViewModel?.showTradeResult(.failure(TKLocales.Perps.Toast.statusUnknown))
                await resolveOpeningOverlay(pending: pending, successToast: nil)
            case let .failed(error):
                walletScope.accountStore.clearPending(marketId: context.intent.marketId)
                assetPageViewModel?.showTradeResult(
                    .failure(PerpsTradingErrorText.message(for: error, fallback: TKLocales.Perps.Toast.openFailed))
                )
            }
        }
    }

    func resolveOpeningOverlay(pending: PerpsPendingTradingAction, successToast: String?) async {
        // A limit order never optimistically opens, so its overlay goes now and the
        // resting order surfaces through extras once reconcile confirms. A market fill
        // settles within ~a second, so that overlay stays `.opening` (actions hidden)
        // until the position exists, rather than flashing Long/Short and inviting a
        // double-open; the live positions stream is the other path to `.open`.
        let isLimit: Bool
        if case .open(nil) = pending.payload {
            isLimit = false
        } else {
            isLimit = true
            walletScope.accountStore.clearPending(marketId: pending.marketId)
        }
        await settleOnPage(
            pending: pending,
            successToast: successToast,
            failureFallback: TKLocales.Perps.Toast.openFailed,
            reloadExtras: isLimit
        )
    }

    /// Polls until tk-perps states an outcome: an order it has not heard about
    /// yet is not a failure, and giving up after a second or two is what used to
    /// report a filled trade as unknown. A cancelled task leaves the pending
    /// journalled for the next launch to finish.
    func awaitReconciled(_ pending: PerpsPendingTradingAction) async -> PerpsReconcileResult {
        for attempt in 0 ..< Self.reconcileCeiling {
            guard !Task.isCancelled else { break }
            let result = await tradingService.reconcile(pending)
            if case .pending = result {
                if attempt < Self.reconcileCeiling - 1 {
                    try? await Task.sleep(nanoseconds: Self.reconcileIntervalNanos)
                }
            } else {
                return result
            }
        }
        return .pending
    }

    /// Submit, then let the page follow the outcome. A refused submission is the
    /// only case that never reaches polling, so it carries its own wording.
    private func settleSubmit(
        marketId: Int64,
        submitFallback: String,
        reloadExtras: Bool,
        successToast: String,
        submit: () async -> PerpsSubmitResult
    ) async {
        let result = await submit()
        let pending: PerpsPendingTradingAction
        let toast: String?
        switch result {
        case let .submitted(value):
            pending = value
            toast = successToast
        case let .submitUnknown(value):
            assetPageViewModel?.showTradeResult(.failure(TKLocales.Perps.Toast.statusUnknown))
            pending = value
            toast = nil
        case let .failed(error):
            walletScope.accountStore.clearPending(marketId: marketId)
            assetPageViewModel?.showTradeResult(
                .failure(PerpsTradingErrorText.message(for: error, fallback: submitFallback))
            )
            refreshAfterTrade()
            return
        }
        await settleOnPage(
            pending: pending,
            successToast: toast,
            failureFallback: TKLocales.Perps.Toast.statusUnknown,
            reloadExtras: reloadExtras
        )
    }

    /// The tail every signed action shares: poll until tk-perps states an outcome,
    /// then put that outcome on the page. Anything but a confirmation drops the
    /// optimistic overlay, since the market is no longer mid-change.
    func settleOnPage(
        pending: PerpsPendingTradingAction,
        successToast: String?,
        failureFallback: String,
        reloadExtras: Bool
    ) async {
        switch await awaitReconciled(pending) {
        case .confirmed:
            walletScope.accountStore.refresh()
            if reloadExtras {
                walletScope.accountStore.loadMarketExtras(marketId: pending.marketId)
            }
            if let successToast {
                assetPageViewModel?.showTradeResult(.success(successToast))
            }
            assetPageViewModel?.retry()
        case let .failed(error):
            walletScope.accountStore.clearPending(marketId: pending.marketId)
            refreshAfterTrade()
            assetPageViewModel?.showTradeResult(
                .failure(PerpsTradingErrorText.message(for: error, fallback: failureFallback))
            )
        case .pending:
            walletScope.accountStore.clearPending(marketId: pending.marketId)
            refreshAfterTrade()
            assetPageViewModel?.showTradeResult(.failure(TKLocales.Perps.Toast.statusUnknown))
        }
    }

    // MARK: - Cash Out (TK-1577)

    func openCashOut(marketId: Int64) {
        guard case .idle = cashOutFlow else { return }
        // The store guards the position side: `.flat`/`.opening` have nothing to cash
        // out, and a stale `.closing` self-heals from venue reads.
        guard openPositionSummary(marketId: marketId) != nil else { return }
        let attempt = PositionActionFlow<PerpsPreparedCloseAction>.Attempt()
        cashOutFlow = .preparing(attempt)
        let originPage = assetPageViewController
        Task { @MainActor [weak self, weak originPage] in
            guard let self else { return }
            let intent = PerpsCloseIntent(marketId: marketId)
            switch await tradingService.prepareClose(intent, passcodeProvider: makePasscodeProvider()) {
            case let .success(prepared):
                // Nothing is submitted yet, so if the user left the asset page while
                // prepare ran, abort instead of presenting the confirm out of context.
                guard cashOutFlow.isCurrent(attempt),
                      let originPage,
                      originPage.navigationController != nil
                else {
                    cashOutFlow = .idle
                    return
                }
                cashOutFlow = .confirming(attempt, prepared)
                await presentCashOutConfirm(prepared, attempt: attempt)
            case let .failure(error):
                cashOutFlow = .idle
                let message = PerpsTradingErrorText.message(for: error)
                if !message.isEmpty {
                    assetPageViewModel?.showTradeResult(.failure(message))
                }
                if case .positionNotFound = error {
                    refreshAfterTrade()
                }
            }
        }
    }

    @MainActor
    private func presentCashOutConfirm(
        _ prepared: PerpsPreparedCloseAction,
        attempt: PositionActionFlow<PerpsPreparedCloseAction>.Attempt
    ) async {
        let sizeDecimals = await perpsAssembly.marketsStore.snapshot(marketId: prepared.marketId)
            .map(\.sizeDecimals) ?? 2
        guard cashOutFlow.isCurrent(attempt) else { return }
        let viewModel = PerpsTradeConfirmViewModel(
            closeContext: PerpsCloseConfirmContext(sizeDecimals: sizeDecimals, review: prepared.review),
            iconURL: assetPageViewModel?.state.ready?.iconURL
        )
        let navigationController = makeTradeNavigationController(
            rootViewController: PerpsTradeConfirmViewController(viewModel: viewModel)
        )

        viewModel.onBack = { [weak self] in
            self?.cancelCashOut()
        }
        viewModel.onClose = { [weak self] in
            self?.cancelCashOut()
        }
        viewModel.onConfirm = { [weak self] in
            self?.submitCashOut()
        }

        present(navigationController)
    }

    func cancelCashOut() {
        guard case .confirming = cashOutFlow else { return }
        cashOutFlow = .idle
        dismissTrade()
    }

    func submitCashOut() {
        guard case let .confirming(_, prepared) = cashOutFlow else { return }
        cashOutFlow = .submitting
        // Design pill semantics: «Closing …» covers the submitted close, so the
        // `.closing` overlay starts at swipe, not at the Cash Out tap.
        walletScope.accountStore.beginClosing(marketId: prepared.marketId)
        dismissTrade()
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.cashOutFlow = .idle }
            await settleSubmit(
                marketId: prepared.marketId,
                submitFallback: TKLocales.Perps.Toast.closeFailed,
                reloadExtras: false,
                successToast: closedToastText(review: prepared.review),
                submit: { await self.tradingService.submit(prepared) }
            )
        }
    }

    func closedToastText(review: PerpsCloseReview) -> String {
        PerpsAssetPageViewModel.closeToastText(
            verb: TKLocales.Perps.Toast.closed,
            symbol: review.symbol,
            side: review.side,
            leverage: review.leverage
        )
    }

    func refreshAfterTrade() {
        assetPageViewModel?.retry()
        walletScope.accountStore.refresh()
    }

    func closeOpenPositionFlow(completion: (() -> Void)? = nil) {
        openPositionFlow.close()
        dismissTrade(completion: completion)
    }

    func dismissTrade(completion: (() -> Void)? = nil) {
        autoClosePrepareTask?.cancel()
        autoClosePrepareTask = nil
        autoClosePrepareGeneration = nil
        guard let tradeNavigationController else {
            completion?()
            return
        }
        tradeNavigationController.dismiss(animated: true, completion: completion)
    }

    func present(_ viewController: UIViewController) {
        sheetPresenter.present(viewController, animated: true)
    }

    func presentSheet(
        _ bottomSheet: TKBottomSheetViewController,
        onWillPresent: @escaping () -> Void
    ) {
        let existingWillPresent = bottomSheet.willPresent
        bottomSheet.willPresent = { [weak self] in
            existingWillPresent?()
            onWillPresent()
            self?.resignTradeKeyboard()
        }
        bottomSheet.present(fromViewController: sheetPresenter)
    }

    static func dismissSheet(
        _ bottomSheet: TKBottomSheetViewController?,
        completion: (() -> Void)? = nil
    ) {
        guard let bottomSheet else {
            completion?()
            return
        }
        bottomSheet.dismiss(completion: completion)
    }

    func resignTradeKeyboard() {
        tradeNavigationController?.view.endEditing(true)
        sheetPresenter.view.endEditing(true)
    }

    var sheetPresenter: UIViewController {
        let base: UIViewController = assetPageViewController?.navigationController ?? router.rootViewController
        return base.topPresentedViewController
    }

    func makePasscodeProvider() -> @Sendable () async -> String? {
        { [weak self] in
            await Task { @MainActor () -> String? in
                guard let self else { return nil }
                return await PasscodeInputCoordinator.getPasscode(
                    parentCoordinator: self,
                    parentRouter: self.router,
                    mnemonicAccess: self.keeperCoreMainAssembly.mnemonicAccess,
                    securityStore: self.keeperCoreMainAssembly.storesAssembly.securityStore
                )
            }.value
        }
    }

    func toastText(verb: String, prepared: PerpsPreparedTradingAction) -> String {
        let sideText = (prepared.intent.side == .long ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short).lowercased()
        let margin = PerpsFormatting.usd(prepared.review.marginUsd)
        let leverage = PerpsFormatting.leverage(prepared.intent.leverage)
        return "\(verb) \(prepared.review.symbol) \(sideText): \(margin) · \(leverage)"
    }

    func openingDescriptor(context: PerpsConfirmContext) -> PerpsOpeningDescriptor {
        PerpsOpeningDescriptor(
            marketId: context.intent.marketId,
            symbol: context.review.symbol,
            side: context.intent.side,
            marginUsd: Double(context.intent.marginUsd) ?? 0,
            leverage: context.intent.leverage,
            isLimit: context.intent.limitPrice != nil
        )
    }

    func toastSuccessVerb(prepared: PerpsPreparedTradingAction) -> String {
        prepared.intent.limitPrice == nil ? TKLocales.Perps.Toast.opened : TKLocales.Perps.Toast.orderPlaced
    }
}

private extension PerpsCoordinator {
    static let defaultInitialLeverage: Double = 10
}

private final class PerpsBottomSheetScrollContentViewController: UIViewController, TKBottomSheetScrollContentViewController {
    var didUpdateHeight: (() -> Void)?
    var headerConfiguration: TKBottomSheetHeaderConfiguration?
    var didUpdateHeaderConfiguration: ((TKBottomSheetHeaderConfiguration?) -> Void)?

    let scrollView = UIScrollView()
    private let hostingView = SwiftUIHostingView()

    init(title: String, subtitle: String?, @ViewBuilder content: () -> some View) {
        super.init(nibName: nil, bundle: nil)
        headerConfiguration = TKBottomSheetHeaderConfiguration(title: .title(title: title, subtitle: subtitle))
        hostingView.setContent(content)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Background.page
        scrollView.backgroundColor = .clear
        view.addSubview(scrollView)
        scrollView.addSubview(hostingView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostingView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
    }

    func calculateHeight(withWidth width: CGFloat) -> CGFloat {
        hostingView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
    }
}

private extension UIViewController {
    var topPresentedViewController: UIViewController {
        var controller: UIViewController = self
        while let presented = controller.presentedViewController {
            controller = presented
        }
        return controller
    }
}
