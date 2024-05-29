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
      coreAssembly: dependencies.coreAssembly,
      keeperCoreOnboardingAssembly: dependencies.keeperCoreOnboardingAssembly
    )
    return coordinator
  }
}

public extension OnboardingModule {
  struct Dependencies {
    let coreAssembly: TKCore.CoreAssembly
    let keeperCoreOnboardingAssembly: KeeperCore.OnboardingAssembly
    
    public init(coreAssembly: TKCore.CoreAssembly, 
                keeperCoreOnboardingAssembly: KeeperCore.OnboardingAssembly) {
      self.coreAssembly = coreAssembly
      self.keeperCoreOnboardingAssembly = keeperCoreOnboardingAssembly
    }
  }
}
