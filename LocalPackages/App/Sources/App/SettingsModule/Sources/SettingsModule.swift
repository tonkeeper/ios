import TKUIKit
import TKCoordinator

public struct SettingsModule {
  public init() {}
  
  public func createSettingsCoordinator(router: NavigationControllerRouter) -> SettingsCoordinator {
    let coordinator = SettingsCoordinator(router: router)
    return coordinator
  }
}
