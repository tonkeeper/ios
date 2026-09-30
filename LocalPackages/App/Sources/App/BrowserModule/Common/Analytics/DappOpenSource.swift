import TKCore

enum DappOpenSource {
    case banner
    case browser
    case browserSearch
    case browserConnected
    case push
    case sidebar
    case deepLink
    case history
    case collectibles
    case tonconnect
}

extension DappOpenSource {
    var analyticsValue: DappAppFrom {
        switch self {
        case .banner:
            return .banner
        case .browser:
            return .browser
        case .browserSearch:
            return .browserSearch
        case .browserConnected:
            return .browserConnected
        case .push:
            return .push
        case .sidebar:
            return .sidebar
        case .deepLink:
            return .deepLink
        case .history:
            return .history
        case .collectibles:
            return .collectibles
        case .tonconnect:
            return .tonconnect
        }
    }
}
