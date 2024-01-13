import UIKit
import TKCoordinator
import TKUIKit
import TKScreenKit
import PasscodeModule
import WalletCustomizationModule

public final class ImportWalletCoordinator: RouterCoordinator<NavigationControllerRouter> {
  var didCancel: (() -> Void)?
  var didImportWallet: (() -> Void)?
  
  public override func start() {
    openInputRecoveryPhrase()
  }
}

private extension ImportWalletCoordinator {
  func openInputRecoveryPhrase() {
    let inputRecoveryPhrase = TKInputRecoveryPhraseAssembly.module(
      validator: InputRecoveryPhraseValidator(), 
      suggestsProvider: InputRecoveryPhraseSuggestsProvider()
    )
    
    inputRecoveryPhrase.output.didInputRecoveryPhrase = { [weak self] phrase in
      self?.openCreatePasscode()
    }
    
    if router.rootViewController.viewControllers.isEmpty {
      inputRecoveryPhrase.viewController.setupLeftCloseButton { [weak self] in
        self?.didCancel?()
      }
    } else {
      inputRecoveryPhrase.viewController.setupBackButton()
    }
    
    router.push(
      viewController: inputRecoveryPhrase.viewController,
      animated: true,
      onPopClosures: { [weak self] in
        self?.didCancel?()
      },
      completion: nil)
  }
  
  func openCreatePasscode() {
    let coordinator = PasscodeModule().createCreatePasscodeCoordinator(router: router)
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
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
      self?.didImportWallet?()
    }
    
    module.view.setupBackButton()
    
    router.push(viewController: module.view)
  }
}
