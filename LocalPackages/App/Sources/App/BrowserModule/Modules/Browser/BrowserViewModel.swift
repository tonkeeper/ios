import KeeperCore

@MainActor
protocol BrowserModuleInput: AnyObject {
    var selectedBrowserTab: DappBrowserTab { get }

    func openExplore()
    func selectExploreNetworkFilter(_ chain: MultichainChain)
}

@MainActor
protocol BrowserModuleOutput: AnyObject {
    var didTapSearch: (() -> Void)? { get set }
    var didSelectCategory: ((PopularAppsCategory, MultichainChain?) -> Void)? { get set }
    var didSelectDapp: ((DappOpenIntent) -> Void)? { get set }
    var didOpenDeeplink: ((_ deeplink: Deeplink, _ utm: UtmParameters) -> Void)? { get set }
}
