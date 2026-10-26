import Foundation
import KeeperCore
import TKCoordinator
import TKLogging
import TKUIKit
import UIKit

extension MainCoordinator {
    func openDapp(
        title: String?,
        url: URL,
        analyticsFrom: DappOpenSource,
        utm: UtmParameters = .empty,
        isSilentConnect: Bool = false
    ) {
        let dapp = makeDapp(title: title, url: url)
        let request = dappBrowserAnalyticsController.directOpenRequest(
            source: analyticsFrom,
            dapp: dapp,
            utm: utm
        )
        openDapp(request, isSilentConnect: isSilentConnect)
    }

    func openEarnDapp(url: URL, analyticsFrom: DappOpenSource, on navigationController: UINavigationController?) {
        let dapp = makeDapp(title: nil, url: url)
        let request = dappBrowserAnalyticsController.directOpenRequest(source: analyticsFrom, dapp: dapp)
        let hostNavigationController = (navigationController ?? router.rootViewController.navigationController)?
            .tabBarHostNavigationController
        openDapp(request, presentation: hostNavigationController.map(DappPresentation.push) ?? .modal)
    }

    func openDapp(
        popularApp: PopularApp,
        url: URL,
        analyticsFrom: DappOpenSource,
        catalogMode: DappCatalogMode,
        utm: UtmParameters = .empty,
        isSilentConnect: Bool = false
    ) {
        let dapp = makeDapp(popularApp: popularApp, url: url)
        guard let request = dappBrowserAnalyticsController.openRequest(
            source: analyticsFrom,
            popularApp: popularApp,
            catalogMode: catalogMode,
            dapp: dapp,
            utm: utm
        ) else {
            Log.e("failed to create popular dapp open request", extraInfo: [
                "url": url.absoluteString,
                "app_id": popularApp.id,
            ])
            openDapp(
                title: popularApp.name,
                url: url,
                analyticsFrom: analyticsFrom,
                utm: utm,
                isSilentConnect: isSilentConnect
            )
            return
        }

        openDapp(request, isSilentConnect: isSilentConnect)
    }
}

private extension MainCoordinator {
    func openDapp(
        _ request: DappOpenRequest,
        isSilentConnect: Bool = false,
        presentation: DappPresentation = .modal
    ) {
        let rootViewController: UIViewController = switch presentation {
        case .modal:
            router.rootViewController
        case let .push(navigationController):
            navigationController
        }
        let controllerRouter = ViewControllerRouter(rootViewController: rootViewController)
        let coordinator = DappCoordinator(
            router: controllerRouter,
            dapp: request.dapp,
            analyticsSession: request.analyticsSession,
            isSilentConnect: isSilentConnect,
            presentation: presentation,
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        coordinator.didHandleDeeplink = { [weak self] deeplink, utm in
            _ = self?.handleTonkeeperDeeplink(deeplink, fromStories: false, sendSource: .deepLink(utm: utm))
        }
        coordinator.didFinish = { [weak self] finished in
            self?.removeChild(finished)
        }

        addChild(coordinator)
        coordinator.start()
    }

    func makeDapp(title: String?, url: URL) -> Dapp {
        Dapp(
            name: title ?? "",
            description: "",
            icon: nil,
            poster: nil,
            url: url,
            textColor: nil,
            excludeCountries: nil,
            includeCountries: nil
        )
    }

    func makeDapp(popularApp: PopularApp, url: URL) -> Dapp {
        Dapp(
            name: popularApp.name,
            description: popularApp.description,
            icon: popularApp.icon,
            poster: popularApp.poster,
            url: url,
            textColor: popularApp.textColor,
            excludeCountries: popularApp.excludeCountries,
            includeCountries: popularApp.includeCountries
        )
    }
}
