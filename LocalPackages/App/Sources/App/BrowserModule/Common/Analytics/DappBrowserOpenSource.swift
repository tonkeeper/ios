import TKCore

enum DappBrowserOpenSource {
    case wallet
    case history
    case deepLink
    case story
}

extension DappBrowserOpenSource {
    var analyticsValue: DappBrowserOpen.From {
        switch self {
        case .wallet:
            return .wallet
        case .history:
            return .history
        case .deepLink:
            return .deepLink
        case .story:
            return .story
        }
    }
}
