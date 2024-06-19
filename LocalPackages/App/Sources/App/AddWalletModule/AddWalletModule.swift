import UIKit
import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore
import TonSwift

struct AddWalletModule {
  private let dependencies: Dependencies
  init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  func createAddWalletCoordinator(options: [AddWalletOption],
                                  router: ViewControllerRouter) -> AddWalletCoordinator {
    let coordinator = AddWalletCoordinator(
      router: router,
      options: options,
      walletAddController: dependencies.walletsUpdateAssembly.walletAddController(),
      createWalletCoordinatorProvider:  { router in
        return createCreateWalletCoordinator(router: router)
      },
      importWalletCoordinatorProvider: { router, isTestnet in
        return createImportWalletCoordinator(router: router, isTestnet: isTestnet)
      },
      importWatchOnlyWalletCoordinatorProvider: { router in
        return createImportWatchOnlyWalletCoordinator(router: router)
      }, pairSignerCoordinatorProvider: { router in
        return createPairSignerCoordinator(router: router)
      }, pairLedgerCoordinatorProvider: { router in
        return createLedgerPairCoordinator(router: router)
      }
    )
    
    return coordinator
  }
  
  func createCreateWalletCoordinator(router: ViewControllerRouter) -> CreateWalletCoordinator {
    let coordinator = CreateWalletCoordinator(
      router: router,
      walletsUpdateAssembly: dependencies.walletsUpdateAssembly,
      storesAssembly: dependencies.storesAssembly,
      customizeWalletModule: {
        self.createCustomizeWalletModule(
          name: nil,
          tintColor: nil,
          emoji: nil,
          configurator: AddWalletCustomizeWalletViewModelConfigurator()
        )
      }
    )
    return coordinator
  }
  
  func createImportWalletCoordinator(router: NavigationControllerRouter, isTestnet: Bool) -> ImportWalletCoordinator {
    let coordinator = ImportWalletCoordinator(
      router: router,
      walletsUpdateAssembly: dependencies.walletsUpdateAssembly,
      storesAssembly: dependencies.storesAssembly,
      isTestnet: isTestnet,
      customizeWalletModule: {
        self.createCustomizeWalletModule(
          name: nil,
          tintColor: nil,
          emoji: nil,
          configurator: AddWalletCustomizeWalletViewModelConfigurator()
        )
      }
    )
    return coordinator
  }
  
  func createCustomizeWalletModule(name: String? = nil,
                                   tintColor: WalletTintColor? = nil,
                                   emoji: String? = nil,
                                   configurator: CustomizeWalletViewModelConfigurator) -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void> {
    return CustomizeWalletAssembly.module(
      name: name,
      tintColor: tintColor,
      emoji: emoji,
      configurator: configurator
    )
  }
  
  public func createPublicKeyImportCoordinator(publicKey: TonSwift.PublicKey,
                                               name: String,
                                               router: NavigationControllerRouter) -> PublicKeyImportCoordinator {
    PublicKeyImportCoordinator(
      publicKey: publicKey,
      name: name,
      router: router,
      walletsUpdateAssembly: dependencies.walletsUpdateAssembly,
      customizeWalletModule: {
        self.createCustomizeWalletModule(
          name: name,
          tintColor: nil,
          emoji: nil,
          configurator: AddWalletCustomizeWalletViewModelConfigurator()
        )
      }
    )
  }
  
  public func createPairSignerCoordinator(router: NavigationControllerRouter) -> PairSignerCoordinator {
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
  
  public func createPairSignerDeeplinkCoordinator(
    publicKey: TonSwift.PublicKey,
    name: String,
    router: NavigationControllerRouter) -> PairSignerDeeplinkCoordinator {
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

public func createLedgerPairCoordinator(router: ViewControllerRouter) -> PairLedgerCoordinator {
    PairLedgerCoordinator(
      walletUpdateAssembly: dependencies.walletsUpdateAssembly,
      coreAssembly: dependencies.coreAssembly,
      router: router,
      publicKeyImportCoordinatorProvider: { router, publicKey, name in
        self.createPublicKeyImportCoordinator(publicKey: publicKey, name: name, router: router)
      }
    )
  }
}

private extension AddWalletModule {
  func createImportWatchOnlyWalletCoordinator(router: NavigationControllerRouter) -> ImportWatchOnlyWalletCoordinator {
    let coordinator = ImportWatchOnlyWalletCoordinator(
      router: router,
      walletsUpdateAssembly: dependencies.walletsUpdateAssembly,
      customizeWalletModule: { name in
        self.createCustomizeWalletModule(
          name: name,
          tintColor: nil,
          emoji: nil,
          configurator: AddWalletCustomizeWalletViewModelConfigurator()
        )
      }
    )
    
    return coordinator
  }
}

extension AddWalletModule {
  struct Dependencies {
    let walletsUpdateAssembly: KeeperCore.WalletsUpdateAssembly
    let storesAssembly: KeeperCore.StoresAssembly
    let coreAssembly: TKCore.CoreAssembly
    let scannerAssembly: KeeperCore.ScannerAssembly
    
    public init(walletsUpdateAssembly: KeeperCore.WalletsUpdateAssembly,
                storesAssembly: KeeperCore.StoresAssembly,
                coreAssembly: TKCore.CoreAssembly,
                scannerAssembly: KeeperCore.ScannerAssembly) {
      self.walletsUpdateAssembly = walletsUpdateAssembly
      self.storesAssembly = storesAssembly
      self.coreAssembly = coreAssembly
      self.scannerAssembly = scannerAssembly
    }
  }
}
