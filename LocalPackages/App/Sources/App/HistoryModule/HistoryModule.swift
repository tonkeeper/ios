import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit
import TonSwift
import UIKit

@MainActor
struct HistoryModule {
    private let dependencies: Dependencies
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func createHistoryCoordinator(
        routerOrNil: NavigationControllerRouter?,
        presentationStyle: HistoryPresentationStyle
    ) -> HistoryCoordinator {
        let router: NavigationControllerRouter
        if let routerOrNil {
            router = routerOrNil
        } else {
            let navigationController = TKNavigationController()
            navigationController.configureTransparentAppearance()
            navigationController.setNavigationBarHidden(true, animated: false)
            router = NavigationControllerRouter(
                rootViewController: navigationController
            )
        }
        return HistoryCoordinator(
            router: router,
            coreAssembly: dependencies.coreAssembly,
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
            recipientResolver: dependencies.keeperCoreMainAssembly.loadersAssembly.recipientResolver(),
            presentationStyle: presentationStyle
        )
    }

    func createTonHistoryListModule(
        wallet: Wallet
    ) -> MVVMModule<HistoryListViewController, HistoryListModuleOutput, HistoryListModuleInput> {
        return HistoryListAssembly.module(
            wallet: wallet,
            paginationLoader: dependencies.keeperCoreMainAssembly.loadersAssembly.historyTonEventsPaginationLoader(
                wallet: wallet
            ),
            cacheProvider: HistoryListTonEventsCacheProvider(historyService: dependencies.keeperCoreMainAssembly.servicesAssembly.historyService()),
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
            historyEventMapper: HistoryEventMapper(accountEventActionContentProvider: HistoryListAccountEventActionContentProvider()),
            filter: .all,
            emptyViewProvider: nil
        )
    }

    func createJettonHistoryListModule(
        jettonMasterAddress: Address,
        wallet: Wallet
    ) -> MVVMModule<HistoryListViewController, HistoryListModuleOutput, HistoryListModuleInput> {
        return HistoryListAssembly.module(
            wallet: wallet,
            paginationLoader: dependencies.keeperCoreMainAssembly.loadersAssembly.historyJettonEventsPaginationLoader(
                wallet: wallet,
                jettonMasterAddress: jettonMasterAddress
            ),
            cacheProvider: HistoryListJettonEventsCacheProvider(
                jettonMasterAddress: jettonMasterAddress,
                historyService: dependencies.keeperCoreMainAssembly.servicesAssembly.historyService()
            ),
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
            historyEventMapper: HistoryEventMapper(accountEventActionContentProvider: HistoryListAccountEventActionContentProvider()),
            filter: .all,
            emptyViewProvider: nil
        )
    }

    func createTronUSDTHistoryListModule(
        wallet: Wallet
    ) -> MVVMModule<HistoryListViewController, HistoryListModuleOutput, HistoryListModuleInput> {
        return HistoryListAssembly.module(
            wallet: wallet,
            paginationLoader: dependencies.keeperCoreMainAssembly.loadersAssembly.historyTronUSDTEventsPaginationLoader(
                wallet: wallet
            ),
            cacheProvider: HistoryListTronEventsCacheProvider(
                historyService: dependencies.keeperCoreMainAssembly.servicesAssembly.tronUSDTHistoryService()
            ),
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
            historyEventMapper: HistoryEventMapper(accountEventActionContentProvider: HistoryListAccountEventActionContentProvider()),
            filter: .all,
            emptyViewProvider: nil
        )
    }

    func createTronTRXHistoryListModule(
        wallet: Wallet
    ) -> MVVMModule<HistoryListViewController, HistoryListModuleOutput, HistoryListModuleInput> {
        return HistoryListAssembly.module(
            wallet: wallet,
            paginationLoader: dependencies.keeperCoreMainAssembly.loadersAssembly.historyTronTRXEventsPaginationLoader(
                wallet: wallet
            ),
            cacheProvider: HistoryListTronEventsCacheProvider(
                historyService: dependencies.keeperCoreMainAssembly.servicesAssembly.tronTRXHistoryService()
            ),
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
            historyEventMapper: HistoryEventMapper(accountEventActionContentProvider: HistoryListAccountEventActionContentProvider()),
            filter: .all,
            emptyViewProvider: nil
        )
    }
}

extension HistoryModule {
    struct Dependencies {
        let coreAssembly: TKCore.CoreAssembly
        let keeperCoreMainAssembly: KeeperCore.MainAssembly

        init(
            coreAssembly: TKCore.CoreAssembly,
            keeperCoreMainAssembly: KeeperCore.MainAssembly
        ) {
            self.coreAssembly = coreAssembly
            self.keeperCoreMainAssembly = keeperCoreMainAssembly
        }
    }
}
