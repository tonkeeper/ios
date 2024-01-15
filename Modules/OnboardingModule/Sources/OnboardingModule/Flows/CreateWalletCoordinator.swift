import UIKit
import TKCoordinator
import TKUIKit
import TKScreenKit
import KeeperCore
import PasscodeModule
import WalletCustomizationModule

public final class CreateWalletCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  private let walletAddController: WalletAddController
  
  var didCancel: (() -> Void)?
  var didCreateWallet: (() -> Void)?
  
  init(router: NavigationControllerRouter,
       walletAddController: WalletAddController) {
    self.walletAddController = walletAddController
    super.init(router: router)
  }
  
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
      self?.openCustomizeWallet(passcode: passcode)
    }
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func openCustomizeWallet(passcode: String) {
    let module = WalletCustomizationModule().customizeWalletModule()
    module.output.didCustomizeWallet = { [weak self] model in
      self?.createWalletWith(passcode: passcode, model: model)
    }
    
    module.view.setupBackButton()
    
    router.push(viewController: module.view)
  }
}

private extension CreateWalletCoordinator {
  func createWalletWith(passcode: String, model: CustomizeWalletModel) {
    let metaData = WalletMetaData(
      label: model.name,
      colorIdentifier: model.colorIdentifier,
      emoji: model.emoji)
    do {
      try walletAddController.createWallet(metaData: metaData)
      didCreateWallet?()
    } catch {
      print("Log: Wallet creation failed")
    }
  }
}
