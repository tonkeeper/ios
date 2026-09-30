import Foundation
import KeeperCore
import TKLogging

enum MultichainSwapTokenPickerSide {
    case source
    case receive(sourceAssetId: String)
}

final class MultichainSwapTokenPickerModel: TokenPickerV2Model {
    private let side: MultichainSwapTokenPickerSide
    private let multichainState: MultichainWalletState
    private let multichainService: MultichainService
    private let multichainSwapService: MultichainSwapService
    private let currencyStore: CurrencyStore

    let initialState: TokenPickerV2ModelState

    let showsCatalogSortControl = false
    private(set) var catalogSearchSort: MultichainAssetSearchSort = .marketCap

    init(
        side: MultichainSwapTokenPickerSide,
        multichainState: MultichainWalletState,
        selectedAsset: MultichainAsset?,
        multichainService: MultichainService,
        multichainSwapService: MultichainSwapService,
        currencyStore: CurrencyStore
    ) {
        self.side = side
        self.multichainState = multichainState
        self.multichainService = multichainService
        self.multichainSwapService = multichainSwapService
        self.currencyStore = currencyStore
        initialState = TokenPickerV2ModelState(
            filters: multichainState.tokenPickerV2Filters,
            displayMode: .includingSelection(selectedAsset),
            initialFilter: .all
        )
    }

    func setCatalogSearchSort(_ sort: MultichainAssetSearchSort) {
        catalogSearchSort = sort
    }

    func loadAssets(
        query: String?,
        filter: TokenPickerV2ChainFilter,
        limit: Int,
        cursor: String?
    ) async throws(MultichainServiceError) -> TokenPickerLoadResult {
        guard cursor == nil else {
            Log.multichainSwap.i(
                "token picker pagination skipped",
                extraInfo: ["side": side.description]
            )
            return TokenPickerLoadResult(assets: [], nextCursor: nil)
        }

        Log.multichainSwap.i(
            "token picker loading started",
            extraInfo: [
                "side": side.description,
                "filter": filter.description,
                "limit": "\(limit)",
                "hasQuery": normalizedQuery(query) == nil ? "false" : "true",
            ]
        )

        switch side {
        case .source:
            return try await loadSourceAssets(query: query, filter: filter, limit: limit)
        case let .receive(sourceAssetId):
            return try await loadReceiveAssets(
                query: query,
                filter: filter,
                limit: limit,
                sourceAssetId: sourceAssetId
            )
        }
    }
}

private extension MultichainSwapTokenPickerModel {
    func loadSourceAssets(
        query: String?,
        filter: TokenPickerV2ChainFilter,
        limit: Int
    ) async throws(MultichainServiceError) -> TokenPickerLoadResult {
        let currency = currencyStore.state
        let assets = try await multichainService.getWalletAssets(
            state: multichainState,
            currencies: requestedCurrencyCodes(for: currency),
            assetIds: nil,
            capabilities: [.swap],
            chain: filter.chain,
            search: normalizedQuery(query),
            availableOnly: true,
            showHidden: false,
            hideDust: nil,
            limit: limit,
            cursor: nil
        ).assets

        Log.multichainSwap.i(
            "source token picker loaded",
            extraInfo: [
                "walletAssetCount": "\(assets.count)",
                "filter": filter.description,
                "hasQuery": normalizedQuery(query) == nil ? "false" : "true",
            ]
        )

        return TokenPickerLoadResult(
            assets: Array(assets),
            nextCursor: nil
        )
    }

    func loadReceiveAssets(
        query: String?,
        filter: TokenPickerV2ChainFilter,
        limit: Int,
        sourceAssetId: String
    ) async throws(MultichainServiceError) -> TokenPickerLoadResult {
        let catalogAssets: [MultichainSwapAsset]
        do {
            catalogAssets = try await multichainSwapService.listCrossSwapAssets(
                query: MultichainSwapAssetsQuery(
                    searchQuery: normalizedQuery(query),
                    limit: limit,
                    chain: filter.crossSwapChainId
                )
            )
        } catch {
            Log.multichainSwap.w(
                "receive token picker catalog loading failed",
                error: error,
                extraInfo: [
                    "sourceAsset": sourceAssetId,
                    "filter": filter.description,
                ]
            )
            throw .apiError(message: nil)
        }

        let walletAssets = await walletAssets(sourceAssetId: sourceAssetId)
        let walletAssetsById = Dictionary(
            walletAssets.map { ($0.asset.assetId, $0) },
            uniquingKeysWith: { current, _ in current }
        )

        let filtered = catalogAssets
            .filter { $0.assetId != sourceAssetId }
            .filter { matches(filter: filter, swapAsset: $0) }
            .prefix(limit)
            .map {
                $0.multichainAsset(
                    walletAsset: walletAssetsById[$0.assetId]
                )
            }

        Log.multichainSwap.i(
            "receive token picker loaded",
            extraInfo: [
                "sourceAsset": sourceAssetId,
                "catalogAssetCount": "\(catalogAssets.count)",
                "walletAssetCount": "\(walletAssets.count)",
                "resultCount": "\(filtered.count)",
                "filter": filter.description,
                "hasQuery": normalizedQuery(query) == nil ? "false" : "true",
            ]
        )

        return TokenPickerLoadResult(
            assets: Array(filtered),
            nextCursor: nil
        )
    }

    /// Balances only decorate the catalog, so a failure keeps the picker usable — but it silently
    /// drops every "you hold this" badge, which is worth knowing about.
    func walletAssets(sourceAssetId: String) async -> [MultichainAsset] {
        do {
            return try await multichainService.getAllWalletAssets(
                state: multichainState,
                currencies: requestedCurrencyCodes(for: currencyStore.state),
                capabilities: nil,
                chain: nil,
                search: nil,
                availableOnly: nil,
                showHidden: false,
                hideDust: nil
            ).assets
        } catch {
            Log.multichainSwap.failure(
                "receive token picker wallet balances unavailable",
                error: error,
                extraInfo: ["sourceAsset": sourceAssetId]
            )
            return []
        }
    }

    func normalizedQuery(_ query: String?) -> String? {
        guard let query else {
            return nil
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func matches(
        filter: TokenPickerV2ChainFilter,
        swapAsset: MultichainSwapAsset
    ) -> Bool {
        guard let chain = MultichainChain(assetIdChain: swapAsset.chainIdChain) else {
            return filter == .all
        }
        return filter.includes(chain: chain)
    }
}

private extension TokenPickerV2ChainFilter {
    var crossSwapChainId: String? {
        guard let chain else {
            return nil
        }
        return "\(chain.rawValue)/mainnet"
    }
}
