import TKUIKit
import TKCoordinator

public struct Onboarding {
  public init() {}
  
  public func createOnboardingCoordinator() -> OnboardingCoordinator {
    let navigationController = TKNavigationController()
    navigationController.configureTransparentAppearance()
    
    let coordinator = OnboardingCoordinator(router: NavigationControllerRouter(rootViewController: navigationController))
    return coordinator
  }
}
