import Combine
import PerpsModels
import SwiftUI
import TKCoordinator
import TKLocalize
import TKLogging
import TKUIKit
import UIKit

public final class PerpsCoordinator: RouterCoordinator<NavigationControllerRouter> {
    public var didOpenDapp: ((URL, String?) -> Void)?
    public var didRequestLearnBasics: (() -> Void)?
    public var didRequestAddFunds: ((_ presentingViewController: UIViewController) -> Void)?
    public var termsOfServiceURL: URL?

    private let perpsAssembly: any PerpsDependencies
    private let walletDependencies: PerpsWalletDependencies
    private var fundingRecoveryTask: Task<Void, Never>?
    /// The funding asset list being loaded for the picker; a tap meanwhile is ignored.
    private var fundingAssetsTask: Task<Void, Never>?
    private var depositKeyTask: Task<Void, Never>?

    public init(
        router: NavigationControllerRouter,
        perpsAssembly: any PerpsDependencies,
        walletDependencies: PerpsWalletDependencies
    ) {
        self.perpsAssembly = perpsAssembly
        self.walletDependencies = walletDependencies
        super.init(router: router)
    }

    deinit {
        fundingRecoveryTask?.cancel()
    }

    private var format: PerpsFormatting {
        perpsAssembly.format
    }

    private var tradingService: any PerpsTradingService {
        walletDependencies.tradingService
    }

    private static let fallbackPriceDecimals = 2

    private weak var assetPageViewModel: PerpsAssetPageViewModel?
    private weak var assetPageViewController: UIViewController?
    private var didPushFlowRoot = false
    private weak var tradeNavigationController: UINavigationController?
    private lazy var shareFlow = PerpsSharePositionFlow(format: format)
    private lazy var historyDetails = PerpsHistoryDetailsPresenter(
        marketsStore: perpsAssembly.marketsStore,
        format: format,
        shareFlow: shareFlow
    )

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
    /// reconciles — this is what keeps one of them from being started twice. Leaving
    /// a position is not held behind it: the service serializes signed actions, and
    /// a refusal there is a toast rather than a button that does nothing.
    private var marketsInFlight: Set<Int64> = [] {
        didSet {
            guard let assetPageViewModel else { return }
            assetPageViewModel.isLimitOrderBusy = isMarketBusy(assetPageViewModel.marketId)
        }
    }

    private let accountActivation = PerpsAccountActivation()

    private func openPositionSummary(marketId: Int64) -> PerpsPositionSummary? {
        guard case let .open(summary) = walletDependencies.accountStore.lifecycle(marketId: marketId) else { return nil }
        return summary
    }

    private func isMarketBusy(_ marketId: Int64) -> Bool {
        marketsInFlight.contains(marketId)
    }

    override public func start() {
        start(marketID: nil)
    }

    /// `fundingOperationId` opens the history in place of the perps screen, focused on that deposit or
    /// withdrawal: a second push in the same turn would break the first one's transition.
    public func start(marketID: Int64?, presentingAutoClose: Bool = false, fundingOperationId: String? = nil) {
        if fundingRecoveryTask == nil {
            fundingRecoveryTask = Task { [recoverFunding = walletDependencies.recoverFunding] in
                await recoverFunding()
            }
        }
        observeAccount()
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
            format: format
        )
        let viewController = PerpsViewController(viewModel: viewModel)

        viewModel.onBack = { [weak viewController] in
            viewController?.navigationController?.popViewController(animated: true)
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
            self?.openDeposit()
        }
        viewModel.onWithdraw = { [weak self] in
            self?.openWithdraw()
        }
        viewModel.onOpenFunding = { [weak self] transactions in
            self?.openHistory(focusedTransactions: transactions)
        }
        viewModel.onSelectMarket = { [weak self] marketId in
            self?.openAssetPage(marketId: marketId)
        }

        pushFlowViewController(viewController)
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
    func observeAccount() {
        let accountStore = walletDependencies.accountStore
        accountStore.addChangeObserver(self) { observer in
            Task { @MainActor in observer.accountDidChange() }
        }
        accountStore.resolveIfNeeded()
    }

    @MainActor
    func accountDidChange() {
        if case let .active(account) = walletDependencies.accountStore.currentWalletState(), !account.needsActivation {
            accountActivation.accountConfirmed()
        }
    }

    @MainActor
    func ensureAccountReady(onPasscodeEntered: @escaping @MainActor () -> Void) async -> Bool {
        let accountStore = walletDependencies.accountStore
        let needsActivation = if case let .active(account) = accountStore.currentWalletState() {
            account.needsActivation
        } else {
            false
        }
        let activateAccount = walletDependencies.activateAccount
        return await accountActivation.ensureReady(needsActivation: needsActivation) { [weak self] in
            guard let self else { return false }
            switch await activateAccount(self, self.router, onPasscodeEntered) {
            case .activated:
                accountStore.refresh()
                return true
            case .canceled:
                return false
            case .failed:
                self.showBindFailureToast()
                return false
            }
        }
    }

    @MainActor
    func prepareSigned<Prepared>(
        _ prepare: () async -> Result<Prepared, PerpsTradingError>
    ) async -> Result<Prepared, PerpsTradingError> {
        guard await ensureAccountReady(onPasscodeEntered: {}) else { return .failure(.activationCanceled) }
        return await prepare()
    }

    func showBindFailureToast() {
        ToastPresenter.showToast(configuration: .init(title: TKLocales.Perps.Error.generic))
    }

    func openDeposit(on navigationController: UINavigationController? = nil) {
        guard depositKeyTask == nil else { return }
        guard let deposit = walletDependencies.makeDeposit() else {
            ToastPresenter.showToast(configuration: .init(title: TKLocales.Perps.DepositForm.unavailable))
            return
        }
        let passcodeProvider = makePasscodeProvider()
        guard !deposit.holdsTradingKey else {
            openDeposit(using: deposit, on: navigationController, passcodeProvider: passcodeProvider)
            return
        }
        depositKeyTask = Task { @MainActor [weak self] in
            defer { self?.depositKeyTask = nil }
            guard let passcode = await passcodeProvider() else { return }
            guard await deposit.keepTradingKey(passcode: passcode) else {
                self?.showBindFailureToast()
                return
            }
            self?.openDeposit(using: deposit, on: navigationController, passcodeProvider: { passcode })
        }
    }

    private func openDeposit(
        using deposit: any PerpsDepositing,
        on navigationController: UINavigationController?,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) {
        let viewModel = PerpsDepositAmountViewModel(
            config: PerpsFundingAmountConfig(
                title: TKLocales.Perps.DepositForm.title,
                asset: { deposit.source },
                initialUnit: .token,
                fixedUsdPrice: nil,
                loadBalance: { await deposit.loadBalance() },
                loadLimit: { await deposit.loadLimit() },
                limitIsMaxOnly: true,
                loadMinimum: { [format] in
                    await deposit.loadMinimum().flatMap { minimum in
                        PerpsDepositErrorText.text(for: .belowMinimum(usd: minimum.usd), format: format)
                            .map { PerpsFundingMinimum(amount: minimum.amount, text: $0) }
                    }
                },
                loadPreferredAsset: { await deposit.availableSources().largestHolding },
                selectAsset: { deposit.selectSource(assetId: $0.source.assetId) },
                review: { try await deposit.review(amount: $0) },
                errorText: { [format] in PerpsDepositErrorText.text(for: deposit.message(for: $0), format: format) }
            ),
            format: format,
            loadPendingReview: { try await deposit.pendingReview() },
            pendingNotice: TKLocales.Perps.DepositForm.resumingPayment
        )
        let viewController = PerpsAmountFormViewController(fundingViewModel: viewModel)
        viewModel.onClose = { [weak viewController] in
            viewController?.navigationController?.popViewController(animated: true)
        }
        viewModel.onAddFunds = { [weak self, weak viewController] in
            guard let viewController else { return }
            self?.didRequestAddFunds?(viewController)
        }
        viewModel.onChooseAsset = { [weak self, weak viewModel, weak viewController] asset in
            guard let self, let viewController else { return }
            chooseFundingAsset(
                selected: asset,
                subtitle: TKLocales.Perps.Funding.convertedToUsd,
                amountViewController: viewController,
                loadOptions: { await deposit.availableSources() },
                row: { [format] option in
                    Self.assetRow(option, balanceText: option.balance.flatMap { format.fundingBalance($0, symbol: option.source.symbol) })
                },
                onSelect: { option in
                    deposit.selectSource(assetId: option.source.assetId)
                    viewModel?.assetDidChange(balance: option.balance)
                },
                onDismiss: { viewModel?.requestFocusOnAppear() }
            )
        }
        viewModel.onReviewed = { [weak self, weak viewModel, weak viewController] reviewed in
            guard let navigationController = viewController?.navigationController,
                  navigationController.topViewController === viewController else { return }
            self?.openDepositConfirm(
                reviewed: reviewed,
                deposit: deposit,
                balance: viewModel?.balance,
                on: navigationController,
                passcodeProvider: passcodeProvider
            )
        }
        push(viewController, on: navigationController)
    }

    /// One list load at a time: a second tap while it loads would stack a second sheet.
    /// A pick switches the open screen in place: a fresh screen would slide in over the
    /// closing sheet and start from an empty balance.
    private func chooseFundingAsset(
        selected: PerpsFundingAssetRow,
        subtitle: String?,
        amountViewController: UIViewController,
        loadOptions: @escaping @MainActor () async -> [PerpsDepositSourceOption],
        row: @escaping (PerpsDepositSourceOption) -> PerpsFundingAssetRow,
        onSelect: @escaping (PerpsDepositSourceOption) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        guard fundingAssetsTask == nil else { return }
        fundingAssetsTask = Task { @MainActor [weak self, weak amountViewController] in
            let options = await loadOptions()
            guard let self else { return }
            fundingAssetsTask = nil
            guard !Task.isCancelled, !options.isEmpty, let amountViewController,
                  amountViewController.navigationController?.topViewController === amountViewController
            else { return }
            let assets = options.map(row)
            weak var bottomSheet: TKBottomSheetViewController?
            let sheet = makeSheet(
                title: TKLocales.Multichain.AssetPicker.chooseTitle,
                subtitle: subtitle
            ) {
                PerpsFundingAssetSheetView(assets: assets, selected: selected) { asset in
                    if asset.assetId != selected.assetId,
                       let option = options.first(where: { $0.source.assetId == asset.assetId })
                    {
                        onSelect(option)
                    }
                    Self.dismissSheet(bottomSheet, completion: onDismiss)
                }
            }
            sheet.didClose = { _ in onDismiss() }
            bottomSheet = sheet
            presentSheet(sheet, onWillPresent: {})
        }
    }

    private static func assetRow(_ option: PerpsDepositSourceOption, balanceText: String?) -> PerpsFundingAssetRow {
        PerpsFundingAssetRow(
            assetId: option.source.assetId,
            symbol: option.source.symbol,
            network: option.source.network,
            iconURL: option.balance?.iconURL,
            balanceText: balanceText
        )
    }

    func openDepositConfirm(
        reviewed: PerpsReviewedDeposit,
        deposit: any PerpsDepositing,
        balance: PerpsFundingBalance?,
        on navigationController: UINavigationController?,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) {
        let viewModel = PerpsDepositConfirmViewModel(
            reviewed: reviewed,
            walletName: deposit.walletName,
            source: deposit.source,
            balance: balance,
            format: format,
            message: { deposit.message(for: $0) },
            passcodeProvider: passcodeProvider,
            requote: reviewed.terms.resumesPayment ? nil : { [amount = reviewed.terms.sourceAmount] in
                try await deposit.review(amount: amount)
            }
        )
        let viewController = PerpsTradeConfirmViewController(viewModel: viewModel)
        viewModel.onBack = { [weak viewController] in
            viewController?.navigationController?.popViewController(animated: true)
        }
        viewModel.onClose = { [weak self, weak viewController] in
            self?.dismissFunding(from: viewController)
        }
        viewModel.onPaid = { [weak self, weak viewController] outcome in
            guard let self else { return }
            switch outcome {
            case .authorizationRequired:
                ToastPresenter.showToast(configuration: .init(title: TKLocales.Perps.DepositForm.resumingPayment))
                viewController?.navigationController?.popViewController(animated: true)
                Task { [refreshFunding = walletDependencies.refreshFunding] in await refreshFunding() }
            case .registered:
                // The deposit is there to trade with: the user stays where it was started.
                dismissFunding(from: viewController)
                ToastPresenter.showToast(configuration: .init(
                    title: TKLocales.Perps.Toast.depositInProgress,
                    icon: .TKUIKit.Icons.Size16.checkmarkCircle,
                    iconTintColor: .Accent.green
                ))
                Task { [refreshFunding = walletDependencies.refreshFunding] in await refreshFunding() }
            }
        }
        push(viewController, on: navigationController)
    }

    func openWithdraw() {
        guard let withdraw = walletDependencies.makeWithdraw() else { return }
        openWithdraw(using: withdraw, on: nil)
    }

    private func openWithdraw(using withdraw: any PerpsWithdrawing, on navigationController: UINavigationController?) {
        let viewModel = PerpsWithdrawAmountViewModel(
            config: PerpsFundingAmountConfig(
                title: TKLocales.Perps.WithdrawForm.title,
                // The amount is typed in the Perps balance, USDC bridged in from Ethereum; the row
                // shows the destination instead.
                asset: { PerpsDepositSource(assetId: "lighter/mainnet/usdc", symbol: "USDC", decimals: 6, network: .ethereum) },
                displayAsset: { balance in
                    let destination = withdraw.destination
                    return PerpsFundingAssetRow(
                        assetId: destination.assetId,
                        symbol: destination.symbol,
                        network: destination.network,
                        iconURL: balance?.iconURL,
                        balanceText: nil
                    )
                },
                initialUnit: .usd,
                // The Perps balance is USDC counted as dollars.
                fixedUsdPrice: 1,
                loadBalance: { await withdraw.loadBalance() },
                loadLimit: nil,
                requiresLimit: true,
                review: { try await withdraw.review(amount: $0) },
                errorText: { PerpsWithdrawErrorText.text(for: withdraw.message(for: $0)) }
            ),
            format: format
        )
        let viewController = PerpsAmountFormViewController(fundingViewModel: viewModel)
        viewModel.onClose = { [weak viewController] in
            viewController?.navigationController?.popViewController(animated: true)
        }
        viewModel.onChooseAsset = { [weak self, weak viewModel, weak viewController] asset in
            guard let self, let viewController else { return }
            chooseFundingAsset(
                selected: asset,
                subtitle: nil,
                amountViewController: viewController,
                loadOptions: { await withdraw.availableDestinations() },
                row: { Self.assetRow($0, balanceText: nil) },
                onSelect: { option in
                    withdraw.selectDestination(assetId: option.source.assetId)
                    // The amount is drawn from the Perps balance, which no destination changes.
                    let balance = viewModel?.balance.map {
                        PerpsFundingBalance(amount: $0.amount, usdPrice: $0.usdPrice, iconURL: option.balance?.iconURL)
                    }
                    viewModel?.assetDidChange(balance: balance)
                },
                onDismiss: { viewModel?.requestFocusOnAppear() }
            )
        }
        viewModel.onReviewed = { [weak self, weak viewModel, weak viewController] reviewed in
            guard let navigationController = viewController?.navigationController,
                  navigationController.topViewController === viewController else { return }
            self?.openWithdrawConfirm(
                reviewed: reviewed,
                withdraw: withdraw,
                balance: viewModel?.balance,
                on: navigationController
            )
        }
        push(viewController, on: navigationController)
    }

    private func openWithdrawConfirm(
        reviewed: PerpsReviewedWithdraw,
        withdraw: any PerpsWithdrawing,
        balance: PerpsFundingBalance?,
        on navigationController: UINavigationController?
    ) {
        let viewModel = PerpsWithdrawConfirmViewModel(
            reviewed: reviewed,
            destination: withdraw.destination,
            balance: balance,
            format: format,
            message: { withdraw.message(for: $0) },
            passcodeProvider: makePasscodeProvider(),
            requote: reviewed.terms.requestedAmount.map { amount in { try await withdraw.review(amount: amount) } }
        )
        let viewController = PerpsTradeConfirmViewController(viewModel: viewModel)
        viewModel.onBack = { [weak viewController] in
            viewController?.navigationController?.popViewController(animated: true)
        }
        viewModel.onClose = { [weak self, weak viewController] in
            self?.dismissFunding(from: viewController)
        }
        viewModel.onPaid = { [weak self, weak viewController] operationId in
            guard let self else { return }
            // Nothing is left to do in perps: only the history shows where the money goes next.
            let history = makeHistoryViewController(withdrawalOperationId: operationId)
            dismissFunding(from: viewController, showing: history.map { [$0] } ?? [])
            Task { [refreshFunding = walletDependencies.refreshFunding] in await refreshFunding() }
        }
        push(viewController, on: navigationController)
    }

    private func push(_ viewController: UIViewController, on navigationController: UINavigationController?) {
        if let navigationController {
            navigationController.pushViewController(viewController, animated: true)
        } else {
            router.push(viewController: viewController, animated: true)
        }
    }

    /// Back past the amount screen too: the money it was showing is on its way, so
    /// returning to it would invite a second payment. `next` lands on top of where the flow
    /// was opened, so back from it returns there.
    private func dismissFunding(from viewController: UIViewController?, showing next: [UIViewController] = []) {
        guard let navigationController = viewController?.navigationController else { return }
        let remaining = navigationController.viewControllers.filter {
            !($0 is PerpsTradeConfirmViewController<PerpsDepositConfirmViewModel>)
                && !($0 is PerpsTradeConfirmViewController<PerpsWithdrawConfirmViewModel>)
                && !($0 is PerpsAmountFormViewController<PerpsDepositAmountViewModel, PerpsFundingAmountView<PerpsDepositAmountViewModel>>)
                && !($0 is PerpsAmountFormViewController<PerpsWithdrawAmountViewModel, PerpsFundingAmountView<PerpsWithdrawAmountViewModel>>)
        }
        navigationController.setViewControllers(remaining + next, animated: true)
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

    func openHistory(marketId: Int64? = nil, focusedTransactions: Set<String> = []) {
        guard let viewController = makeHistoryViewController(marketId: marketId, focusedTransactions: focusedTransactions) else {
            return
        }
        router.push(viewController: viewController, animated: true)
    }

    func makeHistoryViewController(
        marketId: Int64? = nil,
        focusedTransactions: Set<String> = [],
        withdrawalOperationId: String? = nil,
        focusedFundingOperationId: String? = nil
    ) -> UIViewController? {
        walletDependencies.makeHistory(
            marketId,
            focusedTransactions,
            withdrawalOperationId,
            focusedFundingOperationId,
            { [weak self] event in self?.openHistoryEvent(event) },
            { [weak self] url, title in self?.didOpenDapp?(url, title) }
        )
    }

    func openHistoryEvent(_ event: PerpsHistoryEvent) {
        historyDetails.present(event, from: sheetPresenter)
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
            format: format
        )
        let chartViewModel = PerpsChartViewModel(
            marketId: marketId,
            service: perpsAssembly.chartService,
            format: format
        )
        let viewController = PerpsAssetPageViewController(viewModel: viewModel, chartViewModel: chartViewModel)

        viewModel.onBack = { [weak viewController] in
            viewController?.navigationController?.popViewController(animated: true)
        }
        viewModel.onPerpetualInfo = { [weak self] in
            self?.didRequestLearnBasics?()
        }
        viewModel.onRiskDisclosure = { [weak self] in
            self?.openRiskDisclosure()
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
        viewModel.onEditLimitOrder = { [weak self] marketId, order in
            self?.editLimitOrder(marketId: marketId, order: order)
        }
        viewModel.onCancelLimitOrder = { [weak self] marketId, order in
            self?.cancelLimitOrder(marketId: marketId, order: order)
        }
        viewModel.onShare = { [weak self] snapshot in
            self?.openShareSheet(snapshot)
        }
        viewModel.onSeeAllHistory = { [weak self] marketId in
            self?.openHistory(marketId: marketId)
        }
        viewModel.onHistoryEvent = { [weak self] event in
            self?.openHistoryEvent(event)
        }
        viewModel.presentsAutoCloseWhenReady = presentingAutoClose
        viewModel.isLimitOrderBusy = isMarketBusy(marketId)

        assetPageViewModel = viewModel
        assetPageViewController = viewController
        pushFlowViewController(viewController)
    }

    func openRiskDisclosure() {
        weak var sheet: TKBottomSheetViewController?
        let bottomSheet = makeSheet(title: TKLocales.Perps.RiskDisclosure.title) {
            PerpsRiskDisclosureSheetView(keeperTermsURL: termsOfServiceURL) {
                Self.dismissSheet(sheet)
            }
        }
        sheet = bottomSheet
        presentSheet(bottomSheet, onWillPresent: {})
    }

    // MARK: - Open Position (TK-1572)

    func openOpenPosition(marketId: Int64, side: PerpsTradeSide) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard await !tradingService.marketsBlockedByPending().contains(marketId) else {
                Log.perps.w("open position refused, unresolved pending on market=\(marketId)")
                assetPageViewModel?.showTradeResult(
                    .failure(PerpsTradingErrorText.message(for: .operationInProgress))
                )
                return
            }
            presentOpenPosition(marketId: marketId, side: side)
        }
    }

    func presentOpenPosition(marketId: Int64, side: PerpsTradeSide) {
        if case .composing = openPositionFlow.phase, tradeNavigationController?.presentingViewController == nil {
            Log.perps.w("open position flow lost its screen, resetting market=\(marketId)")
            openPositionFlow.close()
        }
        guard openPositionFlow.begin(marketId: marketId) else {
            Log.perps.i("open position ignored market=\(marketId) phase=\(openPositionFlow.phase)")
            return
        }
        let viewModel = PerpsOpenPositionViewModel(
            marketId: marketId,
            side: side,
            service: tradingService,
            accountStore: walletDependencies.accountStore,
            marketsStore: perpsAssembly.marketsStore,
            initialLeverage: Self.defaultInitialLeverage,
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
                self?.assetPageViewModel?.showTradeResult(.failure(TKLocales.Toast.serviceUnavailable))
            }
        }
        viewModel.onDeposit = { [weak self] in
            self?.openDeposit(on: self?.tradeNavigationController)
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
            await self?.ensureAccountReady(onPasscodeEntered: {}) ?? false
        }
        viewModel.onReview = { [weak self, weak viewModel] context in
            self?.openConfirm(context: context, openFormViewModel: viewModel)
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

    func autoCloseInputMemory(marketId: Int64) -> PerpsAutoCloseInputMemory.Slot? {
        guard case let .active(account) = walletDependencies.accountStore.currentWalletState() else { return nil }
        return PerpsAutoCloseInputMemory.shared.slot(accountIndex: account.accountIndex, marketId: marketId)
    }

    func makeAutoCloseSheet(
        _ context: PerpsAutoCloseSheetContext
    ) -> (viewModel: PerpsAutoCloseSheetViewModel, bottomSheet: TKBottomSheetViewController) {
        let viewModel = PerpsAutoCloseSheetViewModel(
            context: context,
            format: format,
            marketsStore: perpsAssembly.marketsStore,
            inputMemory: autoCloseInputMemory(marketId: context.marketId)
        )
        let liveSubtitle = viewModel.$referencePrice
            .map { [format] in "\(TKLocales.Perps.OpenPosition.price) \(format.usd($0))" }
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
            restingTriggerOrders: walletDependencies.accountStore.marketExtras(marketId: marketId)?.triggerOrders ?? []
        )
        sizeChangeSession = session
        let viewModel = PerpsSizeChangeViewModel(
            session: session,
            summary: summary,
            displayPrice: market.flatMap { $0.hasPrice ? $0.price : nil } ?? lastTradePrice,
            sizeDecimals: market.map { Int($0.sizeDecimals) } ?? 2,
            accountStore: walletDependencies.accountStore,
            marketsStore: perpsAssembly.marketsStore,
            format: format
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
            self?.openDeposit(on: self?.tradeNavigationController)
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
            self?.reviewSizeChange(session: session, formViewModel: viewModel)
        }

        present(navigationController)
    }

    func reviewSizeChange(
        session: PerpsSizeChangeSession,
        formViewModel: PerpsSizeChangeViewModel
    ) {
        guard sizeChangeSession === session else { return }
        formViewModel.resolveAutoClose()
        guard let request = session.beginPreparation() else { return }
        prepareSizeChange(session: session, request: request, formViewModel: formViewModel) { [weak formViewModel] navigationController in
            guard let formViewModel else { return }
            await self.pushSizeChangeConfirm(
                session: session,
                in: navigationController,
                formViewModel: formViewModel
            )
        }
    }

    @MainActor
    func offerSizeChangeFix(
        _ error: PerpsTradingError,
        request: PerpsSizeChangeSession.PreparationRequest,
        session: PerpsSizeChangeSession,
        formViewModel: PerpsSizeChangeViewModel
    ) async {
        switch error {
        case .slippageExceeded:
            presentOrderNotPlacedAlert(
                onRetry: { [weak self, weak formViewModel] in
                    guard let formViewModel else { return }
                    self?.reviewSizeChange(session: session, formViewModel: formViewModel)
                },
                onClose: { [weak formViewModel] in formViewModel?.requestAmountFocus() }
            )
        case let .invalidAutoClose(leg?):
            guard case let .replace(autoClose) = request.intent.autoCloseUpdate else { return }
            let invalid = await PerpsAutoCloseValidation.refusedLegs(autoClose, refused: leg) { [tradingService] rest in
                await tradingService.previewSizeChange(request.intent.replacingAutoCloseUpdate(.replace(rest)))
            }
            guard sizeChangeSession === session, let kind = invalid.confirmStaleKind else { return }
            presentAutoCloseStaleAlert(
                kind: kind,
                onContinueWithout: { [weak self, weak formViewModel] in
                    guard let formViewModel else { return }
                    formViewModel.applyAutoClose(PerpsAutoCloseValidation.stripping(autoClose, removing: invalid))
                    self?.reviewSizeChange(session: session, formViewModel: formViewModel)
                },
                onUpdate: { [weak formViewModel] in formViewModel?.openAutoClose() },
                onClose: { [weak formViewModel] in formViewModel?.requestAmountFocus() }
            )
        default:
            formViewModel.requestAmountFocus()
        }
    }

    private func reprepareSizeChangeFromConfirm(
        session: PerpsSizeChangeSession,
        desiredAutoClose: PerpsAutoClose?,
        roiInput: PerpsAutoCloseROIInput? = nil,
        formViewModel: PerpsSizeChangeViewModel?,
        onPrepared: @escaping () -> Void
    ) {
        guard sizeChangeSession === session,
              let request = session.beginRepreparation(desiredAutoClose: desiredAutoClose, roiInput: roiInput)
        else { return }
        prepareSizeChange(
            session: session,
            request: request,
            formViewModel: formViewModel,
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
        formViewModel: PerpsSizeChangeViewModel?,
        onPrepared: @escaping @MainActor (UINavigationController) async -> Void,
        onFailureKeepingTrade: @escaping @MainActor (UINavigationController) -> Void = { _ in }
    ) {
        sizeChangePrepareTask?.cancel()
        sizeChangePrepareTask = Task { @MainActor [weak self, weak session, weak formViewModel] in
            guard let self, let session else { return }
            defer {
                if sizeChangeSession === session {
                    sizeChangePrepareTask = nil
                }
            }
            let result = await prepareSigned { await self.tradingService.prepareSizeChange(request.intent) }
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
                if session.cancelPreparation(request), session.phase == .editing {
                    formViewModel?.requestAmountFocus()
                }
            case let .failure(error):
                let failure = changePrepareFailure(error)
                guard session.failPreparation(request, warning: failure.warning) else { return }
                if failure.shouldCloseTrade {
                    finishSizeChangeSession(session)
                    dismissTrade()
                    refreshAfterTrade()
                } else {
                    onFailureKeepingTrade(navigationController)
                    if let formViewModel {
                        Task { @MainActor in
                            await self.offerSizeChangeFix(error, request: request, session: session, formViewModel: formViewModel)
                        }
                    }
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
            format: format,
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
            guard let self, sizeChangeSession === session, let prepared = session.beginConfirming() else { return }
            Task { @MainActor [weak self] in
                await self?.handleSizeChangeConfirm(prepared, session: session, formViewModel: formViewModel)
            }
        }
        viewModel.onEditAutoClose = { [weak self, weak formViewModel] in
            await self?.editAutoCloseFromSizeChangeConfirm(session: session, formViewModel: formViewModel)
        }
        viewModel.onAutoCloseStale = { Self.showAutoCloseStaleToast($0) }
        viewModel.onRefreshReview = { [weak self] in
            guard let self,
                  sizeChangeSession === session,
                  let prepared = session.prepared,
                  case let .success(review) = await tradingService.previewSizeChange(
                      prepared.intent.replacingAutoCloseUpdate(.unchanged)
                  )
            else { return }
            session.refreshReview(review, operationId: prepared.operationId)
        }
        resignTradeKeyboard()
        navigationController.pushViewController(viewController, animated: true)
    }

    @MainActor
    func editAutoCloseFromSizeChangeConfirm(
        session: PerpsSizeChangeSession,
        formViewModel: PerpsSizeChangeViewModel?
    ) async {
        guard let prepared = session.prepared,
              session.phase == .reviewing,
              sizeChangeSession === session
        else { return }
        let referencePrice = await perpsAssembly.marketsStore.price(marketId: prepared.marketId)
            ?? prepared.review.entryPrice.new
        guard !Task.isCancelled, sizeChangeSession === session, session.prepared?.operationId == prepared.operationId else { return }
        let leverage = prepared.review.leverage
            ?? openPositionSummary(marketId: prepared.marketId)?.effectiveLeverage
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
                    desiredAutoClose: autoClose,
                    roiInput: roiInput,
                    formViewModel: formViewModel
                ) {}
            }
        )
    }

    func submitSizeChange(session: PerpsSizeChangeSession) {
        guard sizeChangeSession === session,
              let prepared = session.beginSubmitting()
        else { return }
        walletDependencies.accountStore.beginAdjusting(
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
                onSlippage: { [weak self] in
                    Task { @MainActor in
                        await self?.openSizeChange(marketId: prepared.marketId, direction: prepared.intent.direction)
                    }
                },
                submit: { await self.tradingService.submit(prepared, passcodeProvider: self.makePasscodeProvider()) }
            )
        }
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

    // MARK: - Auto Close on a live position (TK-1580)

    /// The sheet's Set is the confirmation (no confirm screen in design): it
    /// prepares and submits in one go, shows the designed loading state, and
    /// the sheet closes only on a confirmed trigger-order delta.
    func openPositionAutoClose(marketId: Int64) {
        guard let summary = openPositionSummary(marketId: marketId) else { return }
        // The asset page holds the extras subscription open, so the resting legs
        // behind the prefill are the warm cache the row itself was drawn from.
        let resting = walletDependencies.accountStore.marketExtras(marketId: marketId)?.triggerOrders ?? []
        let context = PerpsAutoCloseSheetContext(
            marketId: marketId,
            side: summary.side,
            entryPrice: summary.entryPrice,
            referencePrice: assetPageViewModel?.lastMarkPrice ?? summary.entryPrice,
            leverage: summary.effectiveLeverage ?? 0,
            baseSize: summary.baseSize,
            liquidationPrice: summary.liquidationPrice > 0 ? summary.liquidationPrice : nil,
            priceDecimals: assetPageViewModel?.priceDecimals ?? Self.fallbackPriceDecimals,
            draft: PerpsAutoClose(triggerOrders: resting),
            livePriceMarketId: marketId
        )
        let (viewModel, bottomSheet) = makeAutoCloseSheet(context)
        viewModel.onApply = .submit { [weak self, weak bottomSheet] target in
            guard let self else { return .finished }
            return await submitAutoCloseChange(marketId: marketId, target: target, bottomSheet: bottomSheet)
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
        guard !isMarketBusy(marketId) else { return }
        let alert = UIAlertController(
            title: TKLocales.Perps.OrderType.limit,
            message: "\(TKLocales.Perps.Order.price) \(format.usd(order.limitPrice))",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: TKLocales.Actions.edit, style: .default) { [weak self] _ in
            self?.editLimitOrder(marketId: marketId, order: order)
        })
        alert.addAction(UIAlertAction(title: TKLocales.Perps.Order.cancel, style: .destructive) { [weak self] _ in
            self?.cancelLimitOrder(marketId: marketId, order: order)
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

    func editLimitOrder(marketId: Int64, order: PerpsLimitOrderSummary) {
        Task { @MainActor [weak self] in
            await self?.openLimitOrderEditor(marketId: marketId, order: order)
        }
    }

    func cancelLimitOrder(marketId: Int64, order: PerpsLimitOrderSummary) {
        submitLimitOrderChange(order: order, intent: .cancel(marketId: marketId, orderIndex: order.orderIndex))
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
            switch await prepareSigned({ await self.tradingService.prepareLimitOrderChange(intent) }) {
            case let .success(value):
                prepared = value
            case .failure(.activationCanceled):
                return
            case .failure(.nothingToChange):
                walletDependencies.accountStore.loadMarketExtras(marketId: marketId)
                assetPageViewModel?.showTradeResult(.success(TKLocales.Actions.done))
                return
            case let .failure(error):
                if case .orderNotFound = error {
                    walletDependencies.accountStore.loadMarketExtras(marketId: marketId)
                }
                assetPageViewModel?.showTradeResult(.failure(PerpsTradingErrorText.message(for: error)))
                return
            }

            let progress = PerpsAssetPageTradeToast.progress(
                PerpsAssetPageViewModel.limitOrderChangeToastText(intent.kind, isDone: false)
            )
            assetPageViewModel?.showTradeResult(progress)
            let submit = await tradingService.submit(prepared, passcodeProvider: makePasscodeProvider())
            let pending: PerpsPendingTradingAction
            switch submit {
            case let .submitted(value), let .submitUnknown(value):
                pending = value
            case .failed(.activationCanceled):
                // The approval passcode was dismissed: nothing is in flight any more.
                assetPageViewModel?.dismissTradeResult(progress)
                return
            case let .failed(error):
                walletDependencies.accountStore.loadMarketExtras(marketId: marketId)
                assetPageViewModel?.showTradeResult(.failure(PerpsTradingErrorText.message(for: error)))
                return
            }

            let result = await awaitReconciled(pending)
            walletDependencies.accountStore.loadMarketExtras(marketId: marketId)
            switch result {
            case .confirmed, .partiallyFilled:
                assetPageViewModel?.showTradeResult(.success(
                    PerpsAssetPageViewModel.limitOrderChangeToastText(intent.kind, isDone: true)
                ))
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
            walletDependencies.accountStore.loadMarketExtras(marketId: marketId)
            Self.dismissSheet(bottomSheet, completion: {})
            return .finished
        case .failure(.positionNotFound), .failure(.orderNotFound):
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

        switch await tradingService.submit(prepared, passcodeProvider: makePasscodeProvider()) {
        case .failed(.activationCanceled):
            return .finished
        case let .failed(error):
            // A single tx either landed or it didn't, but the venue may have
            // rejected for a reason the page should reflect — reload the orders.
            walletDependencies.accountStore.loadMarketExtras(marketId: marketId)
            return .failed(PerpsTradingErrorText.message(for: error, fallback: TKLocales.Perps.Toast.adjustFailed))
        case let .submitted(pending), let .submitUnknown(pending):
            switch await awaitReconciled(pending) {
            case .confirmed, .partiallyFilled:
                walletDependencies.accountStore.loadMarketExtras(marketId: marketId)
                Self.dismissSheet(bottomSheet, completion: {})
                assetPageViewModel?.retry()
                return .finished
            case let .failed(error):
                walletDependencies.accountStore.loadMarketExtras(marketId: marketId)
                return .failed(PerpsTradingErrorText.message(for: error, fallback: TKLocales.Perps.Toast.adjustFailed))
            case .pending:
                walletDependencies.accountStore.loadMarketExtras(marketId: marketId)
                return .failed(TKLocales.Perps.Toast.statusUnknown)
            }
        }
    }

    // MARK: - Adjust Margin (TK-1579)

    func openAdjustMarginSheet(marketId: Int64) {
        guard openPositionSummary(marketId: marketId) != nil else { return }
        let flags = walletDependencies.accountStore.marketExtras(marketId: marketId)?.flags
        let canAdd = flags.canAddMargin
        let canReduce = flags.canRemoveMargin
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
            accountStore: walletDependencies.accountStore,
            marketsStore: perpsAssembly.marketsStore,
            tradingService: tradingService,
            format: format
        )
        let navigationController = makeTradeNavigationController(
            rootViewController: PerpsAmountFormViewController(viewModel: viewModel)
        )

        viewModel.onClose = { [weak self] in
            self?.marginChangeFlow = .idle
            self?.dismissTrade()
        }
        viewModel.onDeposit = { [weak self] in
            self?.openDeposit(on: self?.tradeNavigationController)
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
            let result = await prepareSigned { await self.tradingService.prepareMarginChange(intent) }
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
                if failure.shouldCloseTrade {
                    dismissTrade()
                    refreshAfterTrade()
                } else {
                    formViewModel?.reviewFailed(warning: failure.warning)
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
        let shouldCloseTrade = error == .positionNotFound || error == .orderNotFound
        return ChangePrepareFailure(
            warning: PerpsTradingErrorText.message(for: error, fallback: TKLocales.Perps.Toast.adjustFailed),
            shouldCloseTrade: shouldCloseTrade
        )
    }

    func pushMarginChangeConfirm(_ prepared: PerpsPreparedMarginChangeAction, in navigationController: UINavigationController) {
        let viewModel = PerpsTradeConfirmViewModel(
            marginChangeContext: PerpsMarginChangeConfirmContext(marketId: prepared.marketId, review: prepared.review),
            format: format,
            iconURL: assetPageViewModel?.state.ready?.iconURL,
            marketsStore: perpsAssembly.marketsStore
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
        viewModel.onRefreshReview = { [weak self, weak viewModel] in
            guard let self,
                  case let .confirming(attempt, current) = marginChangeFlow,
                  case let .success(review) = await tradingService.previewMarginChange(current.intent),
                  marginChangeFlow.isCurrent(attempt)
            else { return }
            viewModel?.updateMarginChangeReview(review)
        }
        resignTradeKeyboard()
        navigationController.pushViewController(viewController, animated: true)
    }

    func submitMarginChange() {
        guard case let .confirming(_, prepared) = marginChangeFlow else { return }
        marginChangeFlow = .submitting
        walletDependencies.accountStore.beginAdjustingMargin(
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
                    isDone: true,
                    format: format
                ),
                submit: { await self.tradingService.submit(prepared, passcodeProvider: self.makePasscodeProvider()) }
            )
        }
    }

    // MARK: - Share Position

    func openShareSheet(_ snapshot: SharePositionSnapshot) {
        shareFlow.present(snapshot, from: sheetPresenter) { [weak self] in
            self?.resignTradeKeyboard()
        }
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
        let contentViewController = PerpsBottomSheetScrollContentViewController(
            title: title,
            subtitle: subtitle,
            liveSubtitle: liveSubtitle,
            content: content
        )
        return TKBottomSheetViewController(contentViewController: contentViewController)
    }

    func openConfirm(context: PerpsConfirmContext, openFormViewModel: PerpsOpenPositionViewModel?) {
        resignTradeKeyboard()
        let viewModel = PerpsTradeConfirmViewModel(
            context: context,
            format: format,
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
            await self?.editAutoCloseFromOpenConfirm(
                viewModel: viewModel,
                openFormViewModel: openFormViewModel
            )
        }
        viewModel.onAutoCloseStale = { Self.showAutoCloseStaleToast($0) }
        viewModel.onRefreshReview = { [weak self, weak viewModel] in
            guard let self,
                  let context = viewModel?.openConfirmContext,
                  context.intent.limitPrice == nil,
                  case let .success(review) = await tradingService.previewOpenMarket(context.replacingAutoClose(nil).intent)
            else { return }
            viewModel?.updateOpenReview(review, for: context.intent)
        }
        tradeNavigationController?.pushViewController(viewController, animated: true)
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
                viewModel?.updateOpenAutoClose(autoClose, review: context.review)
            }
        )
    }

    @MainActor
    func handleOpenConfirm(
        context: PerpsConfirmContext,
        openFormViewModel: PerpsOpenPositionViewModel?,
        viewModel: PerpsTradeConfirmViewModel?
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
        guard let kind = invalid.confirmStaleKind else {
            submit(context: context, confirmationViewModel: viewModel)
            return
        }
        presentAutoCloseStaleAlert(
            kind: kind,
            onContinueWithout: { [weak self, weak openFormViewModel, weak viewModel] in
                let stripped = PerpsAutoCloseValidation.stripping(autoClose, removing: invalid)
                let remaining = stripped.isEmpty ? nil : stripped
                openFormViewModel?.applyAutoClose(remaining)
                viewModel?.updateOpenAutoClose(remaining)
                Task { @MainActor in
                    await self?.handleOpenConfirm(
                        context: context.replacingAutoClose(remaining),
                        openFormViewModel: openFormViewModel,
                        viewModel: viewModel
                    )
                }
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
        _ prepared: PerpsPreparedSizeChangeAction,
        session: PerpsSizeChangeSession,
        formViewModel: PerpsSizeChangeViewModel?
    ) async {
        guard let autoClose = session.autoCloseForConfirmValidation else {
            submitSizeChange(session: session)
            return
        }
        let referencePrice = await perpsAssembly.marketsStore.price(marketId: prepared.marketId)
            ?? prepared.review.entryPrice.new
        guard sizeChangeSession === session, session.prepared?.operationId == prepared.operationId else { return }
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
        guard sizeChangeSession === session, session.prepared?.operationId == prepared.operationId else { return }
        guard let kind = invalid.confirmStaleKind else {
            submitSizeChange(session: session)
            return
        }
        presentAutoCloseStaleAlert(
            kind: kind,
            onContinueWithout: { [weak self, weak formViewModel] in
                guard let self else { return }
                let stripped = PerpsAutoCloseValidation.stripping(autoClose, removing: invalid)
                session.cancelConfirming()
                reprepareSizeChangeFromConfirm(
                    session: session,
                    desiredAutoClose: stripped,
                    formViewModel: formViewModel
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
            },
            onClose: { session.cancelConfirming() }
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

    func showOpenFailure(
        _ error: PerpsTradingError,
        context: PerpsConfirmContext,
        fallback: String? = nil
    ) {
        if case .activationCanceled = error { return }
        if case .slippageExceeded = error {
            presentOrderNotPlacedAlert { [weak self] in self?.retryOpen(context) }
            return
        }
        let message = fallback.map { PerpsTradingErrorText.message(for: error, fallback: $0) }
            ?? PerpsTradingErrorText.message(for: error)
        guard !message.isEmpty else { return }
        assetPageViewModel?.showTradeResult(.failure(message))
    }

    func retryOpen(_ context: PerpsConfirmContext) {
        guard openPositionFlow.begin(marketId: context.intent.marketId) else { return }
        submit(context: context)
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
        bottomSheet.present(fromViewController: sheetPresenter)
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
        Task { @MainActor [weak self] in
            guard let self else { return }
            var didBeginOpening = false
            let isReady = await self.ensureAccountReady(onPasscodeEntered: { [weak self] in
                didBeginOpening = true
                self?.beginOpening(descriptor)
            })
            guard isReady else {
                if didBeginOpening {
                    self.walletDependencies.accountStore.clearPending(marketId: context.intent.marketId)
                    self.openPositionFlow.finishSubmitting()
                } else {
                    self.openPositionFlow.cancelSubmitting()
                    confirmationViewModel?.restoreConfirmation()
                }
                return
            }
            if !didBeginOpening { self.beginOpening(descriptor) }
            defer { self.openPositionFlow.finishSubmitting() }
            let prepared: PerpsPreparedTradingAction
            switch await self.tradingService.prepareOpenMarket(context.intent) {
            case let .success(value):
                prepared = value
            case let .failure(error):
                walletDependencies.accountStore.clearPending(marketId: context.intent.marketId)
                showOpenFailure(error, context: context)
                return
            }

            let result = await tradingService.submit(prepared, passcodeProvider: makePasscodeProvider())
            switch result {
            case let .submitted(pending):
                await resolveOpeningOverlay(
                    pending: pending,
                    successToast: toastText(verb: toastSuccessVerb(prepared: prepared), prepared: prepared),
                    onSlippage: { [weak self] in self?.retryOpen(context) }
                )
            case let .submitUnknown(pending):
                assetPageViewModel?.showTradeResult(.failure(TKLocales.Perps.Toast.statusUnknown))
                await resolveOpeningOverlay(
                    pending: pending,
                    successToast: nil,
                    onSlippage: { [weak self] in self?.retryOpen(context) }
                )
            case let .failed(error):
                walletDependencies.accountStore.clearPending(marketId: context.intent.marketId)
                showOpenFailure(error, context: context, fallback: TKLocales.Perps.Toast.openFailed)
            }
        }
    }

    @MainActor
    func beginOpening(_ descriptor: PerpsOpeningDescriptor) {
        dismissTrade()
        walletDependencies.accountStore.beginOpening(descriptor)
    }

    func resolveOpeningOverlay(
        pending: PerpsPendingTradingAction,
        successToast: String?,
        onSlippage: (() -> Void)? = nil
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
            onSlippage: onSlippage
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
        onSlippage: (() -> Void)? = nil,
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
            walletDependencies.accountStore.clearPending(marketId: marketId)
            showSettleFailure(error, fallback: submitFallback, onSlippage: onSlippage)
            refreshAfterTrade()
            return
        }
        await settleOnPage(
            pending: pending,
            successToast: toast,
            failureFallback: TKLocales.Perps.Toast.statusUnknown,
            reloadExtras: reloadExtras,
            onSlippage: onSlippage
        )
    }

    func showSettleFailure(_ error: PerpsTradingError, fallback: String, onSlippage: (() -> Void)?) {
        if case .activationCanceled = error { return }
        if case .slippageExceeded = error, let onSlippage {
            presentOrderNotPlacedAlert(onRetry: onSlippage)
        } else {
            assetPageViewModel?.showTradeResult(.failure(PerpsTradingErrorText.message(for: error, fallback: fallback)))
        }
    }

    /// The tail every signed action shares: poll until tk-perps states an outcome,
    /// then put that outcome on the page. Anything but a confirmation drops the
    /// optimistic overlay, since the market is no longer mid-change.
    func settleOnPage(
        pending: PerpsPendingTradingAction,
        successToast: String?,
        failureFallback: String,
        reloadExtras: Bool,
        onSlippage: (() -> Void)? = nil
    ) async {
        let outcome = await awaitReconciled(pending)
        Log.perps.i("UI: settle operation=\(pending.operationId) market=\(pending.marketId) payload=\(pending.payload) outcome=\(outcome)")
        switch outcome {
        case .confirmed, .partiallyFilled:
            walletDependencies.accountStore.refresh()
            if reloadExtras {
                let clearingPending: Bool
                if case .open = pending.payload { clearingPending = true } else { clearingPending = false }
                walletDependencies.accountStore.loadMarketExtras(marketId: pending.marketId, clearingPending: clearingPending)
            }
            if outcome == .confirmed, let successToast {
                assetPageViewModel?.showTradeResult(.success(successToast))
            }
            assetPageViewModel?.retry()
        case let .failed(error):
            walletDependencies.accountStore.clearPending(marketId: pending.marketId)
            refreshAfterTrade()
            showSettleFailure(error, fallback: failureFallback, onSlippage: onSlippage)
        case .pending:
            walletDependencies.accountStore.clearPending(marketId: pending.marketId)
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
            switch await prepareSigned({ await self.tradingService.prepareClose(intent) }) {
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
                if case .slippageExceeded = error {
                    presentOrderNotPlacedAlert { [weak self] in self?.openCashOut(marketId: marketId) }
                    return
                }
                let message = PerpsTradingErrorText.message(for: error)
                if !message.isEmpty {
                    assetPageViewModel?.showTradeResult(.failure(message))
                }
                if error == .positionNotFound || error == .orderNotFound {
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
            closeContext: PerpsCloseConfirmContext(
                marketId: prepared.marketId,
                sizeDecimals: sizeDecimals,
                review: prepared.review
            ),
            format: format,
            iconURL: assetPageViewModel?.state.ready?.iconURL,
            marketsStore: perpsAssembly.marketsStore
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
        viewModel.onRefreshReview = { [weak self, weak viewModel] in
            guard let self,
                  case let .success(review) = await tradingService.previewClose(PerpsCloseIntent(marketId: prepared.marketId)),
                  cashOutFlow.isCurrent(attempt)
            else { return }
            viewModel?.updateCloseReview(review)
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
        walletDependencies.accountStore.beginClosing(marketId: prepared.marketId)
        dismissTrade()
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.cashOutFlow = .idle }
            await settleSubmit(
                marketId: prepared.marketId,
                submitFallback: TKLocales.Perps.Toast.closeFailed,
                reloadExtras: false,
                successToast: closedToastText(review: prepared.review),
                onSlippage: { [weak self] in self?.openCashOut(marketId: prepared.marketId) },
                submit: { await self.tradingService.submit(prepared, passcodeProvider: self.makePasscodeProvider()) }
            )
        }
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

    func refreshAfterTrade() {
        assetPageViewModel?.retry()
        walletDependencies.accountStore.refresh()
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
                guard let self, let presenter = await self.settledSheetPresenter() else { return nil }
                return await self.walletDependencies.signingPasscode(
                    self,
                    ContainerViewControllerRouter(rootViewController: presenter)
                )
            }.value
        }
    }

    func settledSheetPresenter() async -> UIViewController? {
        for _ in 0 ..< 60 {
            let presenter = sheetPresenter
            if presenter.view.window != nil, presenter.transitionCoordinator == nil, !presenter.isBeingDismissed {
                return presenter
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return nil
    }

    func toastText(verb: String, prepared: PerpsPreparedTradingAction) -> String {
        let sideText = (prepared.intent.side == .long ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short).lowercased()
        let margin = format.usd(prepared.review.marginUsd)
        let leverage = format.leverage(prepared.intent.leverage)
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
    static let defaultInitialLeverage: Double = 20
}

private extension PerpsSizeChangeIntent {
    func replacingAutoCloseUpdate(_ autoCloseUpdate: PerpsAutoCloseUpdate) -> PerpsSizeChangeIntent {
        PerpsSizeChangeIntent(
            marketId: marketId,
            direction: direction,
            marginDeltaUsd: marginDeltaUsd,
            autoCloseUpdate: autoCloseUpdate
        )
    }
}

final class PerpsBottomSheetScrollContentViewController: UIViewController, TKBottomSheetScrollContentViewController {
    var didUpdateHeight: (() -> Void)?
    var headerConfiguration: TKBottomSheetHeaderConfiguration? {
        didSet {
            didUpdateHeaderConfiguration?(headerConfiguration)
        }
    }

    var didUpdateHeaderConfiguration: ((TKBottomSheetHeaderConfiguration?) -> Void)?

    let scrollView = UIScrollView()
    private let hostingView = SwiftUIHostingView()
    private var liveSubtitleCancellable: AnyCancellable?

    init(header: TKBottomSheetHeaderConfiguration, @ViewBuilder content: () -> some View) {
        super.init(nibName: nil, bundle: nil)
        headerConfiguration = header
        hostingView.setContent(content)
    }

    convenience init(
        title: String,
        subtitle: String?,
        liveSubtitle: AnyPublisher<String, Never>?,
        @ViewBuilder content: () -> some View
    ) {
        self.init(header: Self.header(title: title, subtitle: subtitle), content: content)
        liveSubtitleCancellable = liveSubtitle?
            .removeDuplicates()
            .sink { [weak self] in self?.headerConfiguration = Self.header(title: title, subtitle: $0) }
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

    private static func header(title: String, subtitle: String?) -> TKBottomSheetHeaderConfiguration {
        TKBottomSheetHeaderConfiguration(title: .title(title: title, subtitle: subtitle))
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
