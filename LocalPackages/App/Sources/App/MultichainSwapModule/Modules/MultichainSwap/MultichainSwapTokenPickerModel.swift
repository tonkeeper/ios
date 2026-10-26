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
    private let currencyStore: CurrencyStore

    let initialState: TokenPickerV2ModelState

    let showsCatalogSortControl = false
    private(set) var catalogSearchSort: MultichainAssetSearchSort = .marketCap

    init(
        side: MultichainSwapTokenPickerSide,
        multichainState: MultichainWalletState,
        selectedAsset: MultichainAsset?,
        multichainService: MultichainService,
        currencyStore: CurrencyStore
    ) {
        self.side = side
        self.multichainState = multichainState
        self.multichainService = multichainService
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
            return try await loadSourceAssets(query: query, filter: filter, limit: limit, cursor: cursor)
        case let .receive(sourceAssetId):
            return try await loadReceiveAssets(
                query: query,
                filter: filter,
                limit: limit,
                cursor: cursor,
                sourceAssetId: sourceAssetId
            )
        }
    }
}

private extension MultichainSwapTokenPickerModel {
    func loadSourceAssets(
        query: String?,
        filter: TokenPickerV2ChainFilter,
        limit: Int,
        cursor: String?
    ) async throws(MultichainServiceError) -> TokenPickerLoadResult {
        let currency = currencyStore.state
        let page = try await multichainService.getWalletAssets(
            state: multichainState,
            currencies: requestedCurrencyCodes(for: currency),
            assetIds: nil,
            capabilities: [.swap],
            chain: filter.chain,
            search: normalizedQuery(query),
            availableOnly: true,
            showHidden: false,
            showAll: nil,
            hideDust: false,
            limit: limit,
            cursor: cursor
        )

        Log.multichainSwap.i(
            "source token picker loaded",
            extraInfo: [
                "walletAssetCount": "\(page.assets.count)",
                "filter": filter.description,
                "hasQuery": normalizedQuery(query) == nil ? "false" : "true",
            ]
        )

        return TokenPickerLoadResult(
            assets: page.assets,
            nextCursor: page.nextCursor
        )
    }

    func loadReceiveAssets(
        query: String?,
        filter: TokenPickerV2ChainFilter,
        limit: Int,
        cursor: String?,
        sourceAssetId: String
    ) async throws(MultichainServiceError) -> TokenPickerLoadResult {
        let page = try await multichainService.getWalletAssets(
            state: multichainState,
            currencies: requestedCurrencyCodes(for: currencyStore.state),
            assetIds: nil,
            capabilities: [.swap],
            chain: filter.chain,
            search: normalizedQuery(query),
            availableOnly: false,
            showHidden: true,
            showAll: true,
            hideDust: false,
            limit: limit,
            cursor: cursor
        )
        let assets = page.assets.filter { $0.asset.assetId != sourceAssetId }

        Log.multichainSwap.i(
            "receive token picker loaded",
            extraInfo: [
                "sourceAsset": sourceAssetId,
                "assetCount": "\(assets.count)",
                "filter": filter.description,
                "hasQuery": normalizedQuery(query) == nil ? "false" : "true",
            ]
        )

        return TokenPickerLoadResult(
            assets: assets,
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
}
