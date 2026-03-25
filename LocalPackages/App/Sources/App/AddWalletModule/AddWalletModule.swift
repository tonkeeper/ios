import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit
import TonSwift
import TonTransport
import TONWalletKit
import UIKit

@MainActor
struct AddWalletModule {
    private let dependencies: Dependencies
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func createAddWalletCoordinator(
        options: [AddWalletOption],
        router: ViewControllerRouter
    ) -> AddWalletCoordinator {
        return AddWalletCoordinator(
            router: router,
            options: options,
            configurationAssembly: dependencies.configurationAssembly,
            walletAddController: dependencies.walletsUpdateAssembly.walletAddController(),
            createWalletCoordinatorProvider: { router in
                createCreateWalletCoordinator(router: router)
            },
            importWalletCoordinatorProvider: { router, network in
                createImportWalletCoordinator(router: router, network: network)
            },
            importWatchOnlyWalletCoordinatorProvider: { router in
                createImportWatchOnlyWalletCoordinator(router: router)
            }, pairSignerCoordinatorProvider: { router in
                createPairSignerCoordinator(router: router)
            }, pairLedgerCoordinatorProvider: { router in
                createLedgerPairCoordinator(router: router)
            },
            pairKeystoneCoordinatorProvider: { router in
                createPairKeystoneCoordinator(router: router)
            }
        )
    }

    func createCreateWalletCoordinator(router: ViewControllerRouter) -> CreateWalletCoordinator {
        return CreateWalletCoordinator(
            router: router,
            analyticsProvider: dependencies.coreAssembly.analyticsProvider,
            walletsUpdateAssembly: dependencies.walletsUpdateAssembly,
            storesAssembly: dependencies.storesAssembly,
            customizeWalletModule: {
                self.createCustomizeWalletModule(
                    name: nil,
                    tintColor: nil,
                    icon: nil,
                    configurator: AddWalletCustomizeWalletViewModelConfigurator()
                )
            }
        )
    }

    func createAddDifferentRevisionWalletCoordinator(
        wallet: Wallet,
        revisionToAdd: WalletContractVersion,
        router: ViewControllerRouter
    ) -> AddDifferentVersionWalletCoordinator {
        return AddDifferentVersionWalletCoordinator(
            router: router,
            revisionToAdd: revisionToAdd,
            wallet: wallet,
            securityStore: dependencies.storesAssembly.securityStore,
            mnemonicsRepository: dependencies.walletsUpdateAssembly.secureAssembly.mnemonicsRepository(),
            addController: dependencies.walletsUpdateAssembly.walletAddController(),
            analyticsProvider: dependencies.coreAssembly.analyticsProvider
        )
    }

    func createImportWalletCoordinator(router: NavigationControllerRouter, network: Network) -> ImportWalletCoordinator {
        return ImportWalletCoordinator(
            router: router,
            analyticsProvider: dependencies.coreAssembly.analyticsProvider,
            walletsUpdateAssembly: dependencies.walletsUpdateAssembly,
            storesAssembly: dependencies.storesAssembly,
            network: network,
            customizeWalletModule: {
                self.createCustomizeWalletModule(
                    name: nil,
                    tintColor: nil,
                    icon: nil,
                    configurator: AddWalletCustomizeWalletViewModelConfigurator()
                )
            }
        )
    }

    func createCustomizeWalletModule(
        name: String? = nil,
        tintColor: WalletTintColor? = nil,
        icon: WalletIcon? = nil,
        configurator: CustomizeWalletViewModelConfigurator
    ) -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void> {
        return CustomizeWalletAssembly.module(
            name: name,
            tintColor: tintColor,
            icon: icon,
            configurator: configurator
        )
    }

    func createKeystoneImportCoordinator(
        publicKey: TonSwift.PublicKey,
        xfp: String?,
        path: String?,
        name: String,
        router: NavigationControllerRouter
    ) -> KeystoneImportCoordinator {
        KeystoneImportCoordinator(
            publicKey: publicKey,
            xfp: xfp,
            path: path,
            name: name,
            router: router,
            walletsUpdateAssembly: dependencies.walletsUpdateAssembly,
            customizeWalletModule: {
                self.createCustomizeWalletModule(
                    name: name,
                    tintColor: nil,
                    icon: nil,
                    configurator: AddWalletCustomizeWalletViewModelConfigurator()
                )
            }
        )
    }

    func createPublicKeyImportCoordinator(
        publicKey: TonSwift.PublicKey,
        name: String,
        router: NavigationControllerRouter
    ) -> PublicKeyImportCoordinator {
        PublicKeyImportCoordinator(
            publicKey: publicKey,
            name: name,
            router: router,
            walletsUpdateAssembly: dependencies.walletsUpdateAssembly,
            customizeWalletModule: {
                self.createCustomizeWalletModule(
                    name: name,
                    tintColor: nil,
                    icon: nil,
                    configurator: AddWalletCustomizeWalletViewModelConfigurator()
                )
            }
        )
    }

    func createPairSignerCoordinator(router: NavigationControllerRouter) -> PairSignerCoordinator {
        PairSignerCoordinator(
            scannerAssembly: dependencies.scannerAssembly,
            walletUpdateAssembly: dependencies.walletsUpdateAssembly,
            coreAssembly: dependencies.coreAssembly,
            router: router,
            publicKeyImportCoordinatorProvider: { router, publicKey, name in
                self.createPublicKeyImportCoordinator(publicKey: publicKey, name: name, router: router)
            }
        )
    }

    func createPairKeystoneCoordinator(router: NavigationControllerRouter) -> PairKeystoneCoordinator {
        PairKeystoneCoordinator(
            scannerAssembly: dependencies.scannerAssembly,
            walletUpdateAssembly: dependencies.walletsUpdateAssembly,
            coreAssembly: dependencies.coreAssembly,
            router: router,
            keystoneImportCoordinatorProvider: { router, publicKey, xfp, path, name in
                self.createKeystoneImportCoordinator(publicKey: publicKey, xfp: xfp, path: path, name: name, router: router)
            }
        )
    }

    func createPairSignerDeeplinkCoordinator(
        publicKey: TonSwift.PublicKey,
        name: String,
        router: NavigationControllerRouter
    ) -> PairSignerDeeplinkCoordinator {
        PairSignerDeeplinkCoordinator(
            publicKey: publicKey,
            name: name,
            walletUpdateAssembly: dependencies.walletsUpdateAssembly,
            coreAssembly: dependencies.coreAssembly,
            router: router,
            publicKeyImportCoordinatorProvider: { router, publicKey, name in
                self.createPublicKeyImportCoordinator(publicKey: publicKey, name: name, router: router)
            }
        )
    }

    func createLedgerImportCoordinator(
        accounts: [LedgerAccount],
        activeWalletModels: [ActiveWalletModel],
        name: String,
        router: NavigationControllerRouter
    ) -> LedgerImportCoordinator {
        LedgerImportCoordinator(
            ledgerAccounts: accounts,
            activeWalletModels: activeWalletModels,
            name: name,
            router: router,
            walletsUpdateAssembly: dependencies.walletsUpdateAssembly,
            customizeWalletModule: {
                self.createCustomizeWalletModule(
                    name: name,
                    tintColor: nil,
                    icon: nil,
                    configurator: AddWalletCustomizeWalletViewModelConfigurator()
                )
            }
        )
    }

    func createLedgerPairCoordinator(router: ViewControllerRouter) -> PairLedgerCoordinator {
        PairLedgerCoordinator(
            walletUpdateAssembly: dependencies.walletsUpdateAssembly,
            coreAssembly: dependencies.coreAssembly,
            router: router,
            ledgerImportCoordinatorProvider: { router, accounts, activeWalletModels, name in
                self.createLedgerImportCoordinator(accounts: accounts, activeWalletModels: activeWalletModels, name: name, router: router)
            }
        )
    }
}

private extension AddWalletModule {
    func createImportWatchOnlyWalletCoordinator(router: NavigationControllerRouter) -> ImportWatchOnlyWalletCoordinator {
        return ImportWatchOnlyWalletCoordinator(
            router: router,
            analyticsProvider: dependencies.coreAssembly.analyticsProvider,
            walletsUpdateAssembly: dependencies.walletsUpdateAssembly,
            customizeWalletModule: { name in
                self.createCustomizeWalletModule(
                    name: name,
                    tintColor: nil,
                    icon: nil,
                    configurator: AddWalletCustomizeWalletViewModelConfigurator()
                )
            }
        )
    }
}

extension AddWalletModule {
    struct Dependencies {
        let walletsUpdateAssembly: KeeperCore.WalletsUpdateAssembly
        let storesAssembly: KeeperCore.StoresAssembly
        let coreAssembly: TKCore.CoreAssembly
        let scannerAssembly: KeeperCore.ScannerAssembly
        let configurationAssembly: ConfigurationAssembly

        init(
            walletsUpdateAssembly: KeeperCore.WalletsUpdateAssembly,
            storesAssembly: KeeperCore.StoresAssembly,
            coreAssembly: TKCore.CoreAssembly,
            scannerAssembly: KeeperCore.ScannerAssembly,
            configurationAssembly: ConfigurationAssembly
        ) {
            self.walletsUpdateAssembly = walletsUpdateAssembly
            self.storesAssembly = storesAssembly
            self.coreAssembly = coreAssembly
            self.scannerAssembly = scannerAssembly
            self.configurationAssembly = configurationAssembly
        }
    }
}
