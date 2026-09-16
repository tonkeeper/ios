import TKCore

enum DappBrowserTab {
    case explore
    case connected
}

extension DappBrowserTab {
    var analyticsValue: DappBrowserOpen.ModelType {
        switch self {
        case .explore:
            return .explore
        case .connected:
            return .connected
        }
    }

    var tabClickAnalyticsValue: DappBrowserTabClick.ModelType {
        switch self {
        case .explore:
            return .explore
        case .connected:
            return .connected
        }
    }
}
