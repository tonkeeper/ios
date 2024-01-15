import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

public struct OnboardingModule {
  private let dependencies: Dependencies
  public init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  public func createOnboardingCoordinator() -> OnboardingCoordinator {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    
    let coordinator = OnboardingCoordinator(
      router: NavigationControllerRouter(rootViewController: navigationController),
      keeperCoreAssembly: dependencies.keeperCoreAssembly
    )
    return coordinator
  }
}

public extension OnboardingModule {
  struct Dependencies {
    let coreAssembly: TKCore.CoreAssembly
    let keeperCoreAssembly: KeeperCore.Assembly
    
    public init(coreAssembly: TKCore.CoreAssembly, 
                keeperCoreAssembly: KeeperCore.Assembly) {
      self.coreAssembly = coreAssembly
      self.keeperCoreAssembly = keeperCoreAssembly
    }
  }
}
