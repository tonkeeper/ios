import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

public struct PasscodeModule {
  private let dependencies: Dependencies
  init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
//  public func createCreatePasscodeCoordinator(router: NavigationControllerRouter) -> CreatePasscodeCoordinator {
//    let coordinator = CreatePasscodeCoordinator(router: router)
//    return coordinator
//  }
  
//  public func passcodeConfirmationCoordinator() -> PasscodeConfirmationCoordinator {
//    let navigationController = TKNavigationController()
//    navigationController.configureTransparentAppearance()
//    
//    let coordinator = PasscodeConfirmationCoordinator(
//      router: NavigationControllerRouter(
//        rootViewController: navigationController
//      ),
//      passcodeConfirmationController: dependencies.passcodeAssembly.passcodeConfirmationController()
//    )
//    return coordinator
//  }
  
//  public func changePasscodeCoordinator() -> ChangePasscodeCoordinator {
//    let navigationController = TKNavigationController()
//    navigationController.configureTransparentAppearance()
//    
//    let coordinator = ChangePasscodeCoordinator(
//      router: NavigationControllerRouter(
//        rootViewController: navigationController
//      ),
//      passcodeConfirmationController: dependencies.passcodeAssembly.passcodeConfirmationController()
//    )
//    return coordinator
//  }
}

extension PasscodeModule {
  struct Dependencies {
    let passcodeAssembly: KeeperCore.PasscodeAssembly
    
    init(passcodeAssembly: KeeperCore.PasscodeAssembly) {
      self.passcodeAssembly = passcodeAssembly
    }
  }
}
