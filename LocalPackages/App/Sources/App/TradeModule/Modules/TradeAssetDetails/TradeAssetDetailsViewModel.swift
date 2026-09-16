import AppUI
import Combine
import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

@MainActor
final class TradeAssetDetailsViewModel: ObservableObject {
    private enum Constants {
        static let favoriteTooltipMaximumWidth: CGFloat = 280
        static let favoriteTooltipVerticalOffset: CGFloat = 4
    }

    struct PreviewContext {
        let assetID: String
        let assetCategory: TradingAssetCategory?
        let title: String?
        let imageURL: URL?
        let symbol: String?
        let change24hPercent: Decimal?
        let isUnverified: Bool?
        let isTrusted: Bool?

        init(
            assetID: String,
            assetCategory: TradingAssetCategory? = nil,
            title: String? = nil,
            imageURL: URL? = nil,
            symbol: String? = nil,
            change24hPercent: Decimal? = nil,
            isUnverified: Bool? = nil,
            isTrusted: Bool? = nil
        ) {
            self.assetID = assetID
            self.assetCategory = assetCategory
            self.title = title
            self.imageURL = imageURL
            self.symbol = symbol
            self.change24hPercent = change24hPercent
            self.isUnverified = isUnverified
            self.isTrusted = isTrusted
        }
    }

    enum HistorySource {
        case legacy(any TradeAssetDetailsHistoryViewModeling)
        case multichain(any TradeAssetDetailsMultichainHistoryViewModeling)
    }

    struct TokenVisibilityMenuItem {
        let title: String
        let icon: UIImage
    }

    struct ExplorerMenuItem {
        let title: String
        let icon: UIImage
        fileprivate let assetExplorer: MultichainAssetExplorerProvider.AssetExplorer
    }

    @Published private(set) var header: TradeAssetDetailsHeaderViewData?
    @Published private(set) var screen: TradeAssetDetailsScreenViewData?
    @Published private(set) var explorerMenuItem: ExplorerMenuItem?
    @Published private(set) var tokenVisibilityMenuItem: TokenVisibilityMenuItem?
    @Published private(set) var isFavorite: Bool?
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    @Published private(set) var selectedMultichainActivity: MultichainActivity?

    var isFavoritesEnabled: Bool {
        multichainState != nil
    }

    private var resolvedMultichainAsset: MultichainAsset? {
        assetVisibility?.asset
    }

    let chartState: TokenChartViewState?

    private let multichainState: MultichainWalletState?
    private let assetID: String
    private let isSwapDisabled: Bool
    private let analyticsProvider: AnalyticsProvider
    private let analyticsSource: AssetViewAnalyticsSource
    private let favoriteAssetsService: TradingFavoriteAssetsService
    private let tooltipsService: TooltipsService
    private let assetDetailsService: TradingAssetDetailsService
    private let visibilityChangesController: VisibilityChangesController?
    private let explorerProvider: MultichainAssetExplorerProvider
    private let appSettingsStore: AppSettingsStore
    private let initialPreviewContext: PreviewContext
    private let mapper: TradeAssetDetailsScreenMapper
    private let amountFormatter: AmountFormatter
    private let marketDataViewModel: TradeAssetDetailsMarketDataViewModel
    private let balanceViewModel: any TradeAssetDetailsBalanceViewModeling
    private let historySource: HistorySource
    private let tronFeesViewModel: TradeAssetDetailsTronFeesViewModel?
    private let tonStakingAPYProvider: () -> Decimal?
    private let tokenDetailsConfiguratorProvider: (TradingAssetInfo) async -> TokenDetailsConfigurator?
    private let onOpenHistory: (TradeAssetHistoryContext) -> Void
    private let onOpenHistoryEvent: (TradeAssetHistorySelection) -> Void
    private let onOpenMultichainHistory: (MultichainWalletState, String) -> Void
    private let onOpenUrl: (URL) -> Void
    private let onBuy: (TradingAssetInfo) -> Void
    private let onSell: (TradingAssetInfo) -> Void
    private let onSend: (TradingAssetInfo, MultichainAsset?) -> Void
    private let onReceive: (TradingAssetInfo) -> Void
    private let onSellToCard: (TradingAssetInfo, MultichainAsset?) -> Void
    private let onCashBuy: (TradingAssetInfo) -> Void
    private let onTronFees: (TronUsdtFeesSnapshot, TradeAssetDetailsTronFeesTrigger) -> Void
    private let onOpenStaking: () -> Void
    private let onOpenTokenizedInfo: (TokenizedAssetInfoKind) -> Void
    private let onOpenUnverifiedTokenInfo: () -> Void
    private let onOpenVerifiedTokenInfo: () -> Void
    private let onAssetVisibilityChanged: () -> Void
    private let onBack: () -> Void

    private var hasLoaded = false
    private weak var favoriteTooltipSourceView: UIView?
    private var hasAppeared = false
    private var details: TradingAssetDetails?
    private var supplementalMarketData: TradeAssetDetailsMarketData?
    private var balanceSnapshot: TradeAssetDetailsBalanceSnapshot?
    private var assetVisibility: TradeAssetDetailsAssetVisibility?
    private var historyPreview: TradeAssetDetailsHistoryPreview?
    private var multichainHistoryPreview: TradeAssetDetailsMultichainHistoryPreview?
    private var tronFeesSnapshot: TronUsdtFeesSnapshot?
    private var cancellables = Set<AnyCancellable>()
    private var transactionSendNotificationToken: NSObjectProtocol?
    private var isVisibilityUpdateInProgress = false

    init(
        multichainState: MultichainWalletState?,
        preview: PreviewContext,
        isSwapDisabled: Bool,
        analyticsProvider: AnalyticsProvider,
        analyticsSource: AssetViewAnalyticsSource,
        favoriteAssetsService: TradingFavoriteAssetsService,
        tooltipsService: TooltipsService,
        assetDetailsService: TradingAssetDetailsService,
        visibilityChangesController: VisibilityChangesController?,
        explorerProvider: MultichainAssetExplorerProvider,
        appSettingsStore: AppSettingsStore,
        currencyStore: CurrencyStore,
        amountFormatter: AmountFormatter,
        signedAmountFormatter: AmountFormatter,
        tokenDetailsConfiguratorProvider: @escaping (TradingAssetInfo) async -> TokenDetailsConfigurator?,
        marketDataViewModel: TradeAssetDetailsMarketDataViewModel,
        balanceViewModel: any TradeAssetDetailsBalanceViewModeling,
        historySource: HistorySource,
        tronFeesViewModel: TradeAssetDetailsTronFeesViewModel?,
        tonStakingAPYProvider: @escaping () -> Decimal?,
        onOpenUrl: @escaping (URL) -> Void,
        chartState: TokenChartViewState?,
        onOpenHistory: @escaping (TradeAssetHistoryContext) -> Void,
        onOpenHistoryEvent: @escaping (TradeAssetHistorySelection) -> Void,
        onOpenMultichainHistory: @escaping (MultichainWalletState, String) -> Void,
        onBuy: @escaping (TradingAssetInfo) -> Void,
        onSell: @escaping (TradingAssetInfo) -> Void,
        onSend: @escaping (TradingAssetInfo, MultichainAsset?) -> Void,
        onReceive: @escaping (TradingAssetInfo) -> Void,
        onSellToCard: @escaping (TradingAssetInfo, MultichainAsset?) -> Void,
        onCashBuy: @escaping (TradingAssetInfo) -> Void,
        onTronFees: @escaping (TronUsdtFeesSnapshot, TradeAssetDetailsTronFeesTrigger) -> Void,
        onOpenStaking: @escaping () -> Void,
        onOpenTokenizedInfo: @escaping (TokenizedAssetInfoKind) -> Void,
        onOpenUnverifiedTokenInfo: @escaping () -> Void,
        onOpenVerifiedTokenInfo: @escaping () -> Void,
        onAssetVisibilityChanged: @escaping () -> Void,
        onBack: @escaping () -> Void
    ) {
        self.multichainState = multichainState
        self.assetID = preview.assetID
        self.isSwapDisabled = isSwapDisabled
        self.analyticsProvider = analyticsProvider
        self.analyticsSource = analyticsSource
        self.favoriteAssetsService = favoriteAssetsService
        self.tooltipsService = tooltipsService
        self.assetDetailsService = assetDetailsService
        self.visibilityChangesController = visibilityChangesController
        self.explorerProvider = explorerProvider
        self.appSettingsStore = appSettingsStore
        self.initialPreviewContext = preview
        let mapper = TradeAssetDetailsScreenMapper(
            multichainState: multichainState,
            preview: preview,
            isSwapDisabled: isSwapDisabled,
            amountFormatter: amountFormatter,
            signedAmountFormatter: signedAmountFormatter,
            currencyProvider: { [currencyStore] in
                currencyStore.state
            }
        )
        self.mapper = mapper
        self.amountFormatter = amountFormatter
        self.header = mapper.initialHeader
        self.onOpenUrl = onOpenUrl
        self.tokenDetailsConfiguratorProvider = tokenDetailsConfiguratorProvider
        self.marketDataViewModel = marketDataViewModel
        self.balanceViewModel = balanceViewModel
        self.historySource = historySource
        self.tronFeesViewModel = tronFeesViewModel
        self.tonStakingAPYProvider = tonStakingAPYProvider
        self.onOpenHistory = onOpenHistory
        self.onOpenHistoryEvent = onOpenHistoryEvent
        self.onOpenMultichainHistory = onOpenMultichainHistory
        self.onBuy = onBuy
        self.onSell = onSell
        self.onSend = onSend
        self.onReceive = onReceive
        self.onSellToCard = onSellToCard
        self.onCashBuy = onCashBuy
        self.onTronFees = onTronFees
        self.onOpenStaking = onOpenStaking
        self.onOpenTokenizedInfo = onOpenTokenizedInfo
        self.onOpenUnverifiedTokenInfo = onOpenUnverifiedTokenInfo
        self.onOpenVerifiedTokenInfo = onOpenVerifiedTokenInfo
        self.onAssetVisibilityChanged = onAssetVisibilityChanged
        self.onBack = onBack
        self.chartState = chartState

        transactionSendNotificationToken = NotificationCenter.default.addObserver(
            forName: .transactionSendNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.hasLoaded else {
                    return
                }
                await self.refresh()
            }
        }

        // The screen stays alive in its tab while the balance screen toggles secure mode.
        appSettingsStore.addObserver(self) { observer, event in
            switch event {
            case .didUpdateIsSecureMode:
                Task { @MainActor in
                    observer.rebuildScreen()
                }
            case .didUpdateSearchEngine, .didUpdateHistoryFilter, .didUpdateBalanceFilter:
                break
            }
        }

        bindContentViewModels()
        refreshExplorerMenuItem(assetId: preview.assetID)
    }

    deinit {
        if let transactionSendNotificationToken {
            NotificationCenter.default.removeObserver(transactionSendNotificationToken)
        }
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        analyticsProvider.log(
            AssetView(
                from: analyticsSource.assetView,
                asset: assetID,
                walletMode: multichainState == nil ? .single : .multi
            )
        )
        if isFavoritesEnabled {
            Task { [weak self] in
                guard let self else { return }
                let isFavorite = await self.favoriteAssetsService.isFavorite(id: self.assetID)
                guard self.isFavorite == nil else { return }
                self.isFavorite = isFavorite
            }
        }

        Task {
            if let cached = await assetDetailsService.assetDetails(for: assetID) {
                apply(cached)
                scheduleSupplementaryContentUpdate()
            }
            await refresh()
        }
    }

    func handleAppear() {
        guard hasLoaded else {
            return loadIfNeeded()
        }
        Task { [weak self] in
            await self?.refresh()
        }
    }

    func refresh() async {
        isLoading = true
        defer {
            isLoading = false
        }

        do {
            let details = try await assetDetailsService.loadAssetDetails(id: assetID)
            errorMessage = nil
            apply(details)
            scheduleSupplementaryContentUpdate()
        } catch {
            if screen == nil {
                switch error {
                case let .apiError(message):
                    errorMessage = message
                case .networkError:
                    errorMessage = TKLocales.ConnectionStatus.noInternet
                }
            }
        }
    }

    func goBack() {
        onBack()
    }

    func open(url: URL) {
        onOpenUrl(url)
    }

    func openHistory() {
        switch historySource {
        case .legacy:
            guard let context = historyPreview?.context else {
                return
            }
            onOpenHistory(context)
        case .multichain:
            guard let preview = multichainHistoryPreview else {
                return
            }
            onOpenMultichainHistory(preview.multichainState, assetID)
        }
    }

    func openHistoryEvent(id: String) {
        guard let selection = historyPreview?.items.first(where: { $0.id == id })?.selection else {
            return
        }
        onOpenHistoryEvent(selection)
    }

    func openMultichainHistoryEvent(activity: MultichainActivity) {
        selectedMultichainActivity = activity
    }

    func multichainTransactionDetailsModel(
        for activity: MultichainActivity
    ) -> MultichainTransactionDetailsModel {
        MultichainTransactionDetailsModelBuilder(
            amountFormatter: amountFormatter,
            dateFormatter: DateFormatter(),
            transactionButtonProvider: MultichainTransactionDetailsModelBuilder.transactionButton
        ).build(activity: activity)
    }

    func dismissMultichainActivity() {
        selectedMultichainActivity = nil
    }

    func handleBuyAction() {
        guard let details, details.capabilities.supportsSwap, !isSwapDisabled else {
            return
        }
        logButtonClick(.buy, assetID: details.assetInfo.assetId)
        onBuy(details.assetInfo)
    }

    func handleSellAction() {
        guard let details, details.capabilities.supportsSwap, !isSwapDisabled else {
            return
        }
        logButtonClick(.sell, assetID: details.assetInfo.assetId)
        onSell(details.assetInfo)
    }

    func handleSendAction() {
        guard screen?.isSendAvailable == true, let assetInfo = details?.assetInfo else {
            return
        }
        // A TRC20 transfer the wallet cannot pay fees for fails in the send flow, so the
        // shortfall is resolved here instead.
        if let tronFeesSnapshot, !tronFeesSnapshot.hasEnoughForAtLeastOneTransfer {
            onTronFees(tronFeesSnapshot, .insufficientSend)
            return
        }
        logButtonClick(.send, assetID: assetInfo.assetId)
        onSend(assetInfo, resolvedMultichainAsset)
    }

    func handleTronFeesAction() {
        guard let tronFeesSnapshot, let tronFees = screen?.tronFees else {
            return
        }
        switch tronFees {
        case .banner:
            onTronFees(tronFeesSnapshot, .banner)
        case .transfersAvailable:
            onTronFees(tronFeesSnapshot, .transfersAvailable)
        }
    }

    func handleReceiveAction() {
        guard let assetInfo = details?.assetInfo else {
            return
        }
        logButtonClick(.receive, assetID: assetInfo.assetId)
        onReceive(assetInfo)
    }

    func handleSellToCardAction() {
        guard
            multichainState != nil,
            let details,
            details.capabilities.supportsOfframp
        else {
            return
        }
        onSellToCard(details.assetInfo, resolvedMultichainAsset)
    }

    func handleCashBuyAction() {
        guard
            multichainState != nil,
            let details,
            details.capabilities.supportsOnramp
        else {
            return
        }
        onCashBuy(details.assetInfo)
    }

    func handleOpenVerifiedTokenInfo() {
        onOpenVerifiedTokenInfo()
    }

    func onTapHeader(data: HeaderSubtitleViewData) {
        switch data {
        case let .tokenizedAsset(kind):
            onOpenTokenizedInfo(kind)
        case .unverifiedAsset:
            onOpenUnverifiedTokenInfo()
        case .chainInfo:
            return
        }
    }

    func onTapAssetType(assetKind: TradeAssetDetailsAssetTypeSectionKind) {
        switch assetKind {
        case .tokenizedEtf:
            onOpenTokenizedInfo(.etf)
        case .tokenizedStock:
            onOpenTokenizedInfo(.stock)
        case .unverified:
            onOpenUnverifiedTokenInfo()
        }
    }

    func handleOpenEarnAction() {
        guard case .ton? = details?.assetInfo.typedAssetId else {
            return
        }

        onOpenStaking()
    }

    func openAssetExplorer() {
        guard let assetExplorer = explorerMenuItem?.assetExplorer else {
            return
        }

        switch assetExplorer.destination {
        case let .url(url):
            onOpenUrl(url)
        case .tonviewerDetails:
            guard let assetInfo = details?.assetInfo else {
                return
            }
            Task { [weak self] in
                guard let self else { return }
                let configurator = await tokenDetailsConfiguratorProvider(assetInfo)
                guard let url = configurator?.getDetailsURL() else { return }
                onOpenUrl(url)
            }
        }
    }

    func toggleAssetVisibility() {
        guard !isVisibilityUpdateInProgress,
              let multichainState,
              let visibilityChangesController,
              let assetInfo = details?.assetInfo,
              let assetVisibility,
              assetVisibility.hasNonZeroBalance
        else {
            return
        }

        let action: MultichainAssetFilterAction = switch assetVisibility.state {
        case .visible:
            .hide
        case .hidden:
            .show
        }

        isVisibilityUpdateInProgress = true
        defer {
            isVisibilityUpdateInProgress = false
        }

        do {
            try visibilityChangesController.enqueue(
                [
                    MultichainAssetFilterChange(
                        assetId: assetInfo.assetId,
                        action: action
                    ),
                ],
                walletId: multichainState.walletId,
                assets: assetVisibility.asset.map { [$0] } ?? []
            )

            balanceViewModel.applyVisibility(
                action == .hide ? .hidden : .visible
            )
            onAssetVisibilityChanged()
            ToastPresenter.showToast(
                configuration: .confirmed(text: confirmationToastText(for: action))
            )
        } catch {
            return
        }
    }

    func setFavoriteTooltipAnchor(_ view: UIView) {
        favoriteTooltipSourceView = view
        if hasAppeared {
            showFavoriteTooltipIfNeeded()
        }
    }

    func viewDidAppear() {
        hasAppeared = true
        balanceViewModel.didAppear()
        showFavoriteTooltipIfNeeded()
    }

    func viewDidDisappear() {
        balanceViewModel.didDisappear()
    }

    private func showFavoriteTooltipIfNeeded() {
        guard isFavoritesEnabled, let sourceView = favoriteTooltipSourceView else { return }
        tooltipsService.showTooltipIfNeeded(
            id: .tradeFavorite,
            sourceView: sourceView,
            targetActionViews: [sourceView],
            configuration: HintConfiguration(
                position: HintPosition(
                    tailParameters: TKTooltipView.tailParameters,
                    horizontal: .default,
                    vertical: .init(absolute: Constants.favoriteTooltipVerticalOffset),
                    direction: .topRight
                ),
                maximumWidth: Constants.favoriteTooltipMaximumWidth,
                animationStyle: .bouncing
            ),
            // Tapping the tooltip only dismisses it; favoriting happens via the
            // star button itself, not the tooltip target action.
            onTargetAction: nil
        )
    }

    func toggleFavorite() {
        guard isFavoritesEnabled else { return }
        tooltipsService.didPerformTooltipTargetAction(id: .tradeFavorite)
        performFavoriteToggle()
    }

    private func performFavoriteToggle() {
        guard isFavoritesEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let newValue = isFavorite != true
        isFavorite = newValue

        if newValue {
            analyticsProvider.log(TradeFavoriteAdd(from: .assetDetails, asset: assetID))
        } else {
            analyticsProvider.log(TradeFavoriteRemove(from: .assetDetails, asset: assetID))
        }

        let context: TradingFavoriteAssetContext = details
            .map { TradingFavoriteAssetContext(assetInfo: $0.assetInfo) }
            ?? TradingFavoriteAssetContext(preview: initialPreviewContext)

        Task {
            await favoriteAssetsService.setFavorite(newValue, context: context)
        }
    }

    func logButtonClick(
        _ button: AssetButtonClick.Button,
        assetID: String
    ) {
        analyticsProvider.log(
            AssetButtonClick(
                button: button,
                asset: assetID
            )
        )
    }
}

private extension TradeAssetDetailsViewModel {
    func apply(_ details: TradingAssetDetails) {
        var details = details
        if case .ton? = details.assetInfo.typedAssetId {
            details.assetInfo.earnAPY = tonStakingAPYProvider()
        }

        self.details = details
        if isFavorite == true {
            Task {
                await favoriteAssetsService.updateAsset(
                    TradingFavoriteAssetContext(assetInfo: details.assetInfo)
                )
            }
        }
        rebuildScreen()
    }

    func rebuildScreen() {
        let output = mapper.map(
            details: details,
            marketData: supplementalMarketData,
            balance: balanceSnapshot,
            history: historySection(),
            multichainHistory: multichainHistorySection(),
            tronFees: tronFeesSnapshot,
            isSecureMode: appSettingsStore.getState().isSecureMode
        )
        header = output.header
        screen = output.screen
        refreshExplorerMenuItem(assetId: details?.assetInfo.assetId ?? assetID)
        tokenVisibilityMenuItem = makeTokenVisibilityMenuItem()
    }

    func scheduleSupplementaryContentUpdate() {
        marketDataViewModel.scheduleUpdate()
        balanceViewModel.scheduleUpdate()
        switch historySource {
        case let .legacy(viewModel):
            viewModel.scheduleUpdate()
        case let .multichain(viewModel):
            viewModel.scheduleUpdate()
        }
        tronFeesViewModel?.scheduleUpdate()
    }

    func bindContentViewModels() {
        Publishers.CombineLatest3(
            marketDataViewModel.$state,
            balanceViewModel.statePublisher,
            balanceViewModel.visibilityPublisher
        )
        .sink { [weak self] marketData, balance, visibility in
            guard let self else {
                return
            }
            self.supplementalMarketData = marketData
            self.balanceSnapshot = balance
            self.assetVisibility = visibility
            guard self.details != nil else {
                return
            }
            self.rebuildScreen()
        }
        .store(in: &cancellables)

        bindHistorySource()
        bindTronFees()
    }

    func bindTronFees() {
        guard let tronFeesViewModel else {
            return
        }
        tronFeesViewModel.$snapshot
            .sink { [weak self] snapshot in
                guard let self else {
                    return
                }
                self.tronFeesSnapshot = snapshot
                guard self.details != nil else {
                    return
                }
                self.rebuildScreen()
            }
            .store(in: &cancellables)
    }

    func bindHistorySource() {
        switch historySource {
        case let .legacy(viewModel):
            viewModel.statePublisher
                .sink { [weak self] preview in
                    guard let self else {
                        return
                    }
                    self.historyPreview = preview
                    guard self.details != nil else {
                        return
                    }
                    self.rebuildScreen()
                }
                .store(in: &cancellables)
        case let .multichain(viewModel):
            viewModel.statePublisher
                .sink { [weak self] preview in
                    guard let self else {
                        return
                    }
                    self.multichainHistoryPreview = preview
                    guard self.details != nil else {
                        return
                    }
                    self.rebuildScreen()
                }
                .store(in: &cancellables)
        }
    }

    func historySection() -> TradeAssetDetailsHistorySectionViewData? {
        guard case .legacy = historySource,
              let items = historyPreview?.items, !items.isEmpty
        else {
            return nil
        }
        return TradeAssetDetailsHistorySectionViewData(
            items: items.map {
                TradeAssetDetailsHistoryItemViewData(
                    id: $0.id,
                    icon: $0.icon,
                    title: $0.title,
                    subtitle: $0.subtitle,
                    amountText: $0.amountText,
                    amountStyle: $0.amountStyle,
                    dateText: $0.dateText
                )
            }
        )
    }

    func multichainHistorySection() -> TradeAssetDetailsMultichainHistorySectionViewData? {
        guard case .multichain = historySource,
              let items = multichainHistoryPreview?.items, !items.isEmpty
        else {
            return nil
        }
        return TradeAssetDetailsMultichainHistorySectionViewData(items: items)
    }

    func makeTokenVisibilityMenuItem() -> TokenVisibilityMenuItem? {
        guard multichainState != nil,
              let assetVisibility,
              assetVisibility.hasNonZeroBalance
        else {
            return nil
        }

        switch assetVisibility.state {
        case .visible:
            return TokenVisibilityMenuItem(
                title: TKLocales.Token.hideInWallet,
                icon: .TKUIKit.Icons.Size16.eyeDisable
            )
        case .hidden:
            return TokenVisibilityMenuItem(
                title: TKLocales.Token.showInWallet,
                icon: .TKUIKit.Icons.Size16.eyeOutline
            )
        }
    }

    func refreshExplorerMenuItem(assetId: String) {
        guard let assetExplorer = explorerProvider.assetExplorer(for: assetId) else {
            explorerMenuItem = nil
            return
        }
        explorerMenuItem = ExplorerMenuItem(
            title: TKLocales.Actions.viewOn(assetExplorer.browserTitle),
            icon: .TKUIKit.Icons.Size16.globe,
            assetExplorer: assetExplorer
        )
    }

    func confirmationToastText(for action: MultichainAssetFilterAction) -> String {
        switch action {
        case .hide:
            return TKLocales.Toast.hidden
        case .show:
            return TKLocales.Toast.shown
        }
    }
}

private extension TradingFavoriteAssetContext {
    init(preview: TradeAssetDetailsViewModel.PreviewContext) {
        self.init(
            id: preview.assetID,
            symbol: preview.symbol ?? preview.title,
            imageURL: preview.imageURL
        )
    }

    init(assetInfo: TradingAssetInfo) {
        self.init(
            id: assetInfo.assetId,
            symbol: assetInfo.symbol,
            imageURL: assetInfo.imageURL
        )
    }
}
