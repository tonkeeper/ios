import Foundation
import KeeperCore
import TKCoordinator
import TKCore

struct DeeplinkOpenAnalyticsContext: Equatable {
    let link: String
    let isColdStart: Bool
}

struct PendingDeeplinkState {
    private(set) var deeplink: CoordinatorDeeplink?
    private(set) var analyticsContexts = [DeeplinkOpenAnalyticsContext]()

    mutating func append(_ deeplink: CoordinatorDeeplink?, isColdStart: Bool) {
        self.deeplink = deeplink
        guard let link = deeplink as? String else { return }
        analyticsContexts.append(
            DeeplinkOpenAnalyticsContext(link: link, isColdStart: isColdStart)
        )
    }

    mutating func drain() -> PendingDeeplinkState {
        defer { self = PendingDeeplinkState() }
        return self
    }
}

extension DeeplinkOpen.From {
    /// Universal links reach the app over `https`; every other scheme we register
    /// (`tonkeeper://`, `ton://`, `tc://`, …) is an app link.
    init(link: String) {
        let scheme = URLComponents(string: link)?.scheme?.lowercased()
        self = scheme == "https" || scheme == "http" ? .universalLink : .appLink
    }
}

extension DeeplinkOpen.LinkType {
    init(deeplink: Deeplink) {
        switch deeplink {
        case .transfer: self = .transfer
        case .staking: self = .staking
        case .pool: self = .pool
        case .swap: self = .swap
        case .deposit: self = .deposit
        case .withdraw: self = .withdraw
        case .action: self = .action
        case .publish: self = .publish
        case .externalSign: self = .externalSign
        case .tonconnect: self = .tonconnect
        case .walletConnect: self = .walletConnect
        case .dapp: self = .dapp
        case .battery: self = .battery
        case .browser: self = .browser
        case .migration: self = .migration
        case .trading: self = .trading
        case .tradeAsset: self = .tradeAsset
        case .story: self = .story
        case .receive: self = .receive
        case .backup: self = .backup
        case .addWallet: self = .addWallet
        case .main: self = .main
        case .raffle: self = .raffle
        }
    }
}
