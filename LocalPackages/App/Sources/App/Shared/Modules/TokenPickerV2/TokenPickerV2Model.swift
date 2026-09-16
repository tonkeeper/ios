import Foundation
import KeeperCore

struct TokenPickerLoadResult: Equatable {
    let assets: [MultichainAsset]
    let nextCursor: String?
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
}

extension TokenPickerV2Model {
    func loadFilters() async throws(MultichainServiceError) -> [TokenPickerV2ChainFilter]? {
        nil
    }
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
