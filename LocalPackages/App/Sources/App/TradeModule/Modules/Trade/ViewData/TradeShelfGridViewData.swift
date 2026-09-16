import KeeperCore
import TKUIKit

struct TradeShelfGridViewData: Identifiable {
    var id: String
    var name: String
    var items: [TradeShelfAssetViewData]
    var seeAllCategory: TradingAssetCategory?
    var initialCatalogSearchSort: MultichainAssetSearchSort

    var seeAllEnabled: Bool {
        seeAllCategory != nil
    }
}
