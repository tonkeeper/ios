import Combine
import PerpsModels
import SwiftUI
import TKCoordinator
import TKLocalize
import TKUIKit
import UIKit

public final class PerpsCoordinator: RouterCoordinator<NavigationControllerRouter> {
    public var didOpenDapp: ((URL, String?) -> Void)?
    public var didRequestLearnBasics: (() -> Void)?
    public var didRequestAddFunds: ((_ presentingViewController: UIViewController) -> Void)?
    public var didRequestAnotherWallet: (() -> Void)?
    public var termsOfServiceURL: URL?
    public var didOpenLoyalty: (() -> Void)?

    private let context: PerpsFlowContext
    private weak var fundingCoordinator: PerpsFundingCoordinator?
    private weak var tradeCoordinator: PerpsTradeCoordinator?

    public init(
        router: NavigationControllerRouter,
        perpsAssembly: any PerpsDependencies,
        walletDependencies: PerpsWalletDependencies
    ) {
        context = PerpsFlowContext(dependencies: perpsAssembly, wallet: walletDependencies)
        super.init(router: router)
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

    private var openPositionFlow: PerpsOpenPositionFlow {
        context.openPositionFlow
    }

    private var tradeRunner: PerpsTradeRunner {
        context.tradeRunner
    }

    private weak var assetPageViewModel: PerpsAssetPageViewModel?
    private weak var assetPageViewController: UIViewController?
    private var didPushFlowRoot = false
    private weak var flowRootViewController: UIViewController?
    private lazy var shareFlow = PerpsSharePositionFlow(format: format)
    private lazy var historyDetails = PerpsHistoryDetailsPresenter(
        marketsStore: perpsAssembly.marketsStore,
        format: format,
        shareFlow: shareFlow,
        onOpenLoyalty: { [weak self] in self?.didOpenLoyalty?() }
    )

    override public func start() {
        start(marketID: nil)
    }

    /// `fundingOperationId` opens the history in place of the perps screen, focused on that deposit or
    /// withdrawal: a second push in the same turn would break the first one's transition.
    public func start(marketID: Int64?, presentingAutoClose: Bool = false, fundingOperationId: String? = nil) {
        startFunding()
        startTrade()
        walletDependencies.accountStore.resolveIfNeeded()
        if let marketID {
            openAssetPage(marketId: marketID, presentingAutoClose: presentingAutoClose)
            return
        }
        if let fundingOperationId,
           let history = makeHistoryViewController(focusedFundingOperationId: fundingOperationId)
        {
            pushFlowViewController(history)
            return
        }

        let viewModel = PerpsViewModel(
            marketsStore: perpsAssembly.marketsStore,
            accountStore: walletDependencies.accountStore,
            access: { [perpsAssembly] in perpsAssembly.access },
            reloadAccess: { [perpsAssembly] in await perpsAssembly.reloadAccess() },
            format: format
        )
        perpsAssembly.observeAccess(viewModel) { viewModel in
            Task { @MainActor in viewModel.accessDidChange() }
        }
        let viewController = PerpsViewController(viewModel: viewModel)

        viewModel.onBack = { [weak self, weak viewController] in
            self?.goBack(from: viewController)
        }
        viewModel.onLearnBasics = { [weak self] in
            self?.didRequestLearnBasics?()
        }
        viewModel.onSearch = { [weak self] in
            self?.openSearch()
        }
        viewModel.onHistory = { [weak self] in
            self?.openHistory()
        }
        viewModel.onDeposit = { [weak self] in
            self?.fundingCoordinator?.openDeposit(from: .home)
        }
        viewModel.onWithdraw = { [weak self] in
            self?.fundingCoordinator?.openWithdraw()
        }
        viewModel.onRegionRestrictionInfo = { [weak self] in
            self?.presentSheet(PerpsRegionRestrictionSheet.make())
        }
        viewModel.withdrawStatus?.onOpenHistory = { [weak self] operationId in
            guard let self, let history = makeHistoryViewController(focusedFundingOperationId: operationId) else { return }
            router.push(viewController: history, animated: true)
        }
        viewModel.onSelectMarket = { [weak self] marketId in
            self?.openAssetPage(marketId: marketId)
        }

        pushFlowViewController(viewController)
    }

    var isFlowOnTop: Bool {
        guard router.rootViewController.presentedViewController == nil,
              let flowRootViewController
        else {
            return false
        }
        return router.rootViewController.viewControllers.contains { $0 === flowRootViewController }
    }

    public func isShowing(marketID: Int64?) -> Bool {
        guard router.rootViewController.presentedViewController == nil,
              let topViewController = router.rootViewController.topViewController
        else {
            return false
        }
        guard let marketID else {
            return topViewController is PerpsViewController<PerpsViewModel>
        }
        return topViewController === assetPageViewController && assetPageViewModel?.marketId == marketID
    }
}

private extension PerpsCoordinator {
    func startFunding() {
        let coordinator = PerpsFundingCoordinator(
            router: router,
            context: context,
            passcodeProvider: makePasscodeProvider(),
            presentSheet: { [weak self] in self?.presentSheet($0) },
            sheetPresenter: { [weak self] in await self?.settledSheetPresenter() }
        )
        coordinator.didRequestAddFunds = { [weak self] in self?.didRequestAddFunds?($0) }
        coordinator.didRequestAnotherWallet = { [weak self] in self?.didRequestAnotherWallet?() }
        addChild(coordinator)
        fundingCoordinator = coordinator
        coordinator.start()
    }

    func startTrade() {
        let coordinator = PerpsTradeCoordinator(
            router: router,
            context: context,
            passcodeProvider: makePasscodeProvider(),
            openDeposit: { [weak self] in self?.fundingCoordinator?.openDeposit(from: $0, on: $1) },
            sheetPresenter: { [weak self] in await self?.settledFlowPresenter() }
        )
        coordinator.onOpenLoyalty = { [weak self] in self?.didOpenLoyalty?() }
        addChild(coordinator)
        tradeCoordinator = coordinator
        coordinator.start()
    }

    func pushFlowViewController(_ viewController: UIViewController) {
        let isRoot = !didPushFlowRoot
        didPushFlowRoot = true
        if isRoot {
            flowRootViewController = viewController
        }
        router.push(
            viewController: viewController,
            animated: true,
            onPopClosures: isRoot ? { [weak self] in
                guard let self else { return }
                self.didFinish?(self)
            } : nil
        )
    }

    func goBack(from viewController: UIViewController?) {
        guard let navigationController = viewController?.navigationController else { return }
        guard navigationController.viewControllers.first === viewController,
              navigationController.presentingViewController != nil
        else {
            navigationController.popViewController(animated: true)
            return
        }
        navigationController.dismiss(animated: true)
        didFinish?(self)
    }

    func openHistory(marketId: Int64? = nil, focusedTransactions: Set<String> = []) {
        guard let viewController = makeHistoryViewController(marketId: marketId, focusedTransactions: focusedTransactions) else {
            return
        }
        router.push(viewController: viewController, animated: true)
    }

    func makeHistoryViewController(
        marketId: Int64? = nil,
        focusedTransactions: Set<String> = [],
        focusedFundingOperationId: String? = nil
    ) -> UIViewController? {
        walletDependencies.makeHistory(
            marketId,
            focusedTransactions,
            focusedFundingOperationId,
            { [weak self] event in self?.openHistoryEvent(event) },
            { [weak self] url, title in self?.didOpenDapp?(url, title) }
        )
    }

    func openHistoryEvent(_ event: PerpsHistoryEvent) {
        historyDetails.present(event, from: router.sheetPresenter)
    }

    func openSearch() {
        let viewModel = PerpsSearchViewModel(
            repository: perpsAssembly.marketsRepository,
            marketsStore: perpsAssembly.marketsStore,
            format: format
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

    func openAssetPage(marketId: Int64, presentingAutoClose: Bool = false) {
        let viewModel = PerpsAssetPageViewModel(
            marketId: marketId,
            store: perpsAssembly.marketsStore,
            marketDetailsStore: perpsAssembly.makeMarketDetailsStore(),
            accountStore: walletDependencies.accountStore,
            openPositionFlow: openPositionFlow,
            tradeOutcomes: { [tradeRunner] in tradeRunner.outcomes(marketId: marketId) },
            format: format,
            loyalty: walletDependencies.loyalty
        )
        let chartViewModel = PerpsChartViewModel(
            marketId: marketId,
            service: perpsAssembly.chartService,
            format: format
        )
        let viewController = PerpsAssetPageViewController(viewModel: viewModel, chartViewModel: chartViewModel)

        viewModel.onBack = { [weak self, weak viewController] in
            self?.goBack(from: viewController)
        }
        viewModel.onPerpetualInfo = { [weak self] in
            self?.didRequestLearnBasics?()
        }
        viewModel.onRiskDisclosure = { [weak self] in
            self?.openRiskDisclosure()
        }
        viewModel.onTrade = { [weak self] screen, side in
            self?.tradeCoordinator?.openOpenPosition(screen, side: side)
        }
        viewModel.onEdit = { [weak self] screen, directions in
            self?.tradeCoordinator?.openEditPositionSheet(screen, directions: directions)
        }
        viewModel.onCashOut = { [weak self, weak viewController] screen in
            self?.tradeCoordinator?.openCashOut(screen, from: viewController)
        }
        viewModel.onAdjustMargin = { [weak self] screen in
            self?.tradeCoordinator?.openAdjustMarginSheet(screen)
        }
        viewModel.onAutoClose = { [weak self] screen in
            self?.tradeCoordinator?.openPositionAutoClose(screen)
        }
        viewModel.onLimitOrder = { [weak self, weak viewController] screen, order in
            guard let viewController else { return }
            self?.tradeCoordinator?.openLimitOrderActions(screen, order: order, presenter: viewController)
        }
        viewModel.onEditLimitOrder = { [weak self] screen, order in
            self?.tradeCoordinator?.editLimitOrder(screen, order: order)
        }
        viewModel.onCancelLimitOrder = { [weak self] marketId, order in
            self?.tradeCoordinator?.cancelLimitOrder(marketId: marketId, order: order)
        }
        viewModel.onShare = { [weak self] snapshot, updates in
            self?.openShareSheet(snapshot, updates: updates)
        }
        viewModel.onSeeAllHistory = { [weak self] marketId in
            self?.openHistory(marketId: marketId)
        }
        viewModel.onHistoryEvent = { [weak self] event in
            self?.openHistoryEvent(event)
        }
        viewModel.onLoadFailed = { [track = walletDependencies.track] in
            track(.tradingDataError(marketId: marketId))
        }
        viewModel.onOpenLoyalty = { [weak self] in
            self?.didOpenLoyalty?()
        }
        viewModel.presentsAutoCloseWhenReady = presentingAutoClose

        assetPageViewModel = viewModel
        assetPageViewController = viewController
        pushFlowViewController(viewController)
    }

    func openRiskDisclosure() {
        let bottomSheet = TKBottomSheetViewController(
            contentViewController: TKBottomSheetScrollHostingController(
                title: TKLocales.Perps.RiskDisclosure.title,
                subtitle: nil,
                liveSubtitle: nil
            ) {
                PerpsRiskDisclosureSheetView(keeperTermsURL: termsOfServiceURL)
            }
        )
        presentSheet(bottomSheet)
    }

    // MARK: - Share Position

    func openShareSheet(_ snapshot: SharePositionSnapshot, updates: AnyPublisher<SharePositionSnapshot, Never>) {
        shareFlow.present(snapshot, updates: updates, from: router.sheetPresenter) { [weak self] in
            self?.tradeCoordinator?.resignTradeKeyboard()
        }
    }

    func presentSheet(_ bottomSheet: TKBottomSheetViewController) {
        let existingWillPresent = bottomSheet.willPresent
        bottomSheet.willPresent = { [weak self] in
            existingWillPresent?()
            self?.tradeCoordinator?.resignTradeKeyboard()
        }
        bottomSheet.present(fromViewController: router.sheetPresenter)
    }

    func makePasscodeProvider() -> @Sendable () async -> String? {
        { [weak self] in
            await Task { @MainActor () -> String? in
                guard let self, let presenter = await self.settledSheetPresenter() else { return nil }
                return await self.walletDependencies.signingPasscode(
                    self,
                    ContainerViewControllerRouter(rootViewController: presenter)
                )
            }.value
        }
    }

    func settledFlowPresenter() async -> UIViewController? {
        guard let presenter = await settledSheetPresenter(), isFlowOnTop else { return nil }
        return presenter
    }

    func settledSheetPresenter() async -> UIViewController? {
        for _ in 0 ..< 60 {
            let presenter = router.sheetPresenter
            if presenter.view.window != nil, presenter.transitionCoordinator == nil, !presenter.isBeingDismissed {
                return presenter
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return nil
    }
}

extension NavigationControllerRouter {
    var sheetPresenter: UIViewController {
        rootViewController.topPresentedViewController
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
