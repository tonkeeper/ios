import KeeperCore
import TKCoordinator
import TKCore
import TKFeatureFlags
import TKLocalize
import TKLogging
import TKScreenKit
import TKUIKit
import TonSwift
import UIKit

public final class BrowserCoordinator: RouterCoordinator<NavigationControllerRouter> {
    public var didHandleDeeplink: ((_ deeplink: Deeplink, _ utm: UtmParameters) -> Void)?
    public var didRequestOpenBuySell: ((_ wallet: Wallet) -> Void)?

    private var browserInput: BrowserModuleInput?

    private let coreAssembly: TKCore.CoreAssembly
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let analyticsController: DappBrowserAnalyticsController

    init(
        router: NavigationControllerRouter,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        analyticsController: DappBrowserAnalyticsController
    ) {
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.analyticsController = analyticsController
        super.init(router: router)
        router.rootViewController.tabBarItem.title = TKLocales.Tabs.browser
        router.rootViewController.tabBarItem.image = .TKUIKit.Icons.Size28.explore
    }

    override public func start() {
        openBrowser()
    }

    func openExplore() {
        browserInput?.openExplore()
    }

    func selectExploreNetworkFilter(_ chain: MultichainChain) {
        browserInput?.selectExploreNetworkFilter(chain)
    }
}

private extension BrowserCoordinator {
    func openBrowser() {
        let module = BrowserMultichainAssembly.module(
            keeperCoreAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            analyticsController: analyticsController
        )

        module.output.didTapSearch = { [weak self] in
            self?.openSearch()
        }

        module.output.didSelectCategory = { [weak self] category, selectedChain in
            self?.openCategory(category, selectedChain: selectedChain)
        }

        module.output.didSelectDapp = { [weak self, unowned router] request in
            self?.openDapp(request, fromViewController: router.rootViewController)
        }

        module.output.didOpenDeeplink = { [weak self] deeplink, utm in
            self?.didHandleDeeplink?(deeplink, utm)
        }

        browserInput = module.input

        router.push(viewController: module.view, animated: false)
    }

    func openCategory(_ category: PopularAppsCategory, selectedChain: MultichainChain?) {
        let module = BrowserCategoryMultichainAssembly.module(
            category: category,
            walletStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
            supportedChains: keeperCoreMainAssembly.multichainAssembly.supportedChains,
            initialChain: selectedChain
        )

        module.output.didSelectDapp = { [weak self, unowned router] intent in
            self?.openDapp(intent, fromViewController: router.rootViewController)
        }

        module.output.didTapSearch = { [weak self] in
            self?.openSearch()
        }

        router.push(viewController: module.view)
    }

    func openDapp(_ intent: DappOpenIntent, fromViewController: UIViewController) {
        guard let request = analyticsController.openRequest(from: intent) else {
            return Log.e("failed to create dapp open request from intent", extraInfo: [
                "url": intent.description,
            ])
        }
        openDapp(request, fromViewController: fromViewController)
    }

    func openDapp(_ request: DappOpenRequest, fromViewController: UIViewController) {
        let router = ViewControllerRouter(rootViewController: fromViewController)
        let coordinator = DappCoordinator(
            router: router,
            dapp: request.dapp,
            analyticsSession: request.analyticsSession,
            isSilentConnect: false,
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        coordinator.didHandleDeeplink = { [weak self] deeplink, utm in
            _ = self?.didHandleDeeplink?(deeplink, utm)
        }

        coordinator.didRequestOpenBuySell = { [weak self, weak coordinator] wallet, isInternalPurchasing in
            self?.removeChild(coordinator)
            if isInternalPurchasing {
                self?.didRequestOpenBuySell?(wallet)
            } else {
                self?.openDefi()
            }
        }

        addChild(coordinator)
        coordinator.start()
    }

    func openSearch() {
        let module = BrowserSearchAssembly.module(
            keeperCoreAssembly: keeperCoreMainAssembly
        )
        let navigationController = TKNavigationController(rootViewController: module.view)
        navigationController.configureDefaultAppearance()
        module.output.didSelectDapp = { [weak self, unowned navigationController] request in
            self?.openDapp(request, fromViewController: navigationController)
        }
        module.output.didUpdateSearchTarget = { [weak self] targetURL in
            self?.analyticsController.searchInputTargetChanged(targetURL)
        }
        module.output.didSelectSearchResult = { [weak self] url in
            self?.analyticsController.logSearchClick(url: url)
        }

        navigationController.modalTransitionStyle = .crossDissolve
        navigationController.modalPresentationStyle = .fullScreen
        router.present(navigationController)
    }
}

extension BrowserCoordinator {
    func logBrowserOpen(from: DappBrowserOpenSource, utm: UtmParameters = .empty) {
        analyticsController.logBrowserOpen(
            from: from,
            tab: browserInput?.selectedBrowserTab ?? .explore,
            utm: utm
        )
    }

    @MainActor
    func openDefi() {
        let browserController = keeperCoreMainAssembly.browserExploreController()
        let lang = Locale.current.languageCode ?? "en"
        guard let defiCategory = try? browserController.getCachedPopularApps(lang: lang).defiCategory else {
            return
        }
        openCategory(defiCategory, selectedChain: nil)
    }
}
