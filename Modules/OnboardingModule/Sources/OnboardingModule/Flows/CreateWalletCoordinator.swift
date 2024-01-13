import UIKit
import TKCoordinator
import TKUIKit
import TKScreenKit
import PasscodeModule
import WalletCustomizationModule

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
    
    coordinator.didCreatePasscode = { [weak self] passcode in
      self?.openCustomizeWallet()
    }
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func openCustomizeWallet() {
    let module = WalletCustomizationModule().customizeWalletModule()
    module.output.didCustomizeWallet = { [weak self] model in
      self?.didCreateWallet?()
    }
    
    module.view.setupBackButton()
    
    router.push(viewController: module.view)
  }
}
