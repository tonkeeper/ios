import UIKit
import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

struct AddWalletModule {
  private let dependencies: Dependencies
  init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  func createAddWalletCoordinator(router: ViewControllerRouter) -> AddWalletCoordinator {
    let coordinator = AddWalletCoordinator(
      router: router,
      walletAddController: dependencies.walletsUpdateAssembly.walletAddController(),
      createWalletCoordinatorProvider:  { router in
        return createCreateWalletCoordinator(router: router)
      },
      importWalletCoordinatorProvider: { router in
        return createImportWalletCoordinator(router: router)
      },
      importWatchOnlyWalletCoordinatorProvider: { router in
        return createImportWatchOnlyWalletCoordinator(router: router)
      }
    )
    
    return coordinator
  }
  
  func createImportWalletCoordinator(router: NavigationControllerRouter) -> ImportWalletCoordinator {
    let coordinator = ImportWalletCoordinator(
      router: router,
      walletsUpdateAssembly: dependencies.walletsUpdateAssembly,
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
  
  public func createRecoveryPhraseCoordinator(router: NavigationControllerRouter) -> RecoveryPhraseCoordinator {
    let coordinator = RecoveryPhraseCoordinator(
      router: router,
      walletsUpdateAssembly: dependencies.walletsUpdateAssembly
    )
    
    return coordinator
  }
}

private extension AddWalletModule {
  func createCreateWalletCoordinator(router: NavigationControllerRouter) -> CreateWalletCoordinator {
    let coordinator = CreateWalletCoordinator(
      router: router,
      walletsUpdateAssembly: dependencies.walletsUpdateAssembly,
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
    
    public init(walletsUpdateAssembly: KeeperCore.WalletsUpdateAssembly) {
      self.walletsUpdateAssembly = walletsUpdateAssembly
    }
  }
}
