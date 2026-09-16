import KeeperCore
import TKCore

enum DappOpenIntent {
    case popularApp(
        source: DappOpenSource,
        app: PopularApp,
        catalogMode: DappCatalogMode
    )
    case dapp(
        source: DappOpenSource,
        dapp: Dapp
    )
}

extension DappOpenIntent: CustomStringConvertible {
    var description: String {
        switch self {
        case let .popularApp(source, app, catalogMode):
            "popularApp <\(source.analyticsValue.rawValue):\(app.url?.absoluteString ?? "nil"):\(catalogMode)>"
        case let .dapp(source, dapp):
            "dApp <\(source.analyticsValue.rawValue):\(dapp.url.absoluteString)>"
        }
    }
}
