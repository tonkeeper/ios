import KeeperCore
import TKCoordinator
import TKCore
import TKLocalize
import TKScreenKit
import TKUIKit
import TonSwift
import UIKit

public final class BrowserCoordinator: RouterCoordinator<NavigationControllerRouter> {
    public var didHandleDeeplink: ((_ deeplink: Deeplink) -> Void)?
    public var didRequestOpenBuySell: ((_ wallet: Wallet) -> Void)?

    private var browserInput: BrowserModuleInput?

    private let coreAssembly: TKCore.CoreAssembly
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly

    public init(
        router: NavigationControllerRouter,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) {
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
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
}

private extension BrowserCoordinator {
    func openBrowser() {
        let module = BrowserAssembly.module(keeperCoreAssembly: keeperCoreMainAssembly, coreAssembly: coreAssembly)

        module.output.didTapSearch = { [weak self] in
            self?.openSearch()
        }

        module.output.didSelectCategory = { [weak self] category in
            self?.openCategory(category)
        }

        module.output.didSelectDapp = { [weak self, unowned router] dapp in
            self?.openDapp(dapp, fromViewController: router.rootViewController)
        }

        module.output.didOpenDeeplink = { [weak self] deeplink in
            self?.didHandleDeeplink?(deeplink)
        }

        browserInput = module.input

        router.push(viewController: module.view, animated: false)
    }

    func openCategory(_ category: PopularAppsCategory) {
        let module = BrowserCategoryAssembly.module(category: category)

        module.output.didSelectDapp = { [weak self, unowned router] dapp in
            self?.openDapp(dapp, fromViewController: router.rootViewController)
        }

        module.output.didTapSearch = { [weak self] in
            self?.openSearch()
        }

        module.view.setupBackButton()

        router.push(viewController: module.view)
    }

    func openDapp(_ dapp: Dapp, fromViewController: UIViewController) {
        let router = ViewControllerRouter(rootViewController: fromViewController)
        let coordinator = DappCoordinator(
            router: router,
            dapp: dapp,
            isSilentConnect: false,
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        coordinator.didHandleDeeplink = { [weak self] deeplink in
            _ = self?.didHandleDeeplink?(deeplink)
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
        let module = BrowserSearchAssembly.module(keeperCoreAssembly: keeperCoreMainAssembly)
        let navigationController = TKNavigationController(rootViewController: module.view)
        navigationController.configureDefaultAppearance()
        module.output.didSelectDapp = { [weak self, unowned navigationController] dapp in
            self?.openDapp(dapp, fromViewController: navigationController)
        }

        navigationController.modalTransitionStyle = .crossDissolve
        navigationController.modalPresentationStyle = .fullScreen
        router.present(navigationController)
    }
}

public extension BrowserCoordinator {
    @MainActor
    func openDefi() {
        let browserController = keeperCoreMainAssembly.browserExploreController()
        let lang = Locale.current.languageCode ?? "en"
        guard let defiCategory = try? browserController.getCachedPopularApps(lang: lang).defiCategory else {
            return
        }
        openCategory(defiCategory)
    }
}
