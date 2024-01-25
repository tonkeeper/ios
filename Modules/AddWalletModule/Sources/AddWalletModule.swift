import UIKit
import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

public struct AddWalletModule {
  private let dependencies: Dependencies
  public init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  public func createAddWalletCoordinator(router: ViewControllerRouter) -> AddWalletCoordinator {
    let coordinator = AddWalletCoordinator(
      router: router,
      walletAddController: dependencies.walletsUpdateAssembly.walletAddController(),
      createWalletCoordinatorProvider:  { router in
        return createCreateWalletCoordinator(router: router)
      },
      importWalletCoordinatorProvider: { router in
        return createImportWalletCoordinator(router: router)
      })
    
    return coordinator
  }
  
  public func createImportWalletCoordinator(router: NavigationControllerRouter) -> ImportWalletCoordinator {
    let coordinator = ImportWalletCoordinator(
      router: router,
      walletsUpdateAssembly: dependencies.walletsUpdateAssembly,
      customizeWalletModule: { self.createCustomizeWalletModule() }
    )
    
    return coordinator
  }
  
  public func createCustomizeWalletModule() -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void> {
    return CustomizeWalletAssembly.module()
  }
}

private extension AddWalletModule {
  func createCreateWalletCoordinator(router: NavigationControllerRouter) -> CreateWalletCoordinator {
    let coordinator = CreateWalletCoordinator(
      router: router,
      walletsUpdateAssembly: dependencies.walletsUpdateAssembly,
      customizeWalletModule: {
        self.createCustomizeWalletModule()
      }
    )
    
    return coordinator
  }
}

public extension AddWalletModule {
  struct Dependencies {
    let walletsUpdateAssembly: KeeperCore.WalletsUpdateAssembly
    
    public init(walletsUpdateAssembly: KeeperCore.WalletsUpdateAssembly) {
      self.walletsUpdateAssembly = walletsUpdateAssembly
    }
  }
}
