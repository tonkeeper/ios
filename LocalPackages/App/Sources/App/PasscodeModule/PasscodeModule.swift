import TKUIKit
import TKCoordinator

public struct PasscodeModule {
  public init() {}
  
  public func createCreatePasscodeCoordinator(router: NavigationControllerRouter) -> CreatePasscodeCoordinator {
    let coordinator = CreatePasscodeCoordinator(router: router)
    return coordinator
  }
}
