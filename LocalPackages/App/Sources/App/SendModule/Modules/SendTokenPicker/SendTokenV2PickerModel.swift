import Foundation
import KeeperCore

enum SendTokenV2PickerDisplayMode {
    case includingMarketData
    case includingSelection(MultichainAsset?)
    case rampAsset
}

enum SendTokenV2PickerSearchBehavior {
    case catalog
    case account
}

final class SendTokenV2PickerModel: TokenPickerV2Model {
    private let multichainState: MultichainWalletState
    private let searchBehavior: SendTokenV2PickerSearchBehavior
    private let multichainService: MultichainService
    private let currencyStore: CurrencyStore
    private let catalogSearching: TradingCatalogSearching?
    private let perpsSearching: PerpsMarketsSearching?
    private let isTransferSupported: (MultichainAsset) -> Bool
    private let isPerpsCatalogEnabled: Bool

    let initialState: TokenPickerV2ModelState

    private(set) var catalogSearchSort: MultichainAssetSearchSort = .marketCap
    private(set) var perpsSearchSort: PerpsMarketsSort = .volume

    var showsCatalogSortControl: Bool {
        searchBehavior == .catalog
    }

    init(
        multichainState: MultichainWalletState,
        displayMode: SendTokenV2PickerDisplayMode,
        searchBehavior: SendTokenV2PickerSearchBehavior,
        multichainService: MultichainService,
        currencyStore: CurrencyStore,
        initialCatalogSearchSort: MultichainAssetSearchSort = .marketCap,
        isTransferSupported: @escaping (MultichainAsset) -> Bool = { _ in true },
        allowedChains: Set<MultichainChain>? = nil,
        initialChain: MultichainChain? = nil,
        catalogSearching: TradingCatalogSearching? = nil,
        perpsSearching: PerpsMarketsSearching? = nil
    ) {
        self.multichainState = multichainState
        self.searchBehavior = searchBehavior
        self.multichainService = multichainService
        self.currencyStore = currencyStore
        self.catalogSearching = catalogSearching
        self.perpsSearching = perpsSearching
        self.isTransferSupported = isTransferSupported
        catalogSearchSort = initialCatalogSearchSort
        isPerpsCatalogEnabled = searchBehavior == .catalog
            && allowedChains == nil
            && catalogSearching != nil
            && perpsSearching != nil
        let selection = Self.chainFilters(
            walletFilters: multichainState.tokenPickerV2Filters,
            allowedChains: allowedChains,
            initialChain: initialChain
        )
        var filters = selection.filters
        if isPerpsCatalogEnabled {
            filters.append(.perpetuals)
        }
        initialState = TokenPickerV2ModelState(
            filters: filters,
            displayMode: displayMode,
            initialFilter: selection.initialFilter
        )
    }

    func setCatalogSearchSort(_ sort: MultichainAssetSearchSort) {
        guard searchBehavior == .catalog, catalogSearchSort != sort else {
            return
        }
        catalogSearchSort = sort
    }

    func setPerpsSearchSort(_ sort: PerpsMarketsSort) {
        guard isPerpsCatalogEnabled, perpsSearchSort != sort else {
            return
        }
        perpsSearchSort = sort
    }

    static func chainFilters(
        walletFilters: [TokenPickerV2ChainFilter],
        allowedChains: Set<MultichainChain>?,
        initialChain: MultichainChain?
    ) -> (filters: [TokenPickerV2ChainFilter], initialFilter: TokenPickerV2ChainFilter) {
        guard let allowedChains else {
            return (walletFilters.isEmpty ? [.all] : walletFilters, .all)
        }
        let filters = walletFilters.filter { filter in
            if case let .chain(chain) = filter {
                return allowedChains.contains(chain)
            }
            return false
        }
        guard let firstFilter = filters.first else {
            return ([.all], .all)
        }
        let initialFilter = initialChain.flatMap { chain in
            filters.contains(.chain(chain)) ? TokenPickerV2ChainFilter.chain(chain) : nil
        }
        return (filters, initialFilter ?? firstFilter)
    }

    func loadAssets(
        query: String?,
        filter: TokenPickerV2ChainFilter,
        limit: Int,
        cursor: String?
    ) async throws(MultichainServiceError) -> TokenPickerLoadResult {
        let normalizedQuery = normalizedQuery(query)

        if isPerpsCatalogEnabled, filter == .perpetuals {
            return try await loadPerpsMarkets(
                query: normalizedQuery,
                cursor: cursor
            )
        }

        let accounts = multichainState.tokenPickerV2Accounts(for: filter)
        guard !accounts.isEmpty else {
            return TokenPickerLoadResult(assets: [], nextCursor: nil)
        }

        switch searchBehavior {
        case .catalog:
            return try await loadCatalogAssets(
                query: normalizedQuery,
                filter: filter,
                limit: limit,
                cursor: cursor
            )
        case .account:
            return try await loadAccountAssets(
                query: normalizedQuery,
                filter: filter,
                limit: limit,
                cursor: cursor
            )
        }
    }
}

private extension SendTokenV2PickerModel {
    func loadCatalogAssets(
        query: String?,
        filter: TokenPickerV2ChainFilter,
        limit: Int,
        cursor: String?
    ) async throws(MultichainServiceError) -> TokenPickerLoadResult {
        if isPerpsCatalogEnabled {
            return try await loadTradingCatalogAssets(
                query: query,
                filter: filter,
                limit: limit,
                cursor: cursor
            )
        }
        return try await loadMultichainCatalogAssets(
            query: query,
            filter: filter,
            limit: limit,
            cursor: cursor
        )
    }

    func loadTradingCatalogAssets(
        query: String?,
        filter: TokenPickerV2ChainFilter,
        limit: Int,
        cursor: String?
    ) async throws(MultichainServiceError) -> TokenPickerLoadResult {
        guard let catalogSearching else {
            return TokenPickerLoadResult(items: [], nextCursor: nil)
        }

        let walletAssetById = try await walletAssetsByIdForMergingBalances()
        let page: TradingCatalogPage
        do {
            page = try await catalogSearching.catalogSearch(
                query: query,
                chain: filter.chain?.rawValue,
                showPerps: filter == .all,
                sort: catalogSearchSort,
                cursor: cursor,
                pageSize: limit
            )
        } catch {
            throw mapCatalogError(error)
        }

        let currencyCode = currencyStore.state.code.lowercased()
        let items = page.rows.compactMap { row -> TokenPickerLoadResult.Item? in
            switch row {
            case let .spot(spot):
                let asset = spot.multichainAsset(
                    walletAsset: walletAssetById[spot.id],
                    currencyCode: currencyCode
                )
                return isTransferSupported(asset) ? .asset(asset) : nil
            case let .perp(market):
                return .perp(market)
            }
        }
        return TokenPickerLoadResult(items: items, nextCursor: page.nextCursor)
    }

    func loadMultichainCatalogAssets(
        query: String?,
        filter: TokenPickerV2ChainFilter,
        limit: Int,
        cursor: String?
    ) async throws(MultichainServiceError) -> TokenPickerLoadResult {
        let walletAssetById = try await walletAssetsByIdForMergingBalances()
        let currencyCodes = requestedCurrencyCodes(for: currencyStore.state)
        let page = try await multichainService.searchAssets(
            currencies: currencyCodes,
            chain: filter.chain,
            search: query,
            sort: catalogSearchSort,
            limit: limit,
            cursor: cursor
        )
        let merged = page.assets.map { asset in
            MultichainAsset(
                asset: asset.asset,
                price: asset.price,
                balance: walletAssetById[asset.asset.assetId]?.balance ?? .zero,
                marketCap: asset.marketCap
            )
        }.filter(isTransferSupported)
        return TokenPickerLoadResult(
            assets: prioritizedAssets(merged, isFirstPage: cursor == nil),
            nextCursor: page.nextCursor
        )
    }

    func loadPerpsMarkets(
        query: String?,
        cursor: String?
    ) async throws(MultichainServiceError) -> TokenPickerLoadResult {
        guard let perpsSearching else {
            return TokenPickerLoadResult(items: [], nextCursor: nil)
        }

        let page: PerpsMarketsPage
        do {
            page = try await perpsSearching.markets(
                query: query,
                sort: perpsSearchSort,
                cursor: cursor
            )
        } catch {
            throw mapCatalogError(error)
        }
        return TokenPickerLoadResult(
            items: page.items.map { .perp($0) },
            nextCursor: page.nextCursor
        )
    }

    func mapCatalogError(_ error: Error) -> MultichainServiceError {
        if error is CancellationError {
            return .cancelled
        }
        return .apiError(message: nil)
    }

    func loadAccountAssets(
        query: String?,
        filter: TokenPickerV2ChainFilter,
        limit: Int,
        cursor: String?
    ) async throws(MultichainServiceError) -> TokenPickerLoadResult {
        let currencyCodes = requestedCurrencyCodes(for: currencyStore.state)
        let page = try await multichainService.getWalletAssets(
            state: multichainState,
            currencies: currencyCodes,
            assetIds: nil,
            capabilities: nil,
            chain: nil,
            search: nil,
            availableOnly: nil,
            showHidden: nil,
            hideDust: nil,
            limit: limit,
            cursor: cursor
        )
        let filteredAssets = page.assets.filter {
            matchesFilter(filter, asset: $0)
                && matchesQuery(query, asset: $0)
                && isTransferSupported($0)
        }
        return TokenPickerLoadResult(
            assets: prioritizedAssets(filteredAssets, isFirstPage: cursor == nil),
            nextCursor: page.nextCursor
        )
    }

    func normalizedQuery(_ query: String?) -> String? {
        guard let query else {
            return nil
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func walletAssetsByIdForMergingBalances() async throws(MultichainServiceError) -> [String: MultichainAsset] {
        var map: [String: MultichainAsset] = [:]
        let currencyCodes = requestedCurrencyCodes(for: currencyStore.state)
        let assets = try await multichainService.getAllWalletAssets(
            state: multichainState,
            currencies: currencyCodes,
            capabilities: nil,
            chain: nil,
            search: nil,
            availableOnly: nil,
            showHidden: nil,
            hideDust: nil
        ).assets
        for asset in assets {
            map[asset.asset.assetId] = asset
        }
        return map
    }

    func requestedCurrencyCodes(for currency: Currency) -> [String] {
        var codes = [currency.code.lowercased()]
        if currency != .defaultCurrency {
            codes.append(Currency.defaultCurrency.code.lowercased())
        }
        return codes
    }

    func matchesFilter(
        _ filter: TokenPickerV2ChainFilter,
        asset: MultichainAsset
    ) -> Bool {
        guard let chain = asset.asset.chain else {
            return true
        }
        return filter.includes(chain: chain)
    }

    func matchesQuery(
        _ query: String?,
        asset: MultichainAsset
    ) -> Bool {
        guard let query else {
            return true
        }

        return [
            asset.asset.name,
            asset.asset.symbol,
            asset.asset.assetId,
        ].contains {
            $0.localizedCaseInsensitiveContains(query)
        }
    }

    func prioritizedAssets(
        _ assets: [MultichainAsset],
        isFirstPage: Bool
    ) -> [MultichainAsset] {
        let selectedAsset: MultichainAsset?
        switch initialState.displayMode {
        case let .includingSelection(asset):
            selectedAsset = asset
        case .includingMarketData, .rampAsset:
            selectedAsset = nil
        }
        guard
            isFirstPage,
            let selectedAsset,
            let index = assets.lazy.map(\.asset.assetId).firstIndex(
                of: selectedAsset.asset.assetId
            ),
            index > 0
        else {
            return assets
        }

        var prioritizedAssets = assets
        prioritizedAssets.insert(
            prioritizedAssets.remove(at: index),
            at: 0
        )
        return prioritizedAssets
    }
}

private extension TradingCatalogSpot {
    func multichainAsset(
        walletAsset: MultichainAsset?,
        currencyCode: String
    ) -> MultichainAsset {
        let parsedPrice = Double(price)
        return MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: id,
                name: name,
                symbol: symbol,
                decimals: decimals,
                image: imageURL?.absoluteString ?? "",
                verification: MultichainAssetVerification(rawValue: verification.rawValue) ?? .none
            ),
            price: MultichainAssetPrice(
                prices: parsedPrice.map { [currencyCode: $0] } ?? [:],
                diff24h: [currencyCode: change24hPercent],
                diff7d: [:],
                diff30d: [:]
            ),
            balance: walletAsset?.balance ?? .zero,
            marketCap: marketCap.map { [currencyCode: $0] } ?? [:]
        )
    }
}
