import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

@MainActor
public struct WalletModule {
  private let dependencies: Dependencies
  public init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }

  public func createWalletCoordinator() -> WalletCoordinator {
    let navigationController = TKNavigationController()
    navigationController.configureDefaultAppearance()
    
    let coordinator = WalletCoordinator(
      router: NavigationControllerRouter(rootViewController: navigationController),
      coreAssembly: dependencies.coreAssembly,
      keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly
    )
    return coordinator
  }
}

public extension WalletModule {
  struct Dependencies {
    let coreAssembly: TKCore.CoreAssembly
    let keeperCoreMainAssembly: KeeperCore.MainAssembly
    
    public init(coreAssembly: TKCore.CoreAssembly,
                keeperCoreMainAssembly: KeeperCore.MainAssembly) {
      self.coreAssembly = coreAssembly
      self.keeperCoreMainAssembly = keeperCoreMainAssembly
    }
  }
}

