import KeeperCore
import TKCoordinator
import TKCore
import TKLocalize
import TKUIKit
import TonSwift
import TonTransport
import UIKit

@MainActor
struct AddWalletModule {
    private let dependencies: Dependencies
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func createAddWalletCoordinator(
        options: [AddWalletOption],
        router: ViewControllerRouter,
        analyticsContext: WalletFlowAnalyticsContext
    ) -> AddWalletCoordinator {
        return AddWalletCoordinator(
            router: router,
            options: options,
            configurationAssembly: dependencies.configurationAssembly,
            multichainSupportedChains: dependencies.multichainAssembly.supportedChains,
            walletAddController: dependencies.walletsUpdateAssembly.walletAddController(
                multichainAssembly: dependencies.multichainAssembly
            ),
            analyticsProvider: dependencies.coreAssembly.analyticsProvider,
            analyticsContext: analyticsContext,
            createWalletCoordinatorProvider: { router, mode in
                createCreateWalletCoordinator(router: router, mode: mode, analyticsContext: analyticsContext)
            },
            importWalletCoordinatorProvider: { router, network in
                createImportWalletCoordinator(router: router, network: network, analyticsContext: analyticsContext)
            },
            importWatchOnlyWalletCoordinatorProvider: { router in
                createImportWatchOnlyWalletCoordinator(router: router, analyticsContext: analyticsContext)
            }, pairSignerCoordinatorProvider: { router in
                createPairSignerCoordinator(router: router, analyticsContext: analyticsContext)
            }, pairLedgerCoordinatorProvider: { router in
                createLedgerPairCoordinator(router: router, analyticsContext: analyticsContext)
            },
            pairKeystoneCoordinatorProvider: { router in
                createPairKeystoneCoordinator(router: router, analyticsContext: analyticsContext)
            }
        )
    }

    func createCreateWalletCoordinator(
        router: ViewControllerRouter,
        mode: CreateWalletCoordinator.Mode = .regular,
        analyticsContext: WalletFlowAnalyticsContext
    ) -> CreateWalletCoordinator {
        return CreateWalletCoordinator(
            router: router,
            analyticsProvider: dependencies.coreAssembly.analyticsProvider,
            walletsUpdateAssembly: dependencies.walletsUpdateAssembly,
            multichainAssembly: dependencies.multichainAssembly,
            hasPasscodeChecker: DefaultHasPasscodeChecker(
                mnemonicsAccess: dependencies.walletsUpdateAssembly.secureAssembly.mnemonicAccess,
                keeperInfoRepository: dependencies.walletsUpdateAssembly.repositoriesAssembly.keeperInfoRepository()
            ),
            storesAssembly: dependencies.storesAssembly,
            configurationAssembly: dependencies.configurationAssembly,
            coreAssembly: dependencies.coreAssembly,
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
            mode: mode,
            analyticsContext: analyticsContext,
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
            mnemonicAccess: dependencies.walletsUpdateAssembly.secureAssembly.mnemonicAccess,
            addController: dependencies.walletsUpdateAssembly.walletAddController(
                multichainAssembly: dependencies.multichainAssembly
            ),
            analyticsProvider: dependencies.coreAssembly.analyticsProvider
        )
    }

    func createImportWalletCoordinator(
        router: NavigationControllerRouter,
        network: Network,
        analyticsContext: WalletFlowAnalyticsContext
    ) -> ImportWalletCoordinator {
        return ImportWalletCoordinator(
            router: router,
            analyticsProvider: dependencies.coreAssembly.analyticsProvider,
            walletsUpdateAssembly: dependencies.walletsUpdateAssembly,
            storesAssembly: dependencies.storesAssembly,
            hasPasscodeChecker: DefaultHasPasscodeChecker(
                mnemonicsAccess: dependencies.walletsUpdateAssembly.secureAssembly.mnemonicAccess,
                keeperInfoRepository: dependencies.walletsUpdateAssembly.repositoriesAssembly.keeperInfoRepository()
            ),
            multichainAssembly: dependencies.multichainAssembly,
            configurationAssembly: dependencies.configurationAssembly,
            network: network,
            analyticsContext: analyticsContext,
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
    ) -> MVVMModule<CustomizeWalletHostingViewController, CustomizeWalletModuleOutput, Void> {
        return CustomizeWalletAssembly.module(
            name: name ?? suggestedWalletName(),
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

    func createPairSignerCoordinator(
        router: NavigationControllerRouter,
        analyticsContext: WalletFlowAnalyticsContext
    ) -> PairSignerCoordinator {
        PairSignerCoordinator(
            scannerAssembly: dependencies.scannerAssembly,
            walletUpdateAssembly: dependencies.walletsUpdateAssembly,
            multichainAssembly: dependencies.multichainAssembly,
            coreAssembly: dependencies.coreAssembly,
            router: router,
            analyticsContext: analyticsContext,
            publicKeyImportCoordinatorProvider: { router, publicKey, name in
                self.createPublicKeyImportCoordinator(publicKey: publicKey, name: name, router: router)
            }
        )
    }

    func createPairKeystoneCoordinator(
        router: NavigationControllerRouter,
        analyticsContext: WalletFlowAnalyticsContext
    ) -> PairKeystoneCoordinator {
        PairKeystoneCoordinator(
            scannerAssembly: dependencies.scannerAssembly,
            walletUpdateAssembly: dependencies.walletsUpdateAssembly,
            multichainAssembly: dependencies.multichainAssembly,
            coreAssembly: dependencies.coreAssembly,
            router: router,
            analyticsContext: analyticsContext,
            keystoneImportCoordinatorProvider: { router, publicKey, xfp, path, name in
                self.createKeystoneImportCoordinator(publicKey: publicKey, xfp: xfp, path: path, name: name, router: router)
            }
        )
    }

    func createPairSignerDeeplinkCoordinator(
        publicKey: TonSwift.PublicKey,
        name: String,
        router: NavigationControllerRouter,
        analyticsContext: WalletFlowAnalyticsContext
    ) -> PairSignerDeeplinkCoordinator {
        PairSignerDeeplinkCoordinator(
            publicKey: publicKey,
            name: name,
            walletUpdateAssembly: dependencies.walletsUpdateAssembly,
            multichainAssembly: dependencies.multichainAssembly,
            coreAssembly: dependencies.coreAssembly,
            router: router,
            analyticsContext: analyticsContext,
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

    func createLedgerPairCoordinator(
        router: ViewControllerRouter,
        analyticsContext: WalletFlowAnalyticsContext
    ) -> PairLedgerCoordinator {
        PairLedgerCoordinator(
            walletUpdateAssembly: dependencies.walletsUpdateAssembly,
            coreAssembly: dependencies.coreAssembly,
            multichainAssembly: dependencies.multichainAssembly,
            router: router,
            analyticsContext: analyticsContext,
            ledgerImportCoordinatorProvider: { router, accounts, activeWalletModels, name in
                self.createLedgerImportCoordinator(accounts: accounts, activeWalletModels: activeWalletModels, name: name, router: router)
            }
        )
    }
}

private extension AddWalletModule {
    func createImportWatchOnlyWalletCoordinator(
        router: NavigationControllerRouter,
        analyticsContext: WalletFlowAnalyticsContext
    ) -> ImportWatchOnlyWalletCoordinator {
        return ImportWatchOnlyWalletCoordinator(
            router: router,
            analyticsProvider: dependencies.coreAssembly.analyticsProvider,
            walletsUpdateAssembly: dependencies.walletsUpdateAssembly,
            multichainAssembly: dependencies.multichainAssembly,
            analyticsContext: analyticsContext,
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

private extension AddWalletModule {
    func suggestedWalletName() -> String {
        DefaultWalletName.suggest(
            base: TKLocales.CustomizeWallet.defaultWalletName,
            existingLabels: dependencies.storesAssembly.walletsStore.wallets.map(\.metaData.label)
        )
    }
}

extension AddWalletModule {
    func makeWalletFlowAnalyticsContext(from: AddWalletSource) -> WalletFlowAnalyticsContext {
        WalletFlowAnalyticsContext(from: from)
    }
}

extension AddWalletModule {
    struct Dependencies {
        let walletsUpdateAssembly: KeeperCore.WalletsUpdateAssembly
        let storesAssembly: KeeperCore.StoresAssembly
        let coreAssembly: TKCore.CoreAssembly
        let keeperCoreMainAssembly: KeeperCore.MainAssembly
        let multichainAssembly: MultichainAssembly
        let scannerAssembly: KeeperCore.ScannerAssembly
        let configurationAssembly: ConfigurationAssembly

        init(
            walletsUpdateAssembly: KeeperCore.WalletsUpdateAssembly,
            storesAssembly: KeeperCore.StoresAssembly,
            coreAssembly: TKCore.CoreAssembly,
            keeperCoreMainAssembly: KeeperCore.MainAssembly,
            multichainAssembly: MultichainAssembly,
            scannerAssembly: KeeperCore.ScannerAssembly,
            configurationAssembly: ConfigurationAssembly
        ) {
            self.walletsUpdateAssembly = walletsUpdateAssembly
            self.storesAssembly = storesAssembly
            self.coreAssembly = coreAssembly
            self.keeperCoreMainAssembly = keeperCoreMainAssembly
            self.multichainAssembly = multichainAssembly
            self.scannerAssembly = scannerAssembly
            self.configurationAssembly = configurationAssembly
        }
    }
}
