import KeeperCore
import TKUIKit

struct TradeShelfViewData: Identifiable {
    var id: String
    var title: String
    var groups: [TradeShelfGroupViewData]

    var grids: [TradeShelfGridViewData] {
        groups.first?.grids ?? []
    }
}
