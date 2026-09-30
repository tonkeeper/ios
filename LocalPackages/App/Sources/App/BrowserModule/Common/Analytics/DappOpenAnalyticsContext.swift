import KeeperCore
import TKCore

struct DappOpenAnalyticsContext: Equatable {
    var from: DappAppFrom
    var urlDomain: String
    var assetChain: AssetChain
    var appId: String
    var bannerId: String?
    var location: String
    var utm: UtmParameters = .empty
}
