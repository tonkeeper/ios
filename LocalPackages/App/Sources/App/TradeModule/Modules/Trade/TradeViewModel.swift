import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

@MainActor
final class TradeViewModel: ObservableObject {
    struct ServiceViewData: Identifiable {
        enum Kind: String {
            case perps
        }

        let kind: Kind
        let title: String
        let icon: UIImage

        var id: String {
            kind.rawValue
        }
    }

    struct ScrollToShelfRequest: Equatable {
        let id: Int
        let shelfID: String
    }

    struct ShelvesData {
        let mode: TradingShelvesMode
        var shelves: [TradeShelfViewData]
    }

    enum ShelvesState {
        case pending(ShelvesData)
        case refreshing(ShelvesData, task: Task<Void, Never>)
        case loaded(ShelvesData)
        case failed(ShelvesData)

        var data: ShelvesData {
            switch self {
            case let .pending(data),
                 let .refreshing(data, task: _),
                 let .loaded(data),
                 let .failed(data):
                data
            }
        }

        var isPending: Bool {
            if case .pending = self {
                return true
            }
            return false
        }
    }

    @Published private(set) var state: ShelvesState
    @Published private(set) var favoriteAssets = [TradeShelfAssetViewData]()
    @Published private(set) var perpsShelfMarkets = [PerpsShelfMarketViewData]()
    @Published private(set) var isFavoritesEditing = false
    @Published private var pendingFavoriteRemovalIDs = Set<String>()

    /// Favorites shown in the section. While editing, items the user crossed out
    /// are hidden but not yet removed — removal is committed only on Done.
    var visibleFavoriteAssets: [TradeShelfAssetViewData] {
        favoriteAssets.filter { !pendingFavoriteRemovalIDs.contains($0.id) }
    }

    var shelves: [TradeShelfViewData] {
        state.data.shelves
    }

    var multichainEnabled: Bool {
        state.data.mode == .multichain
    }

    @Published private(set) var scrollToTopRequestID = 0
    @Published private(set) var scrollToShelfRequest: ScrollToShelfRequest?
    @Published private(set) var selectedGroupIDs = [String: String]()
    @Published private(set) var selectedGridIDs = [String: String]()

    var services: [ServiceViewData] {
        Self.makeServices(isPerpsEnabled: isPerpsEnabled)
    }

    @Published private(set) var rafflePresentation: MysteryRafflePresentation?

    private let analyticsProvider: AnalyticsProvider
    private let analyticsSource: TradeFlowAnalyticsSource
    private let walletsStore: WalletsStore
    private let shelvesService: TradingShelvesService
    private let favoriteAssetsService: TradingFavoriteAssetsService
    private let perpsShelfMarketsLoader: (() async throws -> [PerpsMarketSummary])?
    private var raffleObserver: MysteryRafflePresentationObserver?
    private let onOpenAssetList: (TradingAssetCategory, MultichainAssetSearchSort) -> Void
    private let onOpenPerps: (() -> Void)?
    private let onOpenPerpsMarket: ((Int64) -> Void)?
    private let onOpenAssetDetails: (TradeAssetDetailsViewModel.PreviewContext) -> Void
    private let onOpenRaffle: () -> Void
    private let signedAmountFormatter: AmountFormatter

    private var pendingGridID: String?
    private var scrollToShelfRequestID = 0
    private var isVisible = false
    private var favoritesMarketItemsTask: Task<Void, Never>?
    private var favoritesMutationTask: Task<Void, Never>?
    private var perpsShelfMarketsTask: Task<Void, Never>?
    private var perpsShelfGeneration = 0

    init(
        analyticsProvider: AnalyticsProvider,
        analyticsSource: TradeFlowAnalyticsSource,
        walletsStore: WalletsStore,
        shelvesService: TradingShelvesService,
        favoriteAssetsService: TradingFavoriteAssetsService,
        perpsShelfMarketsLoader: (() async throws -> [PerpsMarketSummary])? = nil,
        raffleStore: RaffleStore? = nil,
        signedAmountFormatter: AmountFormatter,
        onOpenAssetList: @escaping (TradingAssetCategory, MultichainAssetSearchSort) -> Void,
        onOpenPerps: (() -> Void)?,
        onOpenPerpsMarket: ((Int64) -> Void)? = nil,
        onOpenAssetDetails: @escaping (TradeAssetDetailsViewModel.PreviewContext) -> Void,
        onOpenRaffle: @escaping () -> Void = {}
    ) {
        let shelvesMode = Self.shelvesMode(for: try? walletsStore.activeWallet)
        self.analyticsProvider = analyticsProvider
        self.analyticsSource = analyticsSource
        self.walletsStore = walletsStore
        self.shelvesService = shelvesService
        self.favoriteAssetsService = favoriteAssetsService
        self.perpsShelfMarketsLoader = perpsShelfMarketsLoader
        self.state = .pending(ShelvesData(mode: shelvesMode, shelves: []))
        self.onOpenAssetList = onOpenAssetList
        self.onOpenPerps = onOpenPerps
        self.onOpenPerpsMarket = onOpenPerpsMarket
        self.onOpenAssetDetails = onOpenAssetDetails
        self.onOpenRaffle = onOpenRaffle
        self.signedAmountFormatter = signedAmountFormatter
        raffleObserver = MysteryRafflePresentationObserver(
            raffleStore: raffleStore
        ) { [weak self] presentation in
            self?.rafflePresentation = presentation
        }
        walletsStore.addObserver(self) { observer, event in
            Task { @MainActor in
                observer.handleWalletsStoreEvent(event)
            }
        }
        reloadPerpsShelfMarkets(for: try? walletsStore.activeWallet)
    }

    deinit {
        favoritesMarketItemsTask?.cancel()
        perpsShelfMarketsTask?.cancel()
    }

    func viewDidAppear() {
        isVisible = true
        refreshShelvesIfNeeded()
    }

    func viewDidDisappear() {
        isVisible = false
        exitFavoritesEditing()
    }

    func refresh() async {
        let perpsTask = reloadPerpsShelfMarkets(for: try? walletsStore.activeWallet)
        let task = startShelvesRefresh(forceFavorites: true)
        await task.value
        await perpsTask?.value
    }

    func openSearch() {
        exitFavoritesEditing()
        onOpenAssetList(.all, .marketCap)
    }

    func openRaffle() {
        analyticsProvider.log(RaffleBannerClick(source: .trade))
        exitFavoritesEditing()
        onOpenRaffle()
    }

    /// `shouldShowTradeBanner` reads the dismiss store live, so a plain UserDefaults
    /// write from `tradeBannerDismissed()` doesn't touch `@Published rafflePresentation`
    /// and SwiftUI never re-evaluates it. Force the republish explicitly.
    func dismissRaffleBanner() {
        analyticsProvider.log(RaffleBannerDismiss(source: .trade))
        rafflePresentation?.tradeBannerDismissed()
        objectWillChange.send()
    }

    func raffleBannerDidAppear() {
        guard rafflePresentation?.shouldShowTradeBanner == true else { return }
        analyticsProvider.log(RaffleBannerView(source: .trade))
    }

    func openService(_ service: ServiceViewData) {
        switch service.kind {
        case .perps:
            guard isPerpsEnabled else { return }
            onOpenPerps?()
        }
    }

    func openPerps() {
        exitFavoritesEditing()
        guard isPerpsEnabled else { return }
        onOpenPerps?()
    }

    func openPerpsMarket(_ marketID: Int64) {
        exitFavoritesEditing()
        guard isPerpsShelfEnabled else { return }
        onOpenPerpsMarket?(marketID)
    }

    func openAsset(_ asset: TradeShelfAssetViewData) {
        exitFavoritesEditing()
        analyticsProvider.log(
            TradeClickAsset(from: analyticsSource.tradeClickAsset, asset: asset.id)
        )
        onOpenAssetDetails(asset.preview)
    }

    func refreshFavoriteAssets() {
        guard !state.isPending else {
            return
        }

        Task {
            await reloadFavoriteAssets(forceRefresh: true)
        }
    }

    /// Done button: commit any crossed-out favorites, then leave edit mode.
    /// Tapping it again (when not editing) re-enters edit mode.
    func toggleFavoritesEditing() {
        if isFavoritesEditing {
            commitPendingFavoriteRemovals()
            isFavoritesEditing = false
        } else {
            isFavoritesEditing = true
        }
    }

    /// Leaves edit mode without committing — any crossed-out favorites are
    /// restored. Used when the user navigates away instead of tapping Done.
    func exitFavoritesEditing() {
        guard isFavoritesEditing else { return }
        pendingFavoriteRemovalIDs.removeAll()
        isFavoritesEditing = false
    }

    func openFavorite(_ asset: TradeShelfAssetViewData) {
        let position = visibleFavoriteAssets.firstIndex { $0.id == asset.id } ?? 0
        analyticsProvider.log(
            TradeFavoriteClick(asset: asset.id, position: position)
        )
        openAsset(asset)
    }

    /// Cross button while editing: hides the asset and marks it for removal.
    /// Nothing is persisted or reported until the user taps Done.
    func removeFavorite(_ asset: TradeShelfAssetViewData) {
        pendingFavoriteRemovalIDs.insert(asset.id)
    }

    func openSeeAll(for grid: TradeShelfGridViewData) {
        exitFavoritesEditing()
        guard let category = grid.seeAllCategory else {
            return
        }
        onOpenAssetList(category, grid.initialCatalogSearchSort)
    }

    func scrollToTop() {
        scrollToTopRequestID += 1
    }

    func scrollToGrid(id gridID: String) {
        guard selectGridAndRequestScroll(gridID: gridID) else {
            pendingGridID = gridID
            return
        }
    }

    func selectedGridID(for shelf: TradeShelfViewData) -> String? {
        guard let group = selectedGroup(for: shelf) else {
            return nil
        }
        guard let selectedGridID = selectedGridIDs[shelf.id],
              group.grids.contains(where: { $0.id == selectedGridID })
        else {
            return group.grids.first?.id
        }
        return selectedGridID
    }

    func selectedGroupID(for shelf: TradeShelfViewData) -> String? {
        selectedGroup(for: shelf)?.id
    }

    func selectedGroup(for shelf: TradeShelfViewData) -> TradeShelfGroupViewData? {
        guard let selectedGroupID = selectedGroupIDs[shelf.id] else {
            return shelf.groups.first
        }
        return shelf.groups.first(where: { $0.id == selectedGroupID }) ?? shelf.groups.first
    }

    func selectGroup(id groupID: String, for shelf: TradeShelfViewData) {
        guard let group = shelf.groups.first(where: { $0.id == groupID }) else {
            return
        }

        selectedGroupIDs[shelf.id] = group.id
        if let selectedGridID = selectedGridIDs[shelf.id],
           group.grids.contains(where: { $0.id == selectedGridID })
        {
            return
        }

        selectedGridIDs[shelf.id] = group.grids.first?.id
    }

    func selectGrid(id gridID: String, for shelf: TradeShelfViewData) {
        guard selectedGroup(for: shelf)?.grids.contains(where: { $0.id == gridID }) == true else {
            return
        }
        selectedGridIDs[shelf.id] = gridID
    }
}

private extension TradeViewModel {
    static func shelvesMode(for wallet: Wallet?) -> TradingShelvesMode {
        wallet?.isMultichain == true ? .multichain : .legacy
    }

    static func makeServices(isPerpsEnabled: Bool) -> [ServiceViewData] {
        guard isPerpsEnabled else {
            return []
        }

        return [
            ServiceViewData(
                kind: .perps,
                title: TKLocales.Trade.Services.perps,
                icon: .TKUIKit.Icons.Size28.perps
            ),
        ]
    }

    var itemsMapper: TradeItemsMapper {
        makeItemsMapper(for: state.data.mode)
    }

    var isPerpsEnabled: Bool {
        onOpenPerps != nil && (try? walletsStore.activeWallet)?.isMultichain == true
    }

    var isPerpsShelfEnabled: Bool {
        isPerpsShelfAvailable(for: try? walletsStore.activeWallet)
    }

    var isFavoritesSectionAvailable: Bool {
        multichainEnabled
    }

    func handleWalletsStoreEvent(_ event: WalletsStore.Event) {
        switch event {
        case let .didChangeActiveWallet(from: _, to: wallet):
            updateShelvesMode(for: wallet)
            reloadPerpsShelfMarkets(for: wallet)
        case let .didUpdateWalletMultichain(wallet):
            guard let activeWallet = try? walletsStore.activeWallet,
                  activeWallet.id == wallet.id
            else {
                return
            }
            updateShelvesMode(for: wallet)
            reloadPerpsShelfMarkets(for: wallet)
        default:
            break
        }
    }

    @discardableResult
    func reloadPerpsShelfMarkets(for wallet: Wallet?) -> Task<Void, Never>? {
        perpsShelfMarketsTask?.cancel()
        perpsShelfMarketsTask = nil
        perpsShelfGeneration += 1
        let generation = perpsShelfGeneration

        guard isPerpsShelfAvailable(for: wallet), let loader = perpsShelfMarketsLoader else {
            perpsShelfMarkets = []
            return nil
        }

        let task = Task { [weak self] in
            do {
                let markets = try await loader()
                guard let self, self.isCurrentPerpsShelfLoad(generation) else { return }
                self.perpsShelfMarkets = Array(markets.prefix(8)).map(self.makePerpsShelfMarket)
                self.perpsShelfMarketsTask = nil
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.isCurrentPerpsShelfLoad(generation) else { return }
                self.perpsShelfMarketsTask = nil
            }
        }
        perpsShelfMarketsTask = task
        return task
    }

    func isPerpsShelfAvailable(for wallet: Wallet?) -> Bool {
        wallet?.isMultichain == true
            && onOpenPerps != nil
            && onOpenPerpsMarket != nil
            && perpsShelfMarketsLoader != nil
    }

    func isCurrentPerpsShelfLoad(_ generation: Int) -> Bool {
        !Task.isCancelled
            && generation == perpsShelfGeneration
            && isPerpsShelfAvailable(for: try? walletsStore.activeWallet)
    }

    func makePerpsShelfMarket(_ market: PerpsMarketSummary) -> PerpsShelfMarketViewData {
        let change = Decimal(market.priceChangePercent)
        return PerpsShelfMarketViewData(
            id: market.marketId,
            symbol: market.symbol,
            iconURL: market.iconURL,
            leverage: PerpsFormatting.leverageBadge(Double(market.maxLeverage)),
            changeText: itemsMapper.formatChange(change),
            changeColor: itemsMapper.changeColor(for: change)
        )
    }

    func updateShelvesMode(for wallet: Wallet) {
        let nextMode = Self.shelvesMode(for: wallet)
        guard nextMode != state.data.mode else {
            return
        }
        if case let .refreshing(_, task: task) = state {
            task.cancel()
        }
        state = .pending(ShelvesData(mode: nextMode, shelves: []))
        if nextMode == .legacy {
            clearFavoriteAssets()
        }

        guard isVisible else {
            return
        }

        refreshShelvesIfNeeded()
    }

    func refreshShelvesIfNeeded() {
        guard state.isPending else {
            return
        }

        _ = startShelvesRefresh(forceFavorites: false)
    }

    @discardableResult
    func startShelvesRefresh(
        forceFavorites: Bool
    ) -> Task<Void, Never> {
        if case let .refreshing(_, task: task) = state {
            return task
        }

        let data = state.data
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performShelvesRefresh(for: data.mode, forceFavorites: forceFavorites)
        }
        state = .refreshing(data, task: task)
        return task
    }

    func performShelvesRefresh(
        for mode: TradingShelvesMode,
        forceFavorites: Bool
    ) async {
        await applyCachedShelves(for: mode)
        guard isCurrentShelvesRefresh(for: mode) else { return }

        await reloadFavoriteAssets(forceRefresh: forceFavorites)
        guard isCurrentShelvesRefresh(for: mode) else { return }

        do {
            let snapshot = try await shelvesService.loadShelves(for: mode)
            guard isCurrentShelvesRefresh(for: mode) else { return }

            apply(snapshot)
            await syncDisplayedChangesFromCache(for: mode)
            guard isCurrentShelvesRefresh(for: mode) else { return }

            state = .loaded(state.data)
        } catch {
            guard isCurrentShelvesRefresh(for: mode) else { return }

            state = .failed(state.data)
        }
    }

    func isCurrentShelvesRefresh(for mode: TradingShelvesMode) -> Bool {
        guard !Task.isCancelled,
              case let .refreshing(data, task: _) = state
        else {
            return false
        }
        return data.mode == mode
    }

    func applyCachedShelves(for mode: TradingShelvesMode) async {
        let cachedShelves = await shelvesService.shelves(for: mode)
        guard !Task.isCancelled, state.data.mode == mode else { return }
        if let cachedShelves {
            apply(cachedShelves)
        } else {
            updateShelvesData { $0.shelves = [] }
        }
    }

    func updateShelvesData(_ update: (inout ShelvesData) -> Void) {
        var data = state.data
        update(&data)
        switch state {
        case .pending:
            state = .pending(data)
        case let .refreshing(_, task: task):
            state = .refreshing(data, task: task)
        case .loaded:
            state = .loaded(data)
        case .failed:
            state = .failed(data)
        }
        pruneSelectedGroupIDs()
        pruneSelectedGridIDs()
    }

    func apply(_ snapshot: TradingShelvesSnapshot) {
        let shelves = TradeShelvesMapper.makeShelves(
            from: snapshot,
            itemsMapper: itemsMapper
        )
        updateShelvesData { data in
            data.shelves = shelves
        }
        if let pendingGridID {
            _ = selectGridAndRequestScroll(gridID: pendingGridID)
        }
    }

    func makeItemsMapper(for mode: TradingShelvesMode) -> TradeItemsMapper {
        TradeItemsMapper(
            multichainEnabled: mode == .multichain,
            signedAmountFormatter: signedAmountFormatter
        )
    }

    func commitPendingFavoriteRemovals() {
        let removed = favoriteAssets.filter { pendingFavoriteRemovalIDs.contains($0.id) }
        pendingFavoriteRemovalIDs.removeAll()
        guard !removed.isEmpty else { return }

        favoriteAssets.removeAll { asset in removed.contains { $0.id == asset.id } }

        for asset in removed {
            analyticsProvider.log(
                TradeFavoriteRemove(from: .favoritesSection, asset: asset.id)
            )
        }

        let contexts = removed.map {
            TradingFavoriteAssetContext(id: $0.id, symbol: $0.symbol, imageURL: $0.preview.imageURL)
        }
        let pendingMutation = favoritesMutationTask
        favoritesMutationTask = Task { [favoriteAssetsService] in
            await pendingMutation?.value
            for context in contexts {
                await favoriteAssetsService.setFavorite(false, context: context)
            }
        }
    }

    func reloadFavoriteAssets(forceRefresh: Bool) async {
        guard isFavoritesSectionAvailable else {
            clearFavoriteAssets()
            return
        }

        await favoritesMutationTask?.value

        let assets = await favoriteAssetsService.assets
        let assetIDs = assets.map(\.id)
        favoritesMarketItemsTask?.cancel()
        // Always shimmer the 24h price-diff until the fresh market-items batch
        // returns, matching the loading behaviour of the other tab items.
        favoriteAssets = assets.map {
            itemsMapper.assetViewData($0, isPriceDiffLoading: true)
        }

        guard !assets.isEmpty else {
            pendingFavoriteRemovalIDs.removeAll()
            isFavoritesEditing = false
            return
        }

        favoritesMarketItemsTask = Task { [weak self] in
            guard let self else { return }
            let marketItems = await self.favoriteAssetsService.marketItems(
                assetIDs: assetIDs,
                forceRefresh: forceRefresh
            )
            guard !Task.isCancelled else { return }
            self.applyFavoritesMarketItems(marketItems)
        }
    }

    func clearFavoriteAssets() {
        favoritesMarketItemsTask?.cancel()
        favoriteAssets = []
        pendingFavoriteRemovalIDs.removeAll()
        isFavoritesEditing = false
    }

    func applyFavoritesMarketItems(_ marketItems: [String: TradingMarketItem]) {
        favoriteAssets = favoriteAssets.map { current in
            if let item = marketItems[current.id] {
                return itemsMapper.assetViewData(from: item)
            }
            var current = current
            current.isChangeLoading = false
            return current
        }
        overlayShelvesChanges(marketItems)
    }

    /// Keeps the displayed 24h change consistent across favorites and shelves.
    /// Both views are derived from the same `marketItemsCache`, so the same
    /// asset can never show two different change values once the cache settles.
    func syncDisplayedChangesFromCache(for mode: TradingShelvesMode) async {
        let shelfIDs = shelves.flatMap(\.groups).flatMap(\.grids).flatMap(\.items).map(\.id)
        let ids = Array(Set(shelfIDs + favoriteAssets.map(\.id)))
        guard !ids.isEmpty else { return }

        let cached = await favoriteAssetsService.cachedMarketItems(assetIDs: ids)
        guard !Task.isCancelled, state.data.mode == mode, !cached.isEmpty else { return }

        favoriteAssets = favoriteAssets.map { view in
            // A cached value must not short-circuit the shimmer: favorites whose
            // fresh 24h price-diff is still loading keep shimmering until
            // applyFavoritesMarketItems delivers the fresh batch. Without this
            // guard, a cached hit here races the favorites fetch and can clear
            // the shimmer early (flaky `…ShimmerUntilPriceDiffsLoad` test).
            guard !view.isChangeLoading, let item = cached[view.id] else { return view }
            return itemsMapper.applyingChange(
                to: view,
                change24hPercent: item.change24hPercent,
                isUnverified: item.isUnverified,
                isTrusted: item.isTrusted
            )
        }
        overlayShelvesChanges(cached)
    }

    func overlayShelvesChanges(_ cached: [String: TradingMarketItem]) {
        let itemsMapper = itemsMapper
        updateShelvesData { data in
            data.shelves = TradeShelvesMapper.applyingMarketItems(
                cached,
                to: data.shelves,
                itemsMapper: itemsMapper
            )
        }
    }

    @discardableResult
    func selectGridAndRequestScroll(gridID: String) -> Bool {
        guard let selection = selectionContainingGrid(id: gridID) else {
            return false
        }

        selectedGroupIDs[selection.shelf.id] = selection.group.id
        selectedGridIDs[selection.shelf.id] = gridID
        scrollToShelfRequestID += 1
        scrollToShelfRequest = ScrollToShelfRequest(
            id: scrollToShelfRequestID,
            shelfID: selection.shelf.id
        )

        if pendingGridID == gridID {
            pendingGridID = nil
        }

        return true
    }

    func pruneSelectedGridIDs() {
        selectedGridIDs = selectedGridIDs.filter { shelfID, gridID in
            guard let shelf = shelves.first(where: { $0.id == shelfID }),
                  let group = selectedGroup(for: shelf)
            else {
                return false
            }
            return group.grids.contains(where: { $0.id == gridID })
        }
    }

    func pruneSelectedGroupIDs() {
        selectedGroupIDs = selectedGroupIDs.filter { shelfID, groupID in
            shelves.contains { shelf in
                shelf.id == shelfID && shelf.groups.contains(where: { $0.id == groupID })
            }
        }
    }

    func selectionContainingGrid(id gridID: String) -> (
        shelf: TradeShelfViewData,
        group: TradeShelfGroupViewData
    )? {
        for shelf in shelves {
            if let group = shelf.groups.first(where: { group in
                group.grids.contains(where: { $0.id == gridID })
            }) {
                return (shelf, group)
            }
        }
        return nil
    }
}
