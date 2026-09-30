import Foundation
import KeeperCore

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
}

extension TokenPickerV2Model {
    func loadFilters() async throws(MultichainServiceError) -> [TokenPickerV2ChainFilter]? {
        nil
    }

    var perpsSearchSort: PerpsMarketsSort {
        .volume
    }

    func setPerpsSearchSort(_ sort: PerpsMarketsSort) {}
}

struct TokenPickerV2ModelState {
    let filters: [TokenPickerV2ChainFilter]
    let displayMode: SendTokenV2PickerDisplayMode
    let initialFilter: TokenPickerV2ChainFilter
}

extension MultichainWalletState {
    var tokenPickerV2Filters: [TokenPickerV2ChainFilter] {
        var filters: [TokenPickerV2ChainFilter] = [.all]
        var seenChains = Set<MultichainChain>()

        for address in addresses {
            guard seenChains.insert(address.chain).inserted else {
                continue
            }
            filters.append(.chain(address.chain))
        }

        return filters
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
