import Foundation
import KeeperCore
import TKCoordinator
import TKLogging

extension MainCoordinator {
    func openDapp(
        title: String?,
        url: URL,
        analyticsFrom: DappOpenSource,
        isSilentConnect: Bool = false
    ) {
        let dapp = makeDapp(title: title, url: url)
        let request = dappBrowserAnalyticsController.directOpenRequest(source: analyticsFrom, dapp: dapp)
        openDapp(request, isSilentConnect: isSilentConnect)
    }

    func openDapp(
        popularApp: PopularApp,
        url: URL,
        analyticsFrom: DappOpenSource,
        catalogMode: DappCatalogMode,
        isSilentConnect: Bool = false
    ) {
        let dapp = makeDapp(popularApp: popularApp, url: url)
        guard let request = dappBrowserAnalyticsController.openRequest(
            source: analyticsFrom,
            popularApp: popularApp,
            catalogMode: catalogMode,
            dapp: dapp
        ) else {
            Log.e("failed to create popular dapp open request", extraInfo: [
                "url": url.absoluteString,
                "app_id": popularApp.id,
            ])
            openDapp(
                title: popularApp.name,
                url: url,
                analyticsFrom: analyticsFrom,
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
        isSilentConnect: Bool = false
    ) {
        let controllerRouter = ViewControllerRouter(rootViewController: router.rootViewController)
        let coordinator = DappCoordinator(
            router: controllerRouter,
            dapp: request.dapp,
            analyticsSession: request.analyticsSession,
            isSilentConnect: isSilentConnect,
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        coordinator.didHandleDeeplink = { [weak self] deeplink in
            _ = self?.handleTonkeeperDeeplink(deeplink, fromStories: false, sendSource: .deepLink)
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
