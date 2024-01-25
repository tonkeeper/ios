import UIKit
import KeeperCore
import TKCoordinator
import TKUIKit
import TKScreenKit

public final class ImportWalletCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didCancel: (() -> Void)?
  public var didImportWallets: ((_ wallets: [Wallet], _ phrase: [String]) -> Void)?

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
      self?.didInputRecoveryPhrase(phrase)
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
  
  func didInputRecoveryPhrase(_ phrase: [String]) {
    
  }
}
