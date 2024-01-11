import UIKit
import TKCoordinator
import TKUIKit
import TKScreenKit
import PasscodeModule

public final class CreateWalletCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didCancel: (() -> Void)?
  var didCreateWallet: (() -> Void)?
  
  public override func start() {
    openCreatePasscode()
  }
}

private extension CreateWalletCoordinator {
  func openCreatePasscode() {
    let coordinator = PasscodeModule().createCreatePasscodeCoordinator(router: router)
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      self?.didCancel?()
    }
    
    coordinator.didCreatePasscode = { [weak self, weak coordinator] passcode in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
      self?.didCreateWallet?()
    }
    
    addChild(coordinator)
    coordinator.start()
  }
}
