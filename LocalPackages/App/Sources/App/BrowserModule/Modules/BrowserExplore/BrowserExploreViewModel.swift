import KeeperCore

@MainActor
protocol BrowserExploreModuleInput: AnyObject {
    var isExploreTabVisible: Bool { get }
    var canShowExploreTab: Bool { get }

    func selectNetworkFilter(_ chain: MultichainChain)
}

@MainActor
protocol BrowserExploreModuleOutput: AnyObject {
    var didSelectCategory: ((PopularAppsCategory, MultichainChain?) -> Void)? { get set }
    var didSelectDapp: ((DappOpenIntent) -> Void)? { get set }
    var didOpenDeeplink: ((_ deeplink: Deeplink, _ utm: UtmParameters) -> Void)? { get set }
    var didUpdateExploreTabVisible: ((Bool) -> Void)? { get set }
}
