import Foundation
import KeeperCore
import PerpsModels

struct TokenPickerLoadResult: Equatable {
    enum Item: Equatable {
        case asset(MultichainAsset)
        case perp(PerpsMarketSummary)
    }

    let items: [Item]
    let nextCursor: String?

    init(items: [Item], nextCursor: String?) {
        self.items = items
        self.nextCursor = nextCursor
    }

    init(assets: [MultichainAsset], nextCursor: String?) {
        self.init(items: assets.map { .asset($0) }, nextCursor: nextCursor)
    }

    var assets: [MultichainAsset] {
        items.compactMap { item in
            if case let .asset(asset) = item {
                return asset
            }
            return nil
        }
    }
}

protocol TokenPickerV2Model: AnyObject {
    var initialState: TokenPickerV2ModelState { get }

    func loadAssets(
        query: String?,
        filter: TokenPickerV2ChainFilter,
        limit: Int,
        cursor: String?
    ) async throws(MultichainServiceError) -> TokenPickerLoadResult

    /// When non-`nil`, replaces chain tabs after the screen opens. Default keeps `initialState`.
    func loadFilters() async throws(MultichainServiceError) -> [TokenPickerV2ChainFilter]?

    var showsCatalogSortControl: Bool { get }
    var catalogSearchSort: MultichainAssetSearchSort { get }
    func setCatalogSearchSort(_ sort: MultichainAssetSearchSort)

    var perpsSearchSort: PerpsMarketsSort { get }
    func setPerpsSearchSort(_ sort: PerpsMarketsSort)

    /// Empty hides the asset type selector.
    var assetTypes: [TokenPickerV2AssetType] { get }
    var assetType: TokenPickerV2AssetType { get }
    func setAssetType(_ assetType: TokenPickerV2AssetType)
}

extension TokenPickerV2Model {
    func loadFilters() async throws(MultichainServiceError) -> [TokenPickerV2ChainFilter]? {
        nil
    }

    var perpsSearchSort: PerpsMarketsSort {
        .volume
    }

    func setPerpsSearchSort(_ sort: PerpsMarketsSort) {}

    var assetTypes: [TokenPickerV2AssetType] {
        []
    }

    var assetType: TokenPickerV2AssetType {
        .category(.all)
    }

    func setAssetType(_ assetType: TokenPickerV2AssetType) {}
}

enum TokenPickerV2AssetType: Hashable {
    case category(TradingAssetCategory)
    case perpetuals

    var category: TradingAssetCategory {
        if case let .category(category) = self { return category }
        return .all
    }
}

struct TokenPickerV2ModelState {
    let filters: [TokenPickerV2ChainFilter]
    let displayMode: SendTokenV2PickerDisplayMode
    let initialFilter: TokenPickerV2ChainFilter
}

extension MultichainWalletState {
    var tokenPickerV2Filters: [TokenPickerV2ChainFilter] {
        [.all] + MultichainChain.orderedByDisplayOrder(addresses.map(\.chain)).map(TokenPickerV2ChainFilter.chain)
    }

    func tokenPickerV2Accounts(
        for filter: TokenPickerV2ChainFilter
    ) -> [MultichainAccount] {
        return addresses.compactMap { address -> MultichainAccount? in
            guard filter.includes(chain: address.chain) else {
                return nil
            }

            return MultichainAccount(
                chain: address.chain,
                network: .mainnet,
                address: address.address
            )
        }
    }
}
