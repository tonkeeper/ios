import Combine
import PerpsModels
import SwiftUI
import TKCoordinator
import TKLocalize
import TKLogging
import TKUIKit
import UIKit

final class PerpsTradeCoordinator: RouterCoordinator<NavigationControllerRouter> {
    private let context: PerpsFlowContext
    private let passcodeProvider: @Sendable () async -> String?
    private let openDeposit: (PerpsDepositEntry, UINavigationController?) -> Void
    private let sheetPresenter: @MainActor () async -> UIViewController?
    private let preparation: PerpsTradePreparation
    private weak var tradeNavigationController: UINavigationController?
    private weak var regionRefusalSheet: TKBottomSheetViewController?
    private var regionRefusalsAwaitingSheet: [Int64] = []
    var onOpenLoyalty: (() -> Void)?

    init(
        router: NavigationControllerRouter,
        context: PerpsFlowContext,
        passcodeProvider: @escaping @Sendable () async -> String?,
        openDeposit: @escaping (PerpsDepositEntry, UINavigationController?) -> Void,
        sheetPresenter: @escaping @MainActor () async -> UIViewController?
    ) {
        self.context = context
        self.passcodeProvider = passcodeProvider
        self.openDeposit = openDeposit
        self.sheetPresenter = sheetPresenter
        preparation = PerpsTradePreparation(context: context, passcodeProvider: passcodeProvider)
        super.init(router: router)
        preparation.activateAccount = { [weak self] onPasscodeEntered in
            guard let self else { return .canceled }
            let result = await walletDependencies.activateAccount(self, router, onPasscodeEntered)
            if case .failed = result {
                ToastPresenter.showToast(configuration: .init(title: TKLocales.Perps.Error.generic))
            }
            return result
        }
        context.tradeRunner.onRegionRestricted = { [weak self] marketId in
            self?.presentRegionRefusal(marketId: marketId)
        }
    }

    private var perpsAssembly: any PerpsDependencies {
        context.dependencies
    }

    private var walletDependencies: PerpsWalletDependencies {
        context.wallet
    }

    private var format: PerpsFormatting {
        context.format
    }

    private var tradingService: any PerpsTradingService {
        walletDependencies.tradingService
    }

    private var openPositionFlow: PerpsOpenPositionFlow {
        context.openPositionFlow
    }

    private var tradeRunner: PerpsTradeRunner {
        context.tradeRunner
    }
}

extension PerpsTradeCoordinator {
    func openOpenPosition(_ screen: PerpsMarketScreenContext, side: PerpsTradeSide) {
        guard !isTradingRestricted() else { return }
        preparation.prepareOpening(marketId: screen.marketId) { [weak self] in
            self?.presentOpenPosition(screen, side: side)
        }
    }

    /// A retry is a new order at a new price, so it goes through a confirm screen of its own. The
    /// screen opens at once, since a flow begun with nothing on screen reads as a lost one to the
    /// next open, and holds the swipe until figures read for it replace the refused ones. Another
    /// trade screen already up goes first: presenting over it would take its dismissal handle.
    func retryOpen(_ context: PerpsConfirmContext, screen: PerpsMarketScreenContext) {
        guard !isTradingRestricted() else { return }
        let marketId = context.intent.marketId
        guard tradeNavigationController?.presentingViewController == nil,
              openPositionFlow.begin(marketId: marketId)
        else {
            Log.perps.i("open retry ignored market=\(marketId) composing=\(String(describing: openPositionFlow.composingMarketId))")
            return
        }
        present(makeTradeNavigationController(rootViewController: makeOpenConfirm(
            context: context,
            screen: screen,
            openFormViewModel: nil,
            awaitsReview: context.intent.limitPrice == nil
        )))
    }

    func openEditPositionSheet(_ screen: PerpsMarketScreenContext, directions: Set<PerpsSizeChangeDirection>) {
        guard let summary = screen.position else { return }
        guard directions.count > 1 else {
            guard let direction = directions.first else { return }
            openSizeChange(screen, direction: direction)
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
                guard let self else { return }
                openSizeChange(preparation.refreshed(screen), direction: direction)
            }
        )
    }

    // MARK: - Auto Close on a live position (TK-1580)

    /// The sheet's Set is the confirmation (no confirm screen in design): it
    /// prepares and submits in one go, shows the designed loading state, and
    /// the sheet closes only on a confirmed trigger-order delta.
    func openPositionAutoClose(_ screen: PerpsMarketScreenContext) {
        guard let summary = screen.position else { return }
        let marketId = screen.marketId
        // The asset page holds the extras subscription open, so the resting legs
        // behind the prefill are the warm cache the row itself was drawn from.
        let resting = walletDependencies.accountStore.marketExtras(marketId: marketId)?.triggerOrders ?? []
        let context = PerpsAutoCloseSheetContext(
            marketId: marketId,
            side: summary.side,
            entryPrice: summary.entryPrice,
            referencePrice: screen.markPrice ?? summary.entryPrice,
            leverage: summary.effectiveLeverage ?? 0,
            baseSize: summary.baseSize,
            liquidationPrice: summary.liquidationPrice > 0 ? summary.liquidationPrice : nil,
            priceDecimals: screen.market.priceDecimals,
            draft: PerpsAutoClose(triggerOrders: resting),
            livePriceMarketId: marketId
        )
        let (viewModel, bottomSheet) = makeAutoCloseSheet(context)
        viewModel.onApply = .submit { [weak self, weak bottomSheet] target in
            guard let self else { return .finished }
            return await preparation.changeAutoClose(
                screen,
                target: target,
                isSheetOnScreen: { bottomSheet?.presentingViewController != nil },
                dismissSheet: { Self.dismissSheet(bottomSheet, completion: {}) }
            )
        }
        viewModel.onClose = { [weak bottomSheet] in
            Self.dismissSheet(bottomSheet, completion: {})
        }
        presentSheet(bottomSheet, onWillPresent: {})
    }

    func openLimitOrderActions(
        _ screen: PerpsMarketScreenContext,
        order: PerpsLimitOrderSummary,
        presenter: UIViewController
    ) {
        guard !tradeRunner.isBusy(screen.marketId) else { return }
        let price = "\(TKLocales.Perps.Order.price) \(format.price(order.limitPrice))"
        let alert = UIAlertController(
            title: TKLocales.Perps.OrderType.limit,
            message: order.isBelowMarketMinimum ? "\(price)\n\(TKLocales.Perps.Error.orderTooSmall)" : price,
            preferredStyle: .actionSheet
        )
        let edit = UIAlertAction(title: TKLocales.Actions.edit, style: .default) { [weak self] _ in
            self?.editLimitOrder(screen, order: order)
        }
        edit.isEnabled = !order.isBelowMarketMinimum
        alert.addAction(edit)
        alert.addAction(UIAlertAction(title: TKLocales.Perps.Order.cancel, style: .destructive) { [weak self] _ in
            self?.cancelLimitOrder(marketId: screen.marketId, order: order)
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

    func editLimitOrder(_ screen: PerpsMarketScreenContext, order: PerpsLimitOrderSummary) {
        let marketId = screen.marketId
        guard !tradeRunner.isBusy(marketId), !isTradingRestricted() else { return }
        let side: PerpsTradeSide = order.side == .long ? .long : .short
        let legs = order.autoCloseLegs
        let autoClose = PerpsAutoClose(triggerOrders: legs)
        let context = PerpsSetLimitPriceContext(
            marketId: marketId,
            side: side,
            priceDecimals: screen.market.priceDecimals,
            referencePrice: screen.market.hasPrice ? screen.market.price : order.limitPrice,
            initialLimitPrice: order.limitPrice,
            autoClose: autoClose,
            passedAutoClose: .isRemoved
        )
        let viewModel = PerpsSetLimitPriceViewModel(context: context, marketsStore: perpsAssembly.marketsStore, format: format)
        let viewController = PerpsSetLimitPriceViewController(viewModel: viewModel)
        let navigationController = UINavigationController(rootViewController: viewController)
        viewModel.onBack = { [weak navigationController] in
            navigationController?.dismiss(animated: true)
        }
        viewModel.onClose = { [weak navigationController] in
            navigationController?.dismiss(animated: true)
        }
        viewModel.onSet = { [weak self, weak navigationController] price in
            let passed = PerpsAutoCloseValidation.legsPassed(byLimitPrice: price, side: side, autoClose: autoClose)
            let removedLegs = legs.filter { $0.kind == .takeProfit ? passed.takeProfit : passed.stopLoss }
            navigationController?.dismiss(animated: true) {
                self?.submitLimitOrderChange(
                    .modify(
                        marketId: marketId,
                        orderIndex: order.orderIndex,
                        limitPrice: price,
                        baseAmount: order.remainingBaseAmount,
                        orderId: order.id
                    ),
                    cancellingFirst: removedLegs.map(\.cancelKey)
                ) { [weak self] prepared, submit in
                    self?.presentLimitOrderChangeReview(prepared, market: screen.market, removedLegs: removedLegs, onConfirm: submit)
                }
            }
        }
        router.sheetPresenter.present(navigationController, animated: true)
    }

    func cancelLimitOrder(marketId: Int64, order: PerpsLimitOrderSummary) {
        submitLimitOrderChange(.cancel(marketId: marketId, orderIndex: order.orderIndex, orderId: order.id)) { _, submit in
            submit()
        }
    }

    func openAdjustMarginSheet(_ screen: PerpsMarketScreenContext) {
        guard screen.position != nil else { return }
        let flags = walletDependencies.accountStore.marketExtras(marketId: screen.marketId)?.flags
        let canAdd = flags.canAddMargin
        let canReduce = flags.canRemoveMargin
        guard canAdd, canReduce else {
            guard canAdd || canReduce else { return }
            openMarginChange(screen, direction: canAdd ? .add : .reduce)
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
                guard let self else { return }
                openMarginChange(preparation.refreshed(screen), direction: direction)
            }
        )
    }

    func openCashOut(_ screen: PerpsMarketScreenContext, from originPage: UIViewController?) {
        // The store guards the position side: `.flat`/`.opening` have nothing to cash
        // out, and a stale `.closing` self-heals from venue reads.
        guard screen.position != nil else { return }
        preparation.prepareClose(
            marketId: screen.marketId,
            isOnScreen: { [weak originPage] in originPage?.navigationController != nil }
        ) { [weak self, weak originPage] outcome in
            guard let self else { return }
            switch outcome {
            case let .prepared(prepared):
                presentCashOutConfirm(prepared, screen: screen, originPage: originPage)
            case .slippage:
                presentOrderNotPlacedAlert { [weak self, weak originPage] in
                    guard let self else { return }
                    openCashOut(preparation.refreshed(screen), from: originPage)
                }
            }
        }
    }

    func resignTradeKeyboard() {
        tradeNavigationController?.view.endEditing(true)
        router.sheetPresenter.view.endEditing(true)
    }
}

private extension PerpsTradeCoordinator {
    // MARK: - Open Position (TK-1572)

    func presentOpenPosition(_ screen: PerpsMarketScreenContext, side: PerpsTradeSide) {
        let marketId = screen.marketId
        if openPositionFlow.composingMarketId != nil, tradeNavigationController?.presentingViewController == nil {
            Log.perps.w("open position flow lost its screen, resetting market=\(marketId)")
            openPositionFlow.close()
        }
        guard openPositionFlow.begin(marketId: marketId) else {
            Log.perps.i("open position ignored market=\(marketId) composing=\(String(describing: openPositionFlow.composingMarketId))")
            return
        }
        let viewModel = PerpsOpenPositionViewModel(
            marketId: marketId,
            side: side,
            service: tradingService,
            accountStore: walletDependencies.accountStore,
            marketsStore: perpsAssembly.marketsStore,
            rememberedLeverage: { [inputMemory = context.inputMemory] accountIndex in
                inputMemory.slot(accountIndex: accountIndex, marketId: marketId).leverage
            },
            format: format
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
                self?.tradeRunner.publish(.toast(.failure(TKLocales.Toast.serviceUnavailable)), marketId: marketId)
            }
        }
        viewModel.onDeposit = { [weak self] in
            self?.depositFromTrade(.openPosition)
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
                reviewerLoaded: viewModel?.reviewerLoaded ?? Empty().eraseToAnyPublisher(),
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
                onApply: { viewModel?.applyAutoClose($0, roiInput: $1) }
            )
        }
        viewModel.ensureAccountReady = { [weak self] in
            await self?.preparation.ensureAccountReady(onPasscodeEntered: {}) ?? false
        }
        viewModel.onReview = { [weak self, weak viewModel] context in
            self?.openConfirm(context: context, screen: screen, openFormViewModel: viewModel)
        }
        viewModel.onInvalidAutoClose = { [weak self, weak viewModel] invalid in
            guard let kind = invalid.confirmStaleKind else { return }
            self?.presentAutoCloseStaleAlert(
                kind: kind,
                onContinueWithout: { viewModel?.continueWithoutAutoClose(invalid) },
                onUpdate: { viewModel?.openAutoClose() },
                onClose: { viewModel?.requestAmountFocus() }
            )
        }
        viewModel.onOrderNotPlaced = { [weak self, weak viewModel] in
            self?.presentOrderNotPlacedAlert(
                onRetry: { viewModel?.review() },
                onClose: { viewModel?.requestAmountFocus() }
            )
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
        let viewModel = PerpsSetLimitPriceViewModel(context: context, marketsStore: perpsAssembly.marketsStore, format: format)
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
        reviewerLoaded: AnyPublisher<Void, Never>,
        onWillPresent: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
        onApply: @escaping (Double) -> Void
    ) {
        let viewModel = PerpsLeverageSheetViewModel(
            context: context,
            format: format,
            reviewLiquidation: reviewLiquidation,
            reviewerLoaded: reviewerLoaded
        )
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

    func inputMemory(marketId: Int64) -> PerpsTradeInputMemory.Slot? {
        guard case let .active(account) = walletDependencies.accountStore.currentWalletState() else { return nil }
        return context.inputMemory.slot(accountIndex: account.accountIndex, marketId: marketId)
    }

    func makeAutoCloseSheet(
        _ context: PerpsAutoCloseSheetContext
    ) -> (viewModel: PerpsAutoCloseSheetViewModel, bottomSheet: TKBottomSheetViewController) {
        let viewModel = PerpsAutoCloseSheetViewModel(
            context: context,
            format: format,
            marketsStore: perpsAssembly.marketsStore,
            inputMemory: inputMemory(marketId: context.marketId)
        )
        let liveSubtitle = viewModel.$referencePrice
            .map { [format] in "\(TKLocales.Perps.OpenPosition.price) \(format.price($0))" }
            .eraseToAnyPublisher()
        let bottomSheet = makeSheet(title: TKLocales.Perps.OpenPosition.autoCloseTitle, liveSubtitle: liveSubtitle) {
            PerpsAutoCloseSheetView(viewModel: viewModel)
        }
        bottomSheet.keyboardObserver = TKBottomSheetKeyboardObserver(bottomSheet: bottomSheet)
        return (viewModel, bottomSheet)
    }

    func openAutoCloseSheet(
        _ context: PerpsAutoCloseSheetContext,
        onWillPresent: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
        onApply: @escaping (PerpsAutoClose?, PerpsAutoCloseROIInput) -> Void
    ) {
        let (viewModel, bottomSheet) = makeAutoCloseSheet(context)
        bottomSheet.didClose = { _ in onDismiss() }
        viewModel.onApply = .draft { [weak bottomSheet] autoClose, roiInput in
            guard let bottomSheet else {
                onApply(autoClose, roiInput)
                onDismiss()
                return
            }
            Self.dismissSheet(bottomSheet) {
                onApply(autoClose, roiInput)
                onDismiss()
            }
        }
        viewModel.onClose = { [weak bottomSheet] in
            Self.dismissSheet(bottomSheet, completion: onDismiss)
        }
        presentSheet(bottomSheet, onWillPresent: onWillPresent)
    }

    // MARK: - Edit Position (TK-1578)

    func openSizeChange(_ screen: PerpsMarketScreenContext, direction: PerpsSizeChangeDirection) {
        guard let summary = screen.position, direction == .reduce || !isTradingRestricted() else { return }
        let marketId = screen.marketId
        let session = preparation.beginSizeChange(
            marketId: marketId,
            direction: direction,
            priceDecimals: screen.market.priceDecimals
        )
        let viewModel = PerpsSizeChangeViewModel(
            session: session,
            summary: summary,
            displayPrice: screen.market.price,
            sizeDecimals: screen.market.sizeDecimals,
            accountStore: walletDependencies.accountStore,
            marketsStore: perpsAssembly.marketsStore,
            loadLimits: { [tradingService] in try? await tradingService.sizeChangeLimits(marketId: marketId).get() },
            format: format
        )
        let navigationController = makeTradeNavigationController(
            rootViewController: PerpsAmountFormViewController(viewModel: viewModel)
        )

        viewModel.onClose = { [weak self] in
            guard let self, preparation.isCurrent(session) else { return }
            preparation.finishSizeChange(session)
            dismissTrade()
        }
        viewModel.onDeposit = { [weak self] in
            self?.depositFromTrade(.addToPosition)
        }
        viewModel.onOpenAutoClose = { [weak self, weak viewModel] context in
            self?.openAutoCloseSheet(
                context,
                onWillPresent: { viewModel?.suppressAmountFocus() },
                onDismiss: { viewModel?.requestAmountFocus() },
                onApply: { autoClose, roiInput in viewModel?.applyAutoClose(autoClose, roiInput: roiInput) }
            )
        }
        viewModel.onReview = { [weak self, weak viewModel] in
            guard let viewModel else { return }
            self?.reviewSizeChange(session: session, screen: screen, formViewModel: viewModel)
        }

        present(navigationController)
    }

    func reviewSizeChange(
        session: PerpsSizeChangeSession,
        screen: PerpsMarketScreenContext,
        formViewModel: PerpsSizeChangeViewModel
    ) {
        guard preparation.isCurrent(session) else { return }
        formViewModel.resolveAutoClose()
        guard let request = session.beginPreparation() else { return }
        prepareSizeChange(
            session: session,
            screen: screen,
            request: request,
            formViewModel: formViewModel
        ) { [weak self, weak formViewModel] in
            guard let self, let formViewModel, let tradeNavigationController else { return }
            pushSizeChangeConfirm(
                session: session,
                screen: screen,
                in: tradeNavigationController,
                formViewModel: formViewModel
            )
        }
    }

    func offerSizeChangeFix(
        _ error: PerpsTradingError,
        request: PerpsSizeChangeSession.PreparationRequest,
        session: PerpsSizeChangeSession,
        screen: PerpsMarketScreenContext,
        formViewModel: PerpsSizeChangeViewModel
    ) {
        switch error {
        case .slippageExceeded:
            presentOrderNotPlacedAlert(
                onRetry: { [weak self, weak formViewModel] in
                    guard let formViewModel else { return }
                    self?.reviewSizeChange(session: session, screen: screen, formViewModel: formViewModel)
                },
                onClose: { [weak formViewModel] in formViewModel?.requestAmountFocus() }
            )
        case let .invalidAutoClose(leg?):
            preparation.checkRefusedAutoClose(of: request, refused: leg, session: session) { [weak self, weak formViewModel] kind, remaining in
                self?.presentAutoCloseStaleAlert(
                    kind: kind,
                    onContinueWithout: { [weak self, weak formViewModel] in
                        guard let formViewModel else { return }
                        formViewModel.applyAutoClose(remaining)
                        self?.reviewSizeChange(session: session, screen: screen, formViewModel: formViewModel)
                    },
                    onUpdate: { [weak formViewModel] in formViewModel?.openAutoClose() },
                    onClose: { [weak formViewModel] in formViewModel?.requestAmountFocus() }
                )
            }
        default:
            formViewModel.requestAmountFocus()
        }
    }

    private func reprepareSizeChangeFromConfirm(
        session: PerpsSizeChangeSession,
        screen: PerpsMarketScreenContext,
        desiredAutoClose: PerpsAutoClose?,
        roiInput: PerpsAutoCloseROIInput? = nil,
        formViewModel: PerpsSizeChangeViewModel?,
        onPrepared: @escaping () -> Void
    ) {
        guard preparation.isCurrent(session),
              let request = session.beginRepreparation(desiredAutoClose: desiredAutoClose, roiInput: roiInput)
        else { return }
        prepareSizeChange(
            session: session,
            screen: screen,
            request: request,
            formViewModel: formViewModel,
            onPrepared: onPrepared,
            onFailureKeepingTrade: { navigationController in
                navigationController.popViewController(animated: true)
            }
        )
    }

    private func prepareSizeChange(
        session: PerpsSizeChangeSession,
        screen: PerpsMarketScreenContext,
        request: PerpsSizeChangeSession.PreparationRequest,
        formViewModel: PerpsSizeChangeViewModel?,
        onPrepared: @escaping @MainActor () -> Void,
        onFailureKeepingTrade: @escaping @MainActor (UINavigationController) -> Void = { _ in }
    ) {
        preparation.prepareSizeChange(
            session,
            request: request,
            isOnScreen: { [weak self] in self?.tradeNavigationController?.presentingViewController != nil }
        ) { [weak self, weak formViewModel] outcome in
            guard let self else { return }
            switch outcome {
            case .prepared:
                onPrepared()
            case .canceled:
                formViewModel?.requestAmountFocus()
            case .closeTrade:
                dismissTrade()
            case let .failed(error):
                if let tradeNavigationController {
                    onFailureKeepingTrade(tradeNavigationController)
                }
                if let formViewModel {
                    offerSizeChangeFix(error, request: request, session: session, screen: screen, formViewModel: formViewModel)
                }
            }
        }
    }

    func pushSizeChangeConfirm(
        session: PerpsSizeChangeSession,
        screen: PerpsMarketScreenContext,
        in navigationController: UINavigationController,
        formViewModel: PerpsSizeChangeViewModel
    ) {
        guard let viewModel = PerpsTradeConfirmViewModel(
            sizeChangeSession: session,
            sizeDecimals: screen.market.sizeDecimals,
            format: format,
            iconURL: screen.market.iconURL,
            marketsStore: perpsAssembly.marketsStore
        ) else {
            session.backToEditing()
            return
        }
        let viewController = PerpsTradeConfirmViewController(viewModel: viewModel)

        viewModel.onBack = { [weak self] in
            guard let self, preparation.backToEditing(session) else { return }
            tradeNavigationController?.popViewController(animated: true)
        }
        viewModel.onClose = { [weak self] in
            guard let self, preparation.isCurrent(session) else { return }
            preparation.finishSizeChange(session)
            dismissTrade()
        }
        viewModel.onConfirm = { [weak self, weak formViewModel] in
            guard let self, preparation.isCurrent(session), let prepared = session.beginConfirming() else { return }
            confirmSizeChange(prepared, session: session, screen: screen, formViewModel: formViewModel)
        }
        viewModel.onEditAutoClose = { [weak self, weak formViewModel] in
            await self?.editAutoCloseFromSizeChangeConfirm(session: session, screen: screen, formViewModel: formViewModel)
        }
        viewModel.onAutoCloseStale = { Self.showAutoCloseStaleToast($0) }
        viewModel.onRefreshReview = { [weak self] in
            await self?.preparation.refreshReview(of: session)
        }
        resignTradeKeyboard()
        navigationController.pushViewController(viewController, animated: true)
    }

    @MainActor
    func editAutoCloseFromSizeChangeConfirm(
        session: PerpsSizeChangeSession,
        screen: PerpsMarketScreenContext,
        formViewModel: PerpsSizeChangeViewModel?
    ) async {
        guard let prepared = session.prepared,
              session.phase == .reviewing,
              preparation.isCurrent(session)
        else { return }
        let referencePrice = await perpsAssembly.marketsStore.price(marketId: prepared.marketId)
            ?? prepared.review.entryPrice.new
        guard !Task.isCancelled, preparation.isCurrent(session), session.prepared?.operationId == prepared.operationId else { return }
        let leverage = prepared.review.leverage
            ?? preparation.refreshed(screen).position?.effectiveLeverage
            ?? 0
        let base = PerpsAutoCloseBase(
            side: prepared.review.side,
            entryPrice: prepared.review.entryPrice.new,
            leverage: leverage,
            priceDecimals: session.priceDecimals
        )
        let sheetContext = PerpsAutoCloseSheetContext(
            marketId: prepared.marketId,
            side: prepared.review.side,
            entryPrice: prepared.review.entryPrice.new,
            referencePrice: referencePrice,
            leverage: leverage,
            baseSize: prepared.review.baseSize.new,
            liquidationPrice: prepared.review.liquidationPrice?.new,
            priceDecimals: session.priceDecimals,
            draft: session.autoCloseROIInput.resolving(session.preparedAutoClose, on: base),
            roiInput: session.autoCloseROIInput,
            livePriceMarketId: prepared.marketId
        )
        openAutoCloseSheet(
            sheetContext,
            onWillPresent: {},
            onDismiss: {},
            onApply: { [weak self, weak formViewModel] autoClose, roiInput in
                guard let self else { return }
                reprepareSizeChangeFromConfirm(
                    session: session,
                    screen: screen,
                    desiredAutoClose: autoClose,
                    roiInput: roiInput,
                    formViewModel: formViewModel
                ) {}
            }
        )
    }

    func submitSizeChange(session: PerpsSizeChangeSession, screen: PerpsMarketScreenContext) {
        let direction = session.direction
        let submitted = preparation.submitSizeChange(session) { [weak self] in
            self?.presentOrderNotPlacedAlert { [weak self] in
                guard let self else { return }
                openSizeChange(preparation.refreshed(screen), direction: direction)
            }
        }
        guard submitted else { return }
        dismissTrade()
    }

    // MARK: - Resting limit orders

    func submitLimitOrderChange(
        _ intent: PerpsLimitOrderChangeIntent,
        cancellingFirst legKeys: [Int64] = [],
        confirm: @escaping @MainActor (PerpsPreparedLimitOrderChangeAction, _ submit: @escaping @MainActor () -> Void) -> Void
    ) {
        tradeRunner.changeLimitOrder(
            intent,
            cancellingFirst: legKeys,
            ensureAccountReady: { [weak self] in await self?.preparation.ensureAccountReady(onPasscodeEntered: $0) ?? false },
            passcodeProvider: passcodeProvider,
            confirm: confirm
        )
    }

    func presentLimitOrderChangeReview(
        _ prepared: PerpsPreparedLimitOrderChangeAction,
        market: PerpsAssetMarketSnapshot,
        removedLegs: [PerpsTriggerOrderSummary],
        onConfirm: @escaping @MainActor () -> Void
    ) {
        let text = PerpsAssetPageViewModel.limitOrderChangeReviewText(
            prepared.review,
            symbol: market.symbol,
            sizeDecimals: market.sizeDecimals,
            removedLegs: removedLegs,
            format: format
        )
        let alert = UIAlertController(title: text.title, message: text.message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: TKLocales.Actions.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: TKLocales.Perps.Confirm.confirm, style: .default) { _ in onConfirm() })
        router.sheetPresenter.present(alert, animated: true)
    }

    // MARK: - Adjust Margin (TK-1579)

    func openMarginChange(_ screen: PerpsMarketScreenContext, direction: PerpsMarginChangeDirection) {
        guard let summary = screen.position, direction == .reduce || !isTradingRestricted() else { return }
        preparation.resetMarginChange()
        let viewModel = PerpsMarginChangeViewModel(
            direction: direction,
            summary: summary,
            displayPrice: screen.market.price,
            accountStore: walletDependencies.accountStore,
            marketsStore: perpsAssembly.marketsStore,
            tradingService: tradingService,
            format: format
        )
        let navigationController = makeTradeNavigationController(
            rootViewController: PerpsAmountFormViewController(viewModel: viewModel)
        )

        viewModel.onClose = { [weak self] in
            self?.preparation.resetMarginChange()
            self?.dismissTrade()
        }
        viewModel.onDeposit = { [weak self] in
            self?.depositFromTrade(.addMargin)
        }
        viewModel.onReview = { [weak self, weak viewModel] intent in
            self?.reviewMarginChange(intent: intent, screen: screen, formViewModel: viewModel)
        }

        present(navigationController)
    }

    func reviewMarginChange(
        intent: PerpsMarginChangeIntent,
        screen: PerpsMarketScreenContext,
        formViewModel: PerpsMarginChangeViewModel?
    ) {
        preparation.prepareMarginChange(
            intent,
            isOnScreen: { [weak self] in self?.tradeNavigationController?.presentingViewController != nil }
        ) { [weak self, weak formViewModel] outcome in
            guard let self else { return }
            switch outcome {
            case let .prepared(prepared):
                guard let tradeNavigationController else { return }
                pushMarginChangeConfirm(prepared, screen: screen, in: tradeNavigationController)
            case .closeTrade:
                dismissTrade()
            case let .failed(warning):
                formViewModel?.reviewFailed(warning: warning)
            }
        }
    }

    func pushMarginChangeConfirm(
        _ prepared: PerpsPreparedMarginChangeAction,
        screen: PerpsMarketScreenContext,
        in navigationController: UINavigationController
    ) {
        let viewModel = PerpsTradeConfirmViewModel(
            marginChangeContext: PerpsMarginChangeConfirmContext(marketId: prepared.marketId, review: prepared.review),
            format: format,
            iconURL: screen.market.iconURL,
            marketsStore: perpsAssembly.marketsStore
        )
        let viewController = PerpsTradeConfirmViewController(viewModel: viewModel)

        viewModel.onBack = { [weak self] in
            self?.preparation.resetMarginChange()
            self?.tradeNavigationController?.popViewController(animated: true)
        }
        viewModel.onClose = { [weak self] in
            self?.preparation.resetMarginChange()
            self?.dismissTrade()
        }
        viewModel.onConfirm = { [weak self] in
            self?.submitMarginChange()
        }
        viewModel.onRefreshReview = { [weak self, weak viewModel] in
            guard let review = await self?.preparation.marginChangeReview() else { return }
            viewModel?.updateMarginChangeReview(review)
        }
        resignTradeKeyboard()
        navigationController.pushViewController(viewController, animated: true)
    }

    func submitMarginChange() {
        guard preparation.submitMarginChange() else { return }
        dismissTrade()
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

    func makeSheet(
        title: String,
        subtitle: String? = nil,
        liveSubtitle: AnyPublisher<String, Never>? = nil,
        @ViewBuilder content: () -> some View
    ) -> TKBottomSheetViewController {
        let contentViewController = TKBottomSheetScrollHostingController(
            title: title,
            subtitle: subtitle,
            liveSubtitle: liveSubtitle,
            content: content
        )
        return TKBottomSheetViewController(contentViewController: contentViewController)
    }

    func openConfirm(
        context: PerpsConfirmContext,
        screen: PerpsMarketScreenContext,
        openFormViewModel: PerpsOpenPositionViewModel?
    ) {
        resignTradeKeyboard()
        tradeNavigationController?.pushViewController(
            makeOpenConfirm(context: context, screen: screen, openFormViewModel: openFormViewModel),
            animated: true
        )
    }

    func makeOpenConfirm(
        context: PerpsConfirmContext,
        screen: PerpsMarketScreenContext,
        openFormViewModel: PerpsOpenPositionViewModel?,
        awaitsReview: Bool = false
    ) -> UIViewController {
        let viewModel = PerpsTradeConfirmViewModel(
            context: context,
            format: format,
            iconURL: screen.market.iconURL,
            marketsStore: perpsAssembly.marketsStore
        )
        attachLoyaltyReward(to: viewModel)
        if awaitsReview {
            viewModel.awaitReview()
        }
        let viewController = PerpsTradeConfirmViewController(viewModel: viewModel)

        viewModel.onBack = { [weak self] in
            guard let self, let navigationController = tradeNavigationController else { return }
            if navigationController.viewControllers.count > 1 {
                navigationController.popViewController(animated: true)
            } else {
                closeOpenPositionFlow()
            }
        }
        viewModel.onClose = { [weak self] in
            self?.closeOpenPositionFlow()
        }
        viewModel.onConfirm = { [weak self, weak viewModel, weak openFormViewModel] in
            guard let viewModel, let context = viewModel.openConfirmContext else { return }
            self?.confirmOpen(context, screen: screen, openFormViewModel: openFormViewModel, viewModel: viewModel)
        }
        let marketId = context.intent.marketId
        viewModel.onSwipeBegan = { [tradingService] in
            tradingService.warmSubmit(marketId: marketId)
        }
        viewModel.onSwipeAbandoned = { [tradingService] in
            tradingService.dropWarmSubmit(marketId: marketId)
        }
        viewModel.onEditAutoClose = { [weak self, weak viewModel, weak openFormViewModel] in
            await self?.editAutoCloseFromOpenConfirm(
                viewModel: viewModel,
                openFormViewModel: openFormViewModel
            )
        }
        viewModel.onAutoCloseStale = { Self.showAutoCloseStaleToast($0) }
        viewModel.onRefreshReview = { [weak self, weak viewModel] in
            guard let context = viewModel?.openConfirmContext,
                  let read = await self?.preparation.openReview(for: context)
            else { return }
            switch read {
            case let .success(review):
                viewModel?.updateOpenReview(review, for: context.intent)
            case let .failure(error):
                // A screen still waiting for figures of its own has nothing to fall back on;
                // a later failed refresh keeps the figures on screen.
                guard viewModel?.awaitsReview == true else { return }
                self?.closeOpenPositionFlow { [weak self] in
                    self?.tradeRunner.publish(
                        .toast(.failure(PerpsTradingErrorText.message(for: error, fallback: TKLocales.Toast.serviceUnavailable))),
                        marketId: context.intent.marketId
                    )
                }
            }
        }
        return viewController
    }

    @MainActor
    func editAutoCloseFromOpenConfirm(
        viewModel: PerpsTradeConfirmViewModel?,
        openFormViewModel: PerpsOpenPositionViewModel?
    ) async {
        guard let viewModel,
              let context = await viewModel.autoCloseEditingContext(preview: { [tradingService] intent in
                  await tradingService.previewOpenMarket(intent)
              })
        else { return }
        let marketPrice = await perpsAssembly.marketsStore.price(marketId: context.intent.marketId)
        guard !Task.isCancelled, viewModel.isConfirmationEnabled, viewModel.openConfirmContext?.intent == context.intent else { return }
        let referencePrice = marketPrice
            ?? context.review.entryPrice
            ?? 0
        let roiInput = openFormViewModel?.autoCloseROIInput ?? .none
        let sheetContext = context.autoCloseSheetContext(referencePrice: referencePrice, roiInput: roiInput)
        openAutoCloseSheet(
            sheetContext,
            onWillPresent: {},
            onDismiss: {},
            onApply: { [weak viewModel, weak openFormViewModel] autoClose, roiInput in
                openFormViewModel?.applyAutoClose(autoClose, roiInput: roiInput)
                viewModel?.updateOpenAutoClose(autoClose, roiInput: roiInput, review: context.review)
            }
        )
    }

    func confirmOpen(
        _ context: PerpsConfirmContext,
        screen: PerpsMarketScreenContext,
        openFormViewModel: PerpsOpenPositionViewModel?,
        viewModel: PerpsTradeConfirmViewModel?
    ) {
        preparation.checkAutoClose(of: context) { [weak self, weak openFormViewModel, weak viewModel] check in
            guard let self else { return }
            switch check {
            case .valid:
                submit(context: context, screen: screen, confirmationViewModel: viewModel)
            case let .stale(kind, remaining):
                presentAutoCloseStaleAlert(
                    kind: kind,
                    onContinueWithout: { [weak openFormViewModel, weak viewModel] in
                        openFormViewModel?.applyAutoClose(remaining)
                        viewModel?.updateOpenAutoClose(remaining)
                        viewModel?.restoreConfirmation()
                    },
                    onUpdate: { [weak self, weak openFormViewModel, weak viewModel] in
                        viewModel?.restoreConfirmation()
                        guard let openFormViewModel else {
                            viewModel?.editAutoClose()
                            return
                        }
                        self?.tradeNavigationController?.popViewController(animated: true)
                        openFormViewModel.openAutoClose()
                    },
                    onClose: { [weak viewModel] in viewModel?.restoreConfirmation() }
                )
            }
        }
    }

    func confirmSizeChange(
        _ prepared: PerpsPreparedSizeChangeAction,
        session: PerpsSizeChangeSession,
        screen: PerpsMarketScreenContext,
        formViewModel: PerpsSizeChangeViewModel?
    ) {
        preparation.checkAutoClose(of: session, prepared: prepared) { [weak self, weak formViewModel] check in
            guard let self else { return }
            switch check {
            case .valid:
                submitSizeChange(session: session, screen: screen)
            case let .stale(kind, remaining):
                presentAutoCloseStaleAlert(
                    kind: kind,
                    onContinueWithout: { [weak self, weak formViewModel] in
                        guard let self else { return }
                        session.cancelConfirming()
                        reprepareSizeChangeFromConfirm(
                            session: session,
                            screen: screen,
                            desiredAutoClose: remaining,
                            formViewModel: formViewModel
                        ) {}
                    },
                    onUpdate: { [weak self, weak formViewModel] in
                        guard let self, preparation.backToEditing(session) else { return }
                        tradeNavigationController?.popViewController(animated: true)
                        formViewModel?.openAutoClose()
                    },
                    onClose: { session.cancelConfirming() }
                )
            }
        }
    }

    func presentOrderNotPlacedAlert(onRetry: @escaping () -> Void, onClose: (() -> Void)? = nil) {
        var retryButton = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
        retryButton.content = TKButton.Configuration.Content(
            title: .plainString(TKLocales.Perps.Confirm.tryAgain)
        )

        let viewController = InfoPopupBottomSheetViewController()
        let bottomSheet = TKBottomSheetViewController(contentViewController: viewController)
        var actionHandled = false
        bottomSheet.didClose = { _ in
            if !actionHandled { onClose?() }
        }
        retryButton.action = { [weak bottomSheet] in
            actionHandled = true
            bottomSheet?.dismiss { onRetry() }
        }
        viewController.configuration = InfoPopupBottomSheetViewController.Configuration(
            image: .TKUIKit.Icons.Size84.exclamationmarkCircle,
            imageTintColor: .Icon.secondary,
            title: TKLocales.Perps.Confirm.orderNotPlacedTitle,
            caption: TKLocales.Perps.Confirm.orderNotPlacedCaption,
            bodyContent: nil,
            buttons: [retryButton]
        )
        viewController.headerConfiguration = TKBottomSheetHeaderConfiguration(
            title: .empty,
            contentInsets: UIEdgeInsets(top: 16, left: 16, bottom: 0, right: 16)
        )
        bottomSheet.present(fromViewController: router.sheetPresenter)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
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
        bottomSheet.present(fromViewController: router.sheetPresenter)
    }

    static func showAutoCloseStaleToast(_ kind: PerpsAutoCloseValidation.ConfirmStaleKind) {
        let title = switch kind {
        case .takeProfit: TKLocales.Perps.Confirm.takeProfitNeedsUpdateToast
        case .stopLoss: TKLocales.Perps.Confirm.stopLossNeedsUpdateToast
        case .autoClose: TKLocales.Perps.Confirm.autoCloseNeedsUpdateTitle
        }
        ToastPresenter.showToast(configuration: .init(
            title: title,
            icon: .TKUIKit.Icons.Size16.exclamationMarkCircle,
            iconTintColor: .Icon.secondary
        ))
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

    func submit(
        context: PerpsConfirmContext,
        screen: PerpsMarketScreenContext,
        confirmationViewModel: PerpsTradeConfirmViewModel?
    ) {
        inputMemory(marketId: context.intent.marketId)?.rememberLeverage(context.intent.leverage)
        tradeRunner.open(
            context,
            ensureAccountReady: { [weak self] in await self?.preparation.ensureAccountReady(onPasscodeEntered: $0) ?? false },
            passcodeProvider: passcodeProvider,
            onBeginOpening: { [weak self] in self?.dismissTrade() },
            onCanceled: { [weak confirmationViewModel] in confirmationViewModel?.restoreConfirmation() },
            onSlippage: { [weak self] in
                self?.presentOrderNotPlacedAlert { self?.retryOpen(context, screen: screen) }
            }
        )
    }

    // MARK: - Cash Out (TK-1577)

    private func presentCashOutConfirm(
        _ prepared: PerpsPreparedCloseAction,
        screen: PerpsMarketScreenContext,
        originPage: UIViewController?
    ) {
        let viewModel = PerpsTradeConfirmViewModel(
            closeContext: PerpsCloseConfirmContext(
                marketId: prepared.marketId,
                sizeDecimals: screen.market.sizeDecimals,
                review: prepared.review
            ),
            format: format,
            iconURL: screen.market.iconURL,
            marketsStore: perpsAssembly.marketsStore
        )
        attachLoyaltyReward(to: viewModel)
        let navigationController = makeTradeNavigationController(
            rootViewController: PerpsTradeConfirmViewController(viewModel: viewModel)
        )

        viewModel.onBack = { [weak self] in
            self?.cancelCashOut()
        }
        viewModel.onClose = { [weak self] in
            self?.cancelCashOut()
        }
        viewModel.onConfirm = { [weak self, weak originPage] in
            self?.submitCashOut(screen, from: originPage)
        }
        viewModel.onRefreshReview = { [weak self, weak viewModel] in
            guard let review = await self?.preparation.closeReview() else { return }
            viewModel?.updateCloseReview(review)
        }

        present(navigationController)
    }

    private func attachLoyaltyReward(to viewModel: PerpsTradeConfirmViewModel) {
        viewModel.onOpenLoyalty = { [weak self] in self?.onOpenLoyalty?() }
        viewModel.loyaltyReward = walletDependencies.loyalty?.reward
    }

    func cancelCashOut() {
        guard preparation.cancelClose() else { return }
        dismissTrade()
    }

    func submitCashOut(_ screen: PerpsMarketScreenContext, from originPage: UIViewController?) {
        let submitted = preparation.submitClose { [weak self, weak originPage] in
            self?.presentOrderNotPlacedAlert { [weak self] in
                guard let self else { return }
                openCashOut(preparation.refreshed(screen), from: originPage)
            }
        }
        guard submitted else { return }
        dismissTrade()
    }

    func closeOpenPositionFlow(completion: (() -> Void)? = nil) {
        openPositionFlow.close()
        dismissTrade(completion: completion)
    }

    func dismissTrade(completion: (() -> Void)? = nil) {
        guard let tradeNavigationController,
              tradeNavigationController.presentingViewController != nil,
              !tradeNavigationController.isBeingDismissed
        else {
            completion?()
            return
        }
        tradeNavigationController.dismiss(animated: true, completion: completion)
    }

    func depositFromTrade(_ entry: PerpsDepositEntry) {
        openDeposit(entry, tradeNavigationController)
    }

    func present(_ viewController: UIViewController) {
        router.sheetPresenter.present(viewController, animated: true)
    }

    func isTradingRestricted() -> Bool {
        guard perpsAssembly.access == .restricted else { return false }
        presentSheet(PerpsRegionRestrictionSheet.make(), onWillPresent: {})
        return true
    }

    func presentRegionRefusal(marketId: Int64) {
        guard regionRefusalSheet == nil else { return }
        regionRefusalsAwaitingSheet.append(marketId)
        guard regionRefusalsAwaitingSheet.count == 1 else { return }
        Task { [weak self] in
            guard let self else { return }
            let presenter = await sheetPresenter()
            let refusedMarkets = regionRefusalsAwaitingSheet
            regionRefusalsAwaitingSheet = []
            guard let presenter else {
                let toast = PerpsAssetPageTradeToast.failure(PerpsTradingErrorText.message(for: .regionUnavailable))
                for marketId in refusedMarkets {
                    tradeRunner.publish(.toast(toast), marketId: marketId)
                }
                return
            }
            let sheet = PerpsRegionRestrictionSheet.make()
            regionRefusalSheet = sheet
            sheet.willPresent = { [weak self] in self?.resignTradeKeyboard() }
            sheet.present(fromViewController: presenter)
        }
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
        bottomSheet.present(fromViewController: router.sheetPresenter)
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
}
