import UIKit
import KeeperCore
import TKCoordinator
import TKUIKit
import TKScreenKit
import PasscodeModule
import WalletCustomizationModule

public final class ImportWalletCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  private let walletAddController: WalletAddController
  
  var didCancel: (() -> Void)?
  var didImportWallet: (() -> Void)?
  
  init(router: NavigationControllerRouter,
       walletAddController: WalletAddController) {
    self.walletAddController = walletAddController
    super.init(router: router)
  }
  
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
      self?.openCreatePasscode(phrase: phrase)
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
  
  func openCreatePasscode(phrase: [String]) {
    let coordinator = PasscodeModule().createCreatePasscodeCoordinator(router: router)
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      guard let coordinator = coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    coordinator.didCreatePasscode = { [weak self] passcode in
      self?.openCustomizeWallet(phrase: phrase, passcode: passcode)
    }
    
    addChild(coordinator)
    coordinator.start()
  }
  
  func openCustomizeWallet(phrase: [String], passcode: String) {
    let module = WalletCustomizationModule().customizeWalletModule()
    module.output.didCustomizeWallet = { [weak self] model in
      self?.createWalletWith(phrase: phrase, passcode: passcode, model: model)
    }
    
    module.view.setupBackButton()
    
    router.push(viewController: module.view)
  }
}

private extension ImportWalletCoordinator {
  func createWalletWith(phrase: [String], passcode: String, model: CustomizeWalletModel) {
    let metaData = WalletMetaData(
      label: model.name,
      colorIdentifier: model.colorIdentifier,
      emoji: model.emoji)
    
    do {
      try walletAddController.createWallet(metaData: metaData)
      didImportWallet?()
    } catch {
      print("Log: Wallet import failed")
    }
  }
}
