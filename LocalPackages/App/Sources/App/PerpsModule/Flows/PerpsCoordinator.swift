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

    private weak var assetPageViewModel: PerpsAssetPageViewModel?
    private weak var assetPageViewController: UIViewController?
    private var didPushFlowRoot = false
    private weak var tradeNavigationController: UINavigationController?
    private weak var shareBottomSheet: TKBottomSheetViewController?
    private var shareRenderTask: Task<Void, Never>?

    private let openPositionFlow = PerpsOpenPositionFlow()

    private enum PositionActionFlow<Prepared> {
        case idle
        case preparing
        case confirming(Prepared)
        case submitting
    }

    private var cashOutFlow: PositionActionFlow<PerpsPreparedCloseAction> = .idle
    private var marginChangeFlow: PositionActionFlow<PerpsPreparedMarginChangeAction> = .idle
    private var sizeChangeSession: PerpsSizeChangeSession?
    private var sizeChangePrepareTask: Task<Void, Never>?

    /// Bumped whenever the margin screen is (re)opened or closed, so a
    /// prepare that outlives its screen can't push a confirm with a stale intent
    /// onto whatever flow the user opened next.
    private var marginChangeGeneration: UInt = 0

    /// Auto close has no designed pending state, so unlike the other flows it
    /// leaves the store lifecycle `.open` while its submit reconciles — this
    /// set is what serializes the market's signed actions for that window.
    private var autoCloseSubmitting: Set<Int64> = []
    private var limitOrderSubmitting: Set<Int64> = []
    private var limitOrderSubmittingMarkets: Set<Int64> = []

    private func openPositionSummary(marketId: Int64) -> PerpsPositionSummary? {
        guard case let .open(summary) = walletScope.accountStore.lifecycle(marketId: marketId),
              !autoCloseSubmitting.contains(marketId),
              !limitOrderSubmittingMarkets.contains(marketId) else { return nil }
        return summary
    }

    private func isMarketBusy(_ marketId: Int64) -> Bool {
        autoCloseSubmitting.contains(marketId) || limitOrderSubmittingMarkets.contains(marketId)
    }

    override func start() {
        start(marketID: nil)
    }

    func start(marketID: Int64?) {
        if let marketID {
            openAssetPage(marketId: marketID)
            return
        }

        let viewModel = PerpsViewModel(
            marketsStore: perpsAssembly.marketsStore,
            accountStore: walletScope.accountStore,
            isTestnet: walletScope.activationService.isTestnet
        )
        let viewController = PerpsViewController(viewModel: viewModel)

        viewModel.onBack = { [weak viewController] in
            viewController?.navigationController?.popViewController(animated: true)
        }
        viewModel.onActivate = { [weak self] in
            self?.activate()
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
        viewModel.onSelectMarket = { [weak self] marketId in
            self?.openAssetPage(marketId: marketId)
        }

        pushFlowViewController(viewController)
    }
}

private extension PerpsCoordinator {
    func activate() {
        let accountStore = walletScope.accountStore
        let service = walletScope.activationService
        accountStore.beginActivation()
        Task { [weak self] in
            guard let self else { return }
            let passcode = await PasscodeInputCoordinator.getPasscode(
                parentCoordinator: self,
                parentRouter: self.router,
                mnemonicAccess: self.keeperCoreMainAssembly.mnemonicAccess,
                securityStore: self.keeperCoreMainAssembly.storesAssembly.securityStore,
                analyticsProvider: self.analyticsProvider
            )
            let outcome: LighterActivationOutcome
            if let passcode {
                outcome = await service.activate(wallet: self.walletScope.wallet, passcode: passcode)
            } else {
                outcome = .canceled
            }
            await accountStore.applyActivation(outcome)
            if case let .failed(error) = outcome {
                let message = PerpsTradingErrorText.message(for: error)
                ToastPresenter.showToast(
                    configuration: .init(title: message.isEmpty ? TKLocales.Perps.Error.generic : message)
                )
            }
        }
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
            openPositionFlow: openPositionFlow,
            isTestnet: walletScope.activationService.isTestnet
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
        viewModel.onEdit = { [weak self] marketId in
            self?.openEditPositionSheet(marketId: marketId)
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
        let viewController = PerpsAmountFormViewController(viewModel: viewModel)
        let navigationController = TKNavigationController(rootViewController: viewController)
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.modalPresentationStyle = .fullScreen
        tradeNavigationController = navigationController

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
        onWillPresent: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
        onApply: @escaping (Double) -> Void
    ) {
        let viewModel = PerpsLeverageSheetViewModel(context: context, service: tradingService)
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
        let subtitle = "\(TKLocales.Perps.OpenPosition.price) \(PerpsFormatting.usd(context.entryPrice))"
        let bottomSheet = makeSheet(title: TKLocales.Perps.OpenPosition.autoCloseTitle, subtitle: subtitle) {
            PerpsAutoCloseSheetView(viewModel: viewModel)
        }
        bottomSheet.keyboardObserver = TKBottomSheetKeyboardObserver(bottomSheet: bottomSheet)
        bottomSheet.didClose = { _ in onDismiss() }
        viewModel.onApply = { [weak bottomSheet] autoClose in
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

    // MARK: - Edit Position (TK-1578)

    func openEditPositionSheet(marketId: Int64) {
        guard let summary = openPositionSummary(marketId: marketId) else { return }
        let viewModel = PerpsEditPositionSheetViewModel(side: summary.side)
        let bottomSheet = makeSheet(title: TKLocales.Perps.EditPosition.title) {
            PerpsEditPositionSheetView(viewModel: viewModel)
        }
        viewModel.onAdd = { [weak self, weak bottomSheet] in
            Self.dismissSheet(bottomSheet) {
                Task { @MainActor in
                    await self?.openSizeChange(marketId: marketId, direction: .add)
                }
            }
        }
        viewModel.onReduce = { [weak self, weak bottomSheet] in
            Self.dismissSheet(bottomSheet) {
                Task { @MainActor in
                    await self?.openSizeChange(marketId: marketId, direction: .reduce)
                }
            }
        }
        presentSheet(bottomSheet, onWillPresent: {})
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
        let viewController = PerpsAmountFormViewController(viewModel: viewModel)
        let navigationController = TKNavigationController(rootViewController: viewController)
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.modalPresentationStyle = .fullScreen
        tradeNavigationController = navigationController

        viewModel.onClose = { [weak self] in
            guard let self, sizeChangeSession === session else { return }
            finishSizeChangeSession(session)
            dismissTrade()
        }
        viewModel.onDeposit = { [weak self] in
            self?.openTradePlaceholder(title: TKLocales.Perps.deposit)
        }
        viewModel.onOpenAutoClose = { [weak self, weak viewModel] context in
            self?.openAutoCloseSheet(
                context,
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
                  sizeChangeSession === session
            else {
                session.cancelPreparation(request)
                return
            }
            switch result {
            case let .success(prepared):
                guard let tradeNavigationController, tradeNavigationController.presentingViewController != nil else {
                    session.failPreparation(request, warning: nil)
                    return
                }
                guard session.acceptPreparation(prepared, for: request) else { return }
                await pushSizeChangeConfirm(
                    session: session,
                    in: tradeNavigationController,
                    formViewModel: formViewModel
                )
            case let .failure(error):
                if case .activationCanceled = error {
                    session.cancelPreparation(request)
                    return
                }
                let failure = changePrepareFailure(error)
                guard session.failPreparation(request, warning: failure.warning) else { return }
                if failure.shouldCloseTrade {
                    finishSizeChangeSession(session)
                    dismissTrade()
                    refreshAfterTrade()
                }
            }
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
                  sizeChangeSession === session
            else {
                session.cancelPreparation(request)
                return
            }
            switch result {
            case let .success(newPrepared):
                guard session.acceptPreparation(newPrepared, for: request) else { return }
                onPrepared()
            case .failure(.activationCanceled):
                session.cancelPreparation(request)
            case let .failure(error):
                let failure = changePrepareFailure(error)
                guard session.failPreparation(request, warning: failure.warning) else { return }
                if failure.shouldCloseTrade {
                    finishSizeChangeSession(session)
                    dismissTrade()
                    refreshAfterTrade()
                    return
                }
                tradeNavigationController?.popViewController(animated: true)
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
            leverage: prepared.review.leverage ?? 0,
            liquidationPrice: prepared.review.liquidationPrice,
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
                failureFallback: TKLocales.Perps.Toast.adjustFailed,
                submit: { await self.tradingService.submit(prepared) },
                resolve: { pending, claimSuccess in
                    await self.resolveChangeOverlay(
                        pending: pending,
                        reloadExtras: true,
                        successToast: claimSuccess ? self.adjustedToastText(review: prepared.review) : nil,
                        reconcile: { await self.tradingService.reconcileSizeChange($0) }
                    )
                }
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
        guard let summary = openPositionSummary(marketId: marketId) else { return }
        // The asset page holds the extras subscription open, so the resting legs
        // behind the prefill are the warm cache the row itself was drawn from.
        let resting = walletScope.accountStore.marketExtras(marketId: marketId)?.triggerOrders ?? []
        let context = PerpsAutoCloseSheetContext(
            side: summary.side,
            entryPrice: summary.entryPrice,
            leverage: summary.leverage ?? 0,
            liquidationPrice: summary.liquidationPrice > 0 ? summary.liquidationPrice : nil,
            draft: PerpsAutoClose(triggerOrders: resting)
        )
        let viewModel = PerpsAutoCloseSheetViewModel(context: context)
        let subtitle = "\(TKLocales.Perps.OpenPosition.price) \(PerpsFormatting.usd(context.entryPrice))"
        let bottomSheet = makeSheet(title: TKLocales.Perps.OpenPosition.autoCloseTitle, subtitle: subtitle) {
            PerpsAutoCloseSheetView(viewModel: viewModel)
        }
        bottomSheet.keyboardObserver = TKBottomSheetKeyboardObserver(bottomSheet: bottomSheet)
        viewModel.onSubmit = { [weak self, weak bottomSheet] target in
            await self?.submitAutoCloseChange(marketId: marketId, target: target, bottomSheet: bottomSheet)
        }
        viewModel.onClose = { [weak bottomSheet] in
            Self.dismissSheet(bottomSheet, completion: {})
        }
        presentSheet(bottomSheet, onWillPresent: {})
    }

    // MARK: - Resting limit orders

    func openLimitOrderActions(
        marketId: Int64,
        order: PerpsLimitOrderSummary,
        presenter: UIViewController
    ) {
        guard !limitOrderSubmitting.contains(order.orderIndex),
              !isMarketBusy(marketId) else { return }
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
        guard !limitOrderSubmitting.contains(order.orderIndex),
              !isMarketBusy(marketId) else { return }
        let referencePrice = market.flatMap { $0.hasPrice ? $0.price : nil } ?? order.limitPrice
        let priceDecimals = market.map(\.priceDecimals) ?? 2
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
        guard !isMarketBusy(marketId),
              limitOrderSubmitting.insert(order.orderIndex).inserted else { return }
        limitOrderSubmittingMarkets.insert(marketId)
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.limitOrderSubmitting.remove(order.orderIndex)
                self.limitOrderSubmittingMarkets.remove(marketId)
            }
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

            let result = await awaitLimitOrderChangeReconciled(pending)
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

    func awaitLimitOrderChangeReconciled(
        _ pending: PerpsPendingTradingAction
    ) async -> PerpsLimitOrderChangeReconcileResult {
        for attempt in 0 ..< Self.reconcileAttempts {
            let result = await tradingService.reconcileLimitOrderChange(pending)
            if case .pending = result {
                if attempt < Self.reconcileAttempts - 1 {
                    try? await Task.sleep(nanoseconds: Self.reconcileIntervalNanos)
                }
            } else {
                return result
            }
        }
        return .pending
    }

    /// Returns the inline error text for the sheet; nil closes it (confirmed).
    func submitAutoCloseChange(
        marketId: Int64,
        target: PerpsAutoClose?,
        bottomSheet: TKBottomSheetViewController?
    ) async -> String? {
        let target = target ?? PerpsAutoClose(takeProfit: nil, stopLoss: nil)
        let resting = walletScope.accountStore.marketExtras(marketId: marketId)?.triggerOrders ?? []
        if PerpsAutoCloseChangePlanner.matches(target: target, resting: resting) {
            Self.dismissSheet(bottomSheet, completion: {})
            return nil
        }
        let intent = PerpsAutoCloseChangeIntent(marketId: marketId, target: target)
        let prepared: PerpsPreparedAutoCloseChangeAction
        switch await tradingService.prepareAutoCloseChange(intent, passcodeProvider: makePasscodeProvider()) {
        case let .success(value):
            prepared = value
        case .failure(.activationCanceled):
            return ""
        case .failure(.nothingToChange):
            walletScope.accountStore.loadMarketExtras(marketId: marketId)
            Self.dismissSheet(bottomSheet, completion: {})
            return nil
        case .failure(.positionNotFound):
            Self.dismissSheet(bottomSheet, completion: {})
            refreshAfterTrade()
            return ""
        case let .failure(error):
            return PerpsTradingErrorText.message(for: error)
        }

        // Nothing is submitted yet, so a sheet dismissed during prepare is a cancel.
        guard let bottomSheet, bottomSheet.presentingViewController != nil else { return "" }
        guard !limitOrderSubmittingMarkets.contains(marketId) else {
            return TKLocales.Perps.Toast.adjustFailed
        }

        autoCloseSubmitting.insert(marketId)
        defer { autoCloseSubmitting.remove(marketId) }

        switch await tradingService.submit(prepared) {
        case let .failed(error):
            // A single tx either landed or it didn't, but the venue may have
            // rejected for a reason the page should reflect — reload the orders.
            walletScope.accountStore.loadMarketExtras(marketId: marketId)
            let message = PerpsTradingErrorText.message(for: error)
            return message.isEmpty ? TKLocales.Perps.Toast.adjustFailed : message
        case let .submitted(pending), let .submitUnknown(pending):
            switch await awaitAutoCloseReconciled(pending: pending) {
            case .confirmed:
                walletScope.accountStore.loadMarketExtras(marketId: marketId)
                Self.dismissSheet(bottomSheet, completion: {})
                assetPageViewModel?.retry()
                return nil
            case let .failed(error):
                walletScope.accountStore.loadMarketExtras(marketId: marketId)
                let message = PerpsTradingErrorText.message(for: error)
                return message.isEmpty ? TKLocales.Perps.Toast.adjustFailed : message
            case .pending:
                walletScope.accountStore.loadMarketExtras(marketId: marketId)
                return TKLocales.Perps.Toast.statusUnknown
            }
        }
    }

    func awaitAutoCloseReconciled(pending: PerpsPendingTradingAction) async -> PerpsAutoCloseReconcileResult {
        for attempt in 0 ..< Self.closeReconcileAttempts {
            let result = await tradingService.reconcileAutoCloseChange(pending)
            if case .pending = result {
                if attempt < Self.closeReconcileAttempts - 1 {
                    try? await Task.sleep(nanoseconds: Self.closeReconcileIntervalNanos)
                }
            } else {
                return result
            }
        }
        return .pending
    }

    // MARK: - Adjust Margin (TK-1579)

    func openAdjustMarginSheet(marketId: Int64) {
        guard openPositionSummary(marketId: marketId) != nil else { return }
        let viewModel = PerpsAdjustMarginSheetViewModel()
        let bottomSheet = makeSheet(title: TKLocales.Perps.AdjustMargin.title) {
            PerpsAdjustMarginSheetView(viewModel: viewModel)
        }
        viewModel.onAdd = { [weak self, weak bottomSheet] in
            Self.dismissSheet(bottomSheet) {
                Task { @MainActor in
                    await self?.openMarginChange(marketId: marketId, direction: .add)
                }
            }
        }
        viewModel.onReduce = { [weak self, weak bottomSheet] in
            Self.dismissSheet(bottomSheet) {
                Task { @MainActor in
                    await self?.openMarginChange(marketId: marketId, direction: .reduce)
                }
            }
        }
        presentSheet(bottomSheet, onWillPresent: {})
    }

    @MainActor
    func openMarginChange(marketId: Int64, direction: PerpsMarginChangeDirection) async {
        let market = await perpsAssembly.marketsStore.snapshot(marketId: marketId)
        guard let summary = openPositionSummary(marketId: marketId) else { return }
        marginChangeGeneration += 1
        marginChangeFlow = .idle
        let lastTradePrice = market.map { $0.price > 0 ? $0.price : 0 } ?? 0
        let viewModel = PerpsMarginChangeViewModel(
            direction: direction,
            summary: summary,
            displayPrice: market.flatMap { $0.hasPrice ? $0.price : nil } ?? lastTradePrice,
            accountStore: walletScope.accountStore,
            tradingService: tradingService
        )
        let viewController = PerpsAmountFormViewController(viewModel: viewModel)
        let navigationController = TKNavigationController(rootViewController: viewController)
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.modalPresentationStyle = .fullScreen
        tradeNavigationController = navigationController

        viewModel.onClose = { [weak self] in
            self?.marginChangeGeneration += 1
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
        marginChangeFlow = .preparing
        let generation = marginChangeGeneration
        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await tradingService.prepareMarginChange(intent, passcodeProvider: makePasscodeProvider())
            guard generation == marginChangeGeneration else { return }
            switch result {
            case let .success(prepared):
                guard let tradeNavigationController, tradeNavigationController.presentingViewController != nil else {
                    marginChangeFlow = .idle
                    return
                }
                marginChangeFlow = .confirming(prepared)
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
        let message = PerpsTradingErrorText.message(for: error)
        let shouldCloseTrade: Bool
        if case .positionNotFound = error {
            shouldCloseTrade = true
        } else {
            shouldCloseTrade = false
        }
        return ChangePrepareFailure(
            warning: message.isEmpty ? TKLocales.Perps.Toast.adjustFailed : message,
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
        guard case let .confirming(prepared) = marginChangeFlow else { return }
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
                failureFallback: TKLocales.Perps.Toast.adjustFailed,
                submit: { await self.tradingService.submit(prepared) },
                resolve: { pending, claimSuccess in
                    await self.resolveChangeOverlay(
                        pending: pending,
                        reloadExtras: false,
                        successToast: claimSuccess
                            ? PerpsAssetPageViewModel.marginToastText(
                                direction: prepared.review.direction,
                                amountUsd: prepared.review.amountUsd,
                                isDone: true
                            )
                            : nil,
                        reconcile: { await self.tradingService.reconcileMarginChange($0) }
                    )
                }
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
            guard let context = viewModel?.openConfirmContext else { return }
            Task { @MainActor in
                await self?.handleOpenConfirm(context: context, openFormViewModel: openFormViewModel)
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
            leverage: context.intent.leverage,
            liquidationPrice: context.review.liquidationPrice,
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
    func handleOpenConfirm(context: PerpsConfirmContext, openFormViewModel: PerpsOpenPositionViewModel?) async {
        guard let autoClose = context.intent.autoClose, !autoClose.isEmpty else {
            submit(context: context)
            return
        }
        let marketPrice = await perpsAssembly.marketsStore.price(marketId: context.intent.marketId)
        let referencePrice = context.intent.limitPrice
            ?? marketPrice
            ?? context.review.entryPrice
            ?? 0
        let invalid = PerpsAutoCloseValidation.invalidLegs(
            side: context.intent.side,
            entryPrice: referencePrice,
            liquidationPrice: context.review.liquidationPrice,
            autoClose: autoClose
        )
        guard let kind = invalid.confirmStaleKind else {
            submit(context: context)
            return
        }
        presentAutoCloseStaleAlert(
            kind: kind,
            onContinueWithout: { [weak self, weak openFormViewModel] in
                let stripped = PerpsAutoCloseValidation.stripping(autoClose, removing: invalid)
                openFormViewModel?.applyAutoClose(stripped.isEmpty ? nil : stripped)
                let intent = PerpsOpenMarketIntent(
                    marketId: context.intent.marketId,
                    side: context.intent.side,
                    marginUsd: context.intent.marginUsd,
                    leverage: context.intent.leverage,
                    maxSlippage: context.intent.maxSlippage,
                    autoClose: stripped.isEmpty ? nil : stripped,
                    limitPrice: context.intent.limitPrice
                )
                self?.submit(context: PerpsConfirmContext(
                    intent: intent,
                    sizeDecimals: context.sizeDecimals,
                    review: context.review
                ))
            },
            onUpdate: { [weak self, weak openFormViewModel] in
                self?.tradeNavigationController?.popViewController(animated: true)
                openFormViewModel?.openAutoClose()
            }
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
            entryPrice: referencePrice,
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
        session.finish()
        sizeChangeSession = nil
    }

    func presentAutoCloseStaleAlert(
        kind: PerpsAutoCloseValidation.ConfirmStaleKind,
        onContinueWithout: @escaping () -> Void,
        onUpdate: @escaping () -> Void
    ) {
        let copy = Self.autoCloseStaleCopy(kind: kind)
        var continueButton = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
        continueButton.content = TKButton.Configuration.Content(title: .plainString(copy.continueTitle))
        var updateButton = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
        updateButton.content = TKButton.Configuration.Content(title: .plainString(copy.updateTitle))

        let viewController = InfoPopupBottomSheetViewController()
        let bottomSheet = TKBottomSheetViewController(contentViewController: viewController)
        continueButton.action = { [weak bottomSheet] in
            bottomSheet?.dismiss {
                onContinueWithout()
            }
        }
        updateButton.action = { [weak bottomSheet] in
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

    static let reconcileAttempts = 4
    static let reconcileIntervalNanos: UInt64 = 500_000_000

    func submit(context: PerpsConfirmContext) {
        let descriptor = openingDescriptor(context: context)
        guard openPositionFlow.beginSubmitting(descriptor) else { return }
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
                let message = PerpsTradingErrorText.message(for: error)
                assetPageViewModel?.showTradeResult(.failure(message.isEmpty ? TKLocales.Perps.Toast.openFailed : message))
            }
        }
    }

    func resolveOpeningOverlay(pending: PerpsPendingTradingAction, successToast: String?) async {
        // Limit orders never optimistically open; drop the overlay and let the resting
        // order surface through extras after reconcile confirms.
        guard pending.limitPrice == nil else {
            walletScope.accountStore.clearPending(marketId: pending.marketId)
            let result = await awaitReconciled(
                attempts: Self.reconcileAttempts,
                intervalNanos: Self.reconcileIntervalNanos
            ) {
                await self.tradingService.reconcileOpenMarket(pending)
            }
            switch result {
            case let .confirmed(positions, availableBalance):
                walletScope.accountStore.applyReconciledPositions(positions, availableBalance: availableBalance)
                walletScope.accountStore.loadMarketExtras(marketId: pending.marketId)
                if let successToast {
                    assetPageViewModel?.showTradeResult(.success(successToast))
                }
                assetPageViewModel?.retry()
            case let .failed(error):
                refreshAfterTrade()
                let message = PerpsTradingErrorText.message(for: error)
                assetPageViewModel?.showTradeResult(
                    .failure(message.isEmpty ? TKLocales.Perps.Toast.openFailed : message)
                )
            case .pending:
                refreshAfterTrade()
                assetPageViewModel?.showTradeResult(.failure(TKLocales.Perps.Toast.statusUnknown))
            }
            return
        }
        // A market fill settles within ~a second. Re-read the venue a few times so the
        // overlay stays `.opening` (actions hidden) until the position exists, rather than
        // flashing Long/Short and inviting a double-open; the live positions stream is the
        // other path to `.open`. Only clear once the fill genuinely never landed.
        let result = await awaitReconciled(attempts: Self.reconcileAttempts, intervalNanos: Self.reconcileIntervalNanos) {
            await self.tradingService.reconcileOpenMarket(pending)
        }
        switch result {
        case let .confirmed(positions, availableBalance):
            walletScope.accountStore.applyReconciledPositions(positions, availableBalance: availableBalance)
            if let successToast {
                assetPageViewModel?.showTradeResult(.success(successToast))
            }
            assetPageViewModel?.retry()
        case let .failed(error):
            walletScope.accountStore.clearPending(marketId: pending.marketId)
            refreshAfterTrade()
            let message = PerpsTradingErrorText.message(for: error)
            assetPageViewModel?.showTradeResult(
                .failure(message.isEmpty ? TKLocales.Perps.Toast.openFailed : message)
            )
        case .pending:
            walletScope.accountStore.clearPending(marketId: pending.marketId)
            refreshAfterTrade()
            assetPageViewModel?.showTradeResult(.failure(TKLocales.Perps.Toast.statusUnknown))
        }
    }

    /// Polls until the venue supplies a terminal domain outcome. A rejection is
    /// returned immediately instead of being collapsed into a timeout.
    func awaitReconciled(
        attempts: Int,
        intervalNanos: UInt64,
        _ reconcile: () async -> PerpsReconcileResult
    ) async -> PerpsReconcileResult {
        for attempt in 0 ..< attempts {
            let result = await reconcile()
            if case .pending = result {
                if attempt < attempts - 1 {
                    try? await Task.sleep(nanoseconds: intervalNanos)
                }
            } else {
                return result
            }
        }
        return .pending
    }

    private func settleSubmit(
        marketId: Int64,
        failureFallback: String,
        submit: () async -> PerpsSubmitResult,
        resolve: (PerpsPendingTradingAction, _ claimSuccess: Bool) async -> Void
    ) async {
        switch await submit() {
        case let .submitted(pending):
            await resolve(pending, true)
        case let .submitUnknown(pending):
            assetPageViewModel?.showTradeResult(.failure(TKLocales.Perps.Toast.statusUnknown))
            await resolve(pending, false)
        case let .failed(error):
            walletScope.accountStore.clearPending(marketId: marketId)
            let message = PerpsTradingErrorText.message(for: error)
            assetPageViewModel?.showTradeResult(.failure(message.isEmpty ? failureFallback : message))
            refreshAfterTrade()
        }
    }

    private func resolveChangeOverlay(
        pending: PerpsPendingTradingAction,
        reloadExtras: Bool,
        successToast: String?,
        reconcile: (PerpsPendingTradingAction) async -> PerpsReconcileResult
    ) async {
        let result = await awaitReconciled(attempts: Self.closeReconcileAttempts, intervalNanos: Self.closeReconcileIntervalNanos) {
            await reconcile(pending)
        }
        switch result {
        case let .confirmed(positions, availableBalance):
            walletScope.accountStore.applyReconciledPositions(positions, availableBalance: availableBalance)
            if reloadExtras {
                walletScope.accountStore.loadMarketExtras(marketId: pending.marketId)
            }
            if let successToast {
                assetPageViewModel?.showTradeResult(.success(successToast))
            }
            assetPageViewModel?.retry()
        case let .failed(error):
            let message = PerpsTradingErrorText.message(for: error)
            assetPageViewModel?.showTradeResult(
                .failure(message.isEmpty ? TKLocales.Perps.Toast.statusUnknown : message)
            )
            walletScope.accountStore.clearPending(marketId: pending.marketId)
            refreshAfterTrade()
        case .pending:
            assetPageViewModel?.showTradeResult(.failure(TKLocales.Perps.Toast.statusUnknown))
            walletScope.accountStore.clearPending(marketId: pending.marketId)
            refreshAfterTrade()
        }
    }

    // MARK: - Cash Out (TK-1577)

    func openCashOut(marketId: Int64) {
        guard case .idle = cashOutFlow else { return }
        // The store guards the position side: `.flat`/`.opening` have nothing to cash
        // out, and a stale `.closing` self-heals from venue reads.
        guard openPositionSummary(marketId: marketId) != nil else { return }
        cashOutFlow = .preparing
        let originPage = assetPageViewController
        Task { @MainActor [weak self, weak originPage] in
            guard let self else { return }
            let intent = PerpsCloseIntent(marketId: marketId)
            switch await tradingService.prepareClose(intent, passcodeProvider: makePasscodeProvider()) {
            case let .success(prepared):
                // Nothing is submitted yet, so if the user left the asset page while
                // prepare ran, abort instead of presenting the confirm out of context.
                guard let originPage, originPage.navigationController != nil else {
                    cashOutFlow = .idle
                    return
                }
                cashOutFlow = .confirming(prepared)
                await presentCashOutConfirm(prepared)
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
    func presentCashOutConfirm(_ prepared: PerpsPreparedCloseAction) async {
        let sizeDecimals = await perpsAssembly.marketsStore.snapshot(marketId: prepared.marketId)
            .map(\.sizeDecimals) ?? 2
        guard case let .confirming(current) = cashOutFlow, current.operationId == prepared.operationId else { return }
        let viewModel = PerpsTradeConfirmViewModel(
            closeContext: PerpsCloseConfirmContext(sizeDecimals: sizeDecimals, review: prepared.review),
            iconURL: assetPageViewModel?.state.ready?.iconURL
        )
        let viewController = PerpsTradeConfirmViewController(viewModel: viewModel)
        let navigationController = TKNavigationController(rootViewController: viewController)
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.modalPresentationStyle = .fullScreen
        tradeNavigationController = navigationController

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
        guard case let .confirming(prepared) = cashOutFlow else { return }
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
                failureFallback: TKLocales.Perps.Toast.closeFailed,
                submit: { await self.tradingService.submit(prepared) },
                resolve: { pending, claimSuccess in
                    await self.resolveChangeOverlay(
                        pending: pending,
                        reloadExtras: false,
                        successToast: claimSuccess ? self.closedToastText(review: prepared.review) : nil,
                        reconcile: { await self.tradingService.reconcileClose($0) }
                    )
                }
            )
        }
    }

    // A market close is an IOC order: staging fills + venue reads can lag ~5s,
    // so the close window is longer than the open one.
    static let closeReconcileAttempts = 8
    static let closeReconcileIntervalNanos: UInt64 = 750_000_000

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
